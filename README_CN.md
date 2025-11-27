# Solana Localhost Proxy

[English](./README.md) | [日本語](./README_JP.md) | **中文**

将本地 8899 端口转发到远程 Solana 节点（47.109.157.92:8899），让你可以使用 Phantom 钱包连接本地节点。

## 下载

下载最新版本：[https://github.com/pinpetfun/solana-localhost/releases/tag/v1.0.6](https://github.com/pinpetfun/solana-localhost/releases/tag/v1.0.6)

选择适合你系统的版本：
- **Windows**: `solana-localhost-windows-x64.zip`
- **macOS Intel**: `solana-localhost-macos-x64.tar.gz`
- **macOS M1/M2/M3**: `solana-localhost-macos-arm64.tar.gz`
- **Linux x64**: `solana-localhost-linux-x64.tar.gz`
- **Linux ARM64**: `solana-localhost-linux-arm64.tar.gz`

## 使用方法

### 1. 解压文件

**Windows:**
```bash
# 解压 zip 文件
```

**macOS/Linux:**
```bash
tar -xzf solana-localhost-*.tar.gz
```

### 2. 修改配置（可选）

编辑 `config.toml` 文件，默认配置已设置为转发到 47.109.157.92:8899：

```toml
[proxy]
listen_addr = "127.0.0.1"   # 本地监听地址
listen_port = 8899          # 本地监听端口
target_addr = "47.109.157.92"  # 目标 Solana 节点地址
target_port = 8899          # 目标端口

[logging]
level = "info"
```

### 3. 运行程序

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

### 4. 配置 Phantom 钱包

1. 打开 Phantom 钱包
2. 进入设置 → 开发者设置
3. 将 RPC 节点设置为 `http://localhost:8899`
4. 现在你的 Phantom 钱包已连接到本地节点

## 运行效果

程序启动后会显示：
```
2025-11-26T10:00:00.000Z  INFO solana_localhost: Starting HTTP proxy server
2025-11-26T10:00:00.001Z  INFO solana_localhost: Listening on: 127.0.0.1:8899
2025-11-26T10:00:00.002Z  INFO solana_localhost: Forwarding to: http://47.109.157.92:8899
2025-11-26T10:00:00.003Z  INFO solana_localhost: Server started successfully
```

## 许可证

MIT License