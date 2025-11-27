# Solana Localhost Proxy

**English** | [日本語](./README_JP.md) | [中文](./README_CN.md)

Forward local port 8899 to remote Solana node (47.109.157.92:8899), allowing you to connect Phantom wallet to a local node.

## Download

Download the latest release: [https://github.com/pinpetfun/solana-localhost/releases/tag/v1.0.8](https://github.com/pinpetfun/solana-localhost/releases/tag/v1.0.8)

Choose the version for your system:
- **Windows**: `solana-localhost-windows-x64.zip`
- **macOS Intel**: `solana-localhost-macos-x64.tar.gz`
- **macOS M1/M2/M3**: `solana-localhost-macos-arm64.tar.gz`
- **Linux x64**: `solana-localhost-linux-x64.tar.gz`
- **Linux ARM64**: `solana-localhost-linux-arm64.tar.gz`

## Usage

### 1. Extract Files

**Windows:**
```bash
# Extract the zip file (use built-in Windows extraction or any unzip tool)
# Right-click on solana-localhost-windows-x64.zip and select "Extract All"
```

**macOS Intel:**
```bash
tar -xzf solana-localhost-macos-x64.tar.gz
```

**macOS Apple Silicon (M1/M2/M3):**
```bash
tar -xzf solana-localhost-macos-arm64.tar.gz
```

**Linux x64:**
```bash
tar -xzf solana-localhost-linux-x64.tar.gz
```

**Linux ARM64:**
```bash
tar -xzf solana-localhost-linux-arm64.tar.gz
```

### 2. Modify Configuration (Optional)

Edit the `config.toml` file. The default configuration is already set to forward to 47.109.157.92:8899:

```toml
[proxy]
listen_addr = "127.0.0.1"   # Local listening address
listen_port = 8899          # Local listening port
target_addr = "47.109.157.92"  # Target Solana node address
target_port = 8899          # Target port

[logging]
level = "info"
```

### 3. Run the Application

**Windows:**
```bash
solana-localhost-windows-x64.exe
```

**macOS/Linux:**
```bash
./solana-localhost-macos-x64   # macOS Intel
./solana-localhost-macos-arm64  # macOS Apple Silicon
./solana-localhost-linux-x64    # Linux
```

### 4. Configure Phantom Wallet

1. Open Phantom wallet
2. Go to Settings � Developer Settings
3. Set RPC node to `http://localhost:8899`
4. Your Phantom wallet is now connected to the local node

## Running Output

When the program starts, it will display:
```
2025-11-26T10:00:00.000Z  INFO solana_localhost: Starting HTTP proxy server
2025-11-26T10:00:00.001Z  INFO solana_localhost: Listening on: 127.0.0.1:8899
2025-11-26T10:00:00.002Z  INFO solana_localhost: Forwarding to: http://47.109.157.92:8899
2025-11-26T10:00:00.003Z  INFO solana_localhost: Server started successfully
```

## License

MIT License