use anyhow::{Context, Result};
use http_body_util::{combinators::BoxBody, BodyExt, Full};
use hyper::body::Bytes;
use hyper::header::{HeaderValue, CONNECTION, HOST, UPGRADE};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::upgrade::Upgraded;
use hyper::{Request, Response, StatusCode, Uri};
use hyper_util::client::legacy::Client;
use hyper_util::rt::{TokioExecutor, TokioIo};
use serde::Deserialize;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tracing::{debug, error, info};

#[derive(Debug, Deserialize)]
struct Config {
    proxies: Vec<ProxyConfig>,
    logging: LoggingConfig,
}

#[derive(Debug, Deserialize, Clone)]
struct ProxyConfig {
    name: String,
    listen_addr: String,
    listen_port: u16,
    target_addr: String,
    target_port: u16,
    #[serde(default)]
    enable_websocket: bool,
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

    fn default() -> Self {
        Config {
            proxies: vec![
                ProxyConfig {
                    name: String::from("solana-rpc"),
                    listen_addr: String::from("127.0.0.1"),
                    listen_port: 8899,
                    target_addr: String::from("162.250.124.66"),
                    target_port: 8899,
                    enable_websocket: false,
                },
                ProxyConfig {
                    name: String::from("solana-ws"),
                    listen_addr: String::from("127.0.0.1"),
                    listen_port: 8900,
                    target_addr: String::from("162.250.124.66"),
                    target_port: 8900,
                    enable_websocket: true,
                },
                ProxyConfig {
                    name: String::from("service-3000"),
                    listen_addr: String::from("127.0.0.1"),
                    listen_port: 3000,
                    target_addr: String::from("162.250.124.66"),
                    target_port: 3000,
                    enable_websocket: false,
                },
            ],
            logging: LoggingConfig {
                level: String::from("info"),
            },
        }
    }

    fn from_file_or_default(path: &str) -> Self {
        match std::fs::read_to_string(path) {
            Ok(content) => {
                match toml::from_str::<Config>(&content) {
                    Ok(config) => {
                        println!("Configuration loaded from {}", path);
                        config
                    }
                    Err(e) => {
                        eprintln!("Failed to parse config file {}: {}. Using default configuration.", path, e);
                        Self::default()
                    }
                }
            }
            Err(_) => {
                println!("Config file {} not found. Using default configuration:", path);
                println!("  RPC: 127.0.0.1:8899 -> 162.250.124.66:8899");
                println!("  WebSocket: 127.0.0.1:8900 -> 162.250.124.66:8900");
                println!("  Service: 127.0.0.1:3000 -> 162.250.124.66:3000");
                Self::default()
            }
        }
    }
}

impl ProxyConfig {
    fn listen_addr(&self) -> String {
        format!("{}:{}", self.listen_addr, self.listen_port)
    }

    fn target_url(&self) -> String {
        format!("http://{}:{}", self.target_addr, self.target_port)
    }

}

#[derive(Clone)]
struct ProxyState {
    config: ProxyConfig,
    client: Client<hyper_util::client::legacy::connect::HttpConnector, BoxBody<Bytes, hyper::Error>>,
}

fn is_websocket_upgrade(req: &Request<hyper::body::Incoming>) -> bool {
    if let Some(connection) = req.headers().get(CONNECTION) {
        if let Ok(conn_str) = connection.to_str() {
            if conn_str.to_lowercase().contains("upgrade") {
                if let Some(upgrade) = req.headers().get(UPGRADE) {
                    if let Ok(upgrade_str) = upgrade.to_str() {
                        return upgrade_str.to_lowercase() == "websocket";
                    }
                }
            }
        }
    }
    false
}

