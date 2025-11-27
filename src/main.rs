use anyhow::{Context, Result};
use http_body_util::{combinators::BoxBody, BodyExt, Full};
use hyper::body::Bytes;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response, StatusCode};
use hyper_util::client::legacy::Client;
use hyper_util::rt::TokioExecutor;
use hyper_util::rt::TokioIo;
use serde::Deserialize;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use tracing::{error, info};

#[derive(Debug, Deserialize)]
struct Config {
    proxy: ProxyConfig,
    logging: LoggingConfig,
}

#[derive(Debug, Deserialize)]
struct ProxyConfig {
    listen_addr: String,
    listen_port: u16,
    target_addr: String,
    target_port: u16,
}

#[derive(Debug, Deserialize)]
struct LoggingConfig {
    level: String,
}

impl Config {
    fn from_file(path: &str) -> Result<Self> {
        let content = std::fs::read_to_string(path)
            .with_context(|| format!("Failed to read config file: {}", path))?;
        let config: Config = toml::from_str(&content)
            .with_context(|| format!("Failed to parse config file: {}", path))?;
        Ok(config)
    }

    fn listen_addr(&self) -> String {
        format!("{}:{}", self.proxy.listen_addr, self.proxy.listen_port)
    }

    fn target_url(&self) -> String {
        format!("http://{}:{}", self.proxy.target_addr, self.proxy.target_port)
    }
}

#[derive(Clone)]
struct ProxyState {
    target_url: String,
    client: Client<hyper_util::client::legacy::connect::HttpConnector, BoxBody<Bytes, hyper::Error>>,
}

async fn proxy_handler(
    mut req: Request<hyper::body::Incoming>,
    state: ProxyState,
) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    let method = req.method().clone();
    let uri = req.uri().clone();
    let path = uri.path();
    let query = uri.query().unwrap_or("");

    info!(
        "Proxying request: {} {} {}",
        method,
        path,
        if query.is_empty() {
            String::new()
        } else {
            format!("?{}", query)
        }
    );

    // Build target URL
    let target_url = if query.is_empty() {
        format!("{}{}", state.target_url, path)
    } else {
        format!("{}{}?{}", state.target_url, path, query)
    };

    // Parse target URI
    let target_uri = match target_url.parse::<hyper::Uri>() {
        Ok(uri) => uri,
        Err(e) => {
            error!("Invalid target URI: {}", e);
            return Ok(Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(full("Invalid target URI"))
                .unwrap());
        }
    };

    // Update request URI
    *req.uri_mut() = target_uri;

    // Forward the request
    match state.client.request(req.map(|body| body.boxed())).await {
        Ok(response) => {
            info!("Response status: {}", response.status());
            Ok(response.map(|body| body.boxed()))
        }
        Err(e) => {
            error!("Proxy request failed: {}", e);
            Ok(Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(full(format!("Proxy error: {}", e)))
                .unwrap())
        }
    }
}

fn full<T: Into<Bytes>>(chunk: T) -> BoxBody<Bytes, hyper::Error> {
    Full::new(chunk.into())
        .map_err(|never| match never {})
        .boxed()
}

#[tokio::main]
async fn main() -> Result<()> {
    // Load configuration
    let config = Config::from_file("config.toml").context("Failed to load configuration")?;

    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(&config.logging.level)),
        )
        .init();

    info!("Starting HTTP proxy server");
    info!("Listening on: {}", config.listen_addr());
    info!("Forwarding to: {}", config.target_url());

    // Parse listen address
    let addr: SocketAddr = config
        .listen_addr()
        .parse()
        .context("Invalid listen address")?;

    // Create HTTP client
    let client = Client::builder(TokioExecutor::new()).build_http();

    let state = ProxyState {
        target_url: config.target_url(),
        client,
    };

    // Bind TCP listener
    let listener = TcpListener::bind(addr)
        .await
        .context("Failed to bind to address")?;

    info!("Server started successfully");

    // Accept connections
    loop {
        match listener.accept().await {
            Ok((stream, client_addr)) => {
                info!("New connection from: {}", client_addr);
                let io = TokioIo::new(stream);
                let state_clone = state.clone();

                tokio::spawn(async move {
                    if let Err(err) = http1::Builder::new()
                        .serve_connection(
                            io,
                            service_fn(move |req| {
                                let state = state_clone.clone();
                                async move { proxy_handler(req, state).await }
                            }),
                        )
                        .await
                    {
                        error!("Error serving connection: {}", err);
                    }
                });
            }
            Err(e) => {
                error!("Failed to accept connection: {}", e);
            }
        }
    }
}