async fn handle_websocket_upgrade(
    mut req: Request<hyper::body::Incoming>,
    state: ProxyState,
) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    let path = req.uri().path();
    let query = req.uri().query();

    info!(
        "[{}] WebSocket upgrade request: {}{}",
        state.config.name,
        path,
        query.map(|q| format!("?{}", q)).unwrap_or_default()
    );

    // Build target URL for HTTP request
    let target_url = if let Some(q) = query {
        format!("{}{}?{}", state.config.target_url(), path, q)
    } else {
        format!("{}{}", state.config.target_url(), path)
    };

    // Parse target URI
    let target_uri: Uri = match target_url.parse() {
        Ok(uri) => uri,
        Err(e) => {
            error!("[{}] Invalid target URI: {}", state.config.name, e);
            return Ok(Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(full("Invalid target URI"))
                .unwrap());
        }
    };

    // Get the client's upgrade handle before we modify the request
    let on_upgrade_client = hyper::upgrade::on(&mut req);

    // Update the request URI and Host header for target server
    *req.uri_mut() = target_uri;
    req.headers_mut().insert(
        HOST,
        HeaderValue::from_str(&format!("{}:{}", state.config.target_addr, state.config.target_port))
            .unwrap_or_else(|_| HeaderValue::from_static("localhost")),
    );

    // Forward the WebSocket upgrade request to the target server
    debug!(
        "[{}] Forwarding WebSocket upgrade to target server",
        state.config.name
    );

    match state.client.request(req.map(|body| body.boxed())).await {
        Ok(mut response) => {
            let status = response.status();
            info!(
                "[{}] Target server responded with status: {}",
                state.config.name, status
            );

            if status == StatusCode::SWITCHING_PROTOCOLS {
                // Get the upgrade handle from the target's response
                let on_upgrade_target = hyper::upgrade::on(&mut response);

                // Spawn task to proxy between client and target after both upgrades complete
                let proxy_name = state.config.name.clone();
                tokio::spawn(async move {
                    debug!("[{}] Waiting for both WebSocket upgrades to complete", proxy_name);

                    // Wait for both upgrades to complete
                    let (client_result, target_result) = tokio::join!(
                        on_upgrade_client,
                        on_upgrade_target
                    );

                    match (client_result, target_result) {
                        (Ok(client_upgraded), Ok(target_upgraded)) => {
                            info!("[{}] Both WebSocket upgrades completed, starting bidirectional proxy", proxy_name);
                            if let Err(e) = proxy_bidirectional(client_upgraded, target_upgraded, proxy_name.clone()).await {
                                error!("[{}] WebSocket proxy error: {}", proxy_name, e);
                            }
                        }
                        (Err(e), _) => {
                            error!("[{}] Failed to upgrade client connection: {}", proxy_name, e);
                        }
                        (_, Err(e)) => {
                            error!("[{}] Failed to upgrade target connection: {}", proxy_name, e);
                        }
                    }
                });
            }

            // Return the response from the target server to the client
            Ok(response.map(|body| body.boxed()))
        }
        Err(e) => {
            error!("[{}] Failed to forward WebSocket upgrade: {}", state.config.name, e);
            Ok(Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(full(format!("Failed to connect to target server: {}", e)))
                .unwrap())
        }
    }
}

// Proxy raw bytes bidirectionally between client and target
async fn proxy_bidirectional(
    client: Upgraded,
    target: Upgraded,
    proxy_name: String,
) -> Result<()> {
    let client = TokioIo::new(client);
    let target = TokioIo::new(target);

    let (mut client_read, mut client_write) = tokio::io::split(client);
    let (mut target_read, mut target_write) = tokio::io::split(target);

    let client_to_target = async {
        let mut buffer = vec![0u8; 8192];
        loop {
            match client_read.read(&mut buffer).await {
                Ok(0) => {
                    debug!("[{}] Client connection closed", proxy_name);
                    break;
                }
                Ok(n) => {
                    debug!("[{}] Client -> Target: {} bytes", proxy_name, n);
                    if let Err(e) = target_write.write_all(&buffer[..n]).await {
                        error!("[{}] Failed to write to target: {}", proxy_name, e);
                        break;
                    }
                    if let Err(e) = target_write.flush().await {
                        error!("[{}] Failed to flush target: {}", proxy_name, e);
                        break;
                    }
                }
                Err(e) => {
                    error!("[{}] Failed to read from client: {}", proxy_name, e);
                    break;
                }
            }
        }
    };

    let target_to_client = async {
        let mut buffer = vec![0u8; 8192];
        loop {
            match target_read.read(&mut buffer).await {
                Ok(0) => {
                    debug!("[{}] Target connection closed", proxy_name);
                    break;
                }
                Ok(n) => {
                    debug!("[{}] Target -> Client: {} bytes", proxy_name, n);
                    if let Err(e) = client_write.write_all(&buffer[..n]).await {
                        error!("[{}] Failed to write to client: {}", proxy_name, e);
                        break;
                    }
                    if let Err(e) = client_write.flush().await {
                        error!("[{}] Failed to flush client: {}", proxy_name, e);
                        break;
                    }
                }
                Err(e) => {
                    error!("[{}] Failed to read from target: {}", proxy_name, e);
                    break;
                }
            }
        }
    };

    // Run both directions concurrently
    tokio::select! {
        _ = client_to_target => {
            info!("[{}] Client to target stream ended", proxy_name);
        }
        _ = target_to_client => {
            info!("[{}] Target to client stream ended", proxy_name);
        }
    }

    info!("[{}] WebSocket connection closed", proxy_name);
    Ok(())
}


async fn proxy_handler(
    mut req: Request<hyper::body::Incoming>,
    state: ProxyState,
) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    // Check if this is a WebSocket upgrade request
    if state.config.enable_websocket && is_websocket_upgrade(&req) {
        return handle_websocket_upgrade(req, state).await;
    }

    let method = req.method().clone();
    let uri = req.uri().clone();
    let path = uri.path();
    let query = uri.query().unwrap_or("");

    info!(
        "[{}] HTTP proxy: {} {} {}",
        state.config.name,
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
        format!("{}{}", state.config.target_url(), path)
    } else {
        format!("{}{}?{}", state.config.target_url(), path, query)
    };

    // Parse target URI
    let target_uri = match target_url.parse::<hyper::Uri>() {
        Ok(uri) => uri,
        Err(e) => {
            error!("[{}] Invalid target URI: {}", state.config.name, e);
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
            info!("[{}] Response status: {}", state.config.name, response.status());
            Ok(response.map(|body| body.boxed()))
        }
        Err(e) => {
            error!("[{}] Proxy request failed: {}", state.config.name, e);
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

async fn run_proxy(config: ProxyConfig) -> Result<()> {
    let proxy_name = config.name.clone();

    info!("[{}] Starting proxy server", proxy_name);
    info!("[{}] Listening on: {}", proxy_name, config.listen_addr());
    info!("[{}] Forwarding to: {}", proxy_name, config.target_url());
    if config.enable_websocket {
        info!("[{}] WebSocket support: ENABLED", proxy_name);
    }

    // Parse listen address
    let addr: SocketAddr = config
        .listen_addr()
        .parse()
        .with_context(|| format!("[{}] Invalid listen address", proxy_name))?;

    // Create HTTP client
    let client = Client::builder(TokioExecutor::new()).build_http();

    let state = Arc::new(ProxyState {
        config: config.clone(),
        client,
    });

    // Bind TCP listener
    let listener = TcpListener::bind(addr)
        .await
        .with_context(|| format!("[{}] Failed to bind to address", proxy_name))?;

    info!("[{}] Server started successfully", proxy_name);

    // Accept connections
    loop {
        match listener.accept().await {
            Ok((stream, client_addr)) => {
                debug!("[{}] New connection from: {}", proxy_name, client_addr);
                let io = TokioIo::new(stream);
                let state_clone = state.clone();
                let name_clone = proxy_name.clone();

                tokio::spawn(async move {
                    if let Err(err) = http1::Builder::new()
                        .serve_connection(
                            io,
                            service_fn(move |req| {
                                let state = state_clone.clone();
                                async move { proxy_handler(req, state.as_ref().clone()).await }
                            }),
                        )
                        .with_upgrades()  // Enable HTTP upgrades for WebSocket
                        .await
                    {
                        error!("[{}] Error serving connection: {}", name_clone, err);
                    }
                });
            }
            Err(e) => {
                error!("[{}] Failed to accept connection: {}", proxy_name, e);
            }
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Load configuration (use default if config.toml not found)
    let config = Config::from_file_or_default("config.toml");

    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(&config.logging.level)),
        )
        .init();

    info!("Starting multi-port proxy server");
    info!("Found {} proxy configurations", config.proxies.len());

    // Start a separate task for each proxy configuration
    let mut handles = vec![];

    for proxy_config in config.proxies {
        let handle = tokio::spawn(async move {
            if let Err(e) = run_proxy(proxy_config.clone()).await {
                error!("[{}] Proxy failed: {}", proxy_config.name, e);
            }
        });
        handles.push(handle);
    }

    // Wait for all proxy tasks
    for handle in handles {
        let _ = handle.await;
    }

    Ok(())
}