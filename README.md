# Solana Localhost Proxy

一个基于 Rust + Tokio + Hyper 的高性能 HTTP 端口映射/反向代理工具。

## 功能特性

- ✅ 高性能异步 HTTP 代理 (基于 Tokio + Hyper v1)
- ✅ 支持 TOML 配置文件
- ✅ 完整的日志输出 (基于 tracing)
- ✅ 跨平台支持 (Windows, Linux, macOS)
- ✅ 简单易用,零依赖运行

## 使用场景

将本地端口 `localhost:8899` 映射到远程服务器 `192.168.18.5:8899`,常用于:

- Solana RPC 节点代理
- 开发环境端口转发
- 网络调试和测试

## 快速开始

### 1. 编译项目

```bash
# 开发版本
cargo build

# 发布版本 (推荐)
cargo build --release
```

### 2. 配置文件

编辑 `config.toml`:

```toml
[proxy]
# 本地监听地址和端口
listen_addr = "127.0.0.1"
listen_port = 8899

# 目标服务器地址和端口
target_addr = "192.168.18.5"
target_port = 8899

[logging]
# 日志级别: trace, debug, info, warn, error
level = "info"
```

### 3. 运行程序

```bash
# 开发版本
cargo run

# 或直接运行编译好的二进制文件
./target/release/solana-localhost
```

## 跨平台编译

本项目提供了多种方式进行跨平台编译。

### 方法一: 使用构建脚本 (推荐)

#### Linux / macOS:

```bash
# 查看所有支持的目标平台
./build.sh list

# 构建所有平台
./build.sh all

# 构建特定平台
./build.sh x86_64-unknown-linux-gnu
./build.sh x86_64-pc-windows-gnu
./build.sh x86_64-apple-darwin
```

#### Windows (PowerShell):

```powershell
# 查看所有支持的目标平台
.\build.ps1 list

# 构建所有平台
.\build.ps1 all

# 构建特定平台
.\build.ps1 x86_64-pc-windows-msvc
.\build.ps1 x86_64-unknown-linux-gnu
```

构建脚本会自动:
- 检查并安装所需的编译目标
- 编译二进制文件
- 将产物复制到 `dist/` 目录
- 创建压缩包 (Windows 使用 .zip, 其他平台使用 .tar.gz)

### 方法二: 使用 Cargo 直接编译

首先安装编译目标:

```bash
# 安装编译目标
rustup target add x86_64-unknown-linux-gnu
rustup target add x86_64-pc-windows-gnu
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-darwin
```

然后编译:

```bash
# Linux x86_64
cargo build --release --target x86_64-unknown-linux-gnu

# Linux x86_64 (musl - 静态链接)
cargo build --release --target x86_64-unknown-linux-musl

# Windows x86_64
cargo build --release --target x86_64-pc-windows-gnu
# 或使用 MSVC (需要在 Windows 上)
cargo build --release --target x86_64-pc-windows-msvc

# macOS Intel
cargo build --release --target x86_64-apple-darwin

# macOS Apple Silicon (M1/M2/M3)
cargo build --release --target aarch64-apple-darwin
```

编译产物位于 `target/<target-name>/release/` 目录。

### 方法三: 使用 GitHub Actions 自动构建

当你推送带有 `v*` 标签的提交时,GitHub Actions 会自动构建所有平台的二进制文件并创建 Release。

```bash
# 创建并推送标签
git tag v0.1.0
git push origin v0.1.0
```

或者手动触发构建:
1. 访问 GitHub 仓库的 Actions 页面
2. 选择 "Release" workflow
3. 点击 "Run workflow"

自动构建支持的平台:
- Linux x86_64 (glibc)
- Linux x86_64 (musl - 静态链接)
- Windows x86_64 (MSVC)
- macOS x86_64 (Intel)
- macOS aarch64 (Apple Silicon)

### 跨平台编译注意事项

1. **macOS 目标**: 只能在 macOS 系统上编译 macOS 目标
2. **Windows MSVC**: 需要在 Windows 上使用 MSVC 工具链
3. **Linux musl**: 在 Ubuntu/Debian 上需要安装 `musl-tools`:
   ```bash
   sudo apt-get install musl-tools
   ```
4. **交叉编译**: 对于复杂的交叉编译,可以使用 [cross](https://github.com/cross-rs/cross):
   ```bash
   cargo install cross
   cross build --release --target x86_64-unknown-linux-musl
   ```

## 运行示例

启动后你会看到:

```
2025-11-26T10:00:00.000Z  INFO solana_localhost: Starting HTTP proxy server
2025-11-26T10:00:00.001Z  INFO solana_localhost: Listening on: 127.0.0.1:8899
2025-11-26T10:00:00.002Z  INFO solana_localhost: Forwarding to: http://192.168.18.5:8899
2025-11-26T10:00:00.003Z  INFO solana_localhost: Server started successfully
```

测试请求:

```bash
curl http://localhost:8899/health
```

程序会转发请求到 `http://192.168.18.5:8899/health` 并返回结果。

## 日志级别

通过环境变量或配置文件设置日志级别:

```bash
# 环境变量方式
RUST_LOG=debug ./target/release/solana-localhost

# 或修改 config.toml 中的 logging.level
```

可用的日志级别:
- `trace` - 最详细
- `debug` - 调试信息
- `info` - 常规信息 (默认)
- `warn` - 警告
- `error` - 仅错误

## 技术栈

- **Tokio** - 异步运行时
- **Hyper** - HTTP 库 (v1.x)
- **Hyper-util** - Hyper 工具库
- **Tracing** - 结构化日志
- **Serde** - 序列化/反序列化
- **TOML** - 配置文件解析
- **Anyhow** - 错误处理

## 性能特点

- 零拷贝转发
- 异步 I/O
- 多连接并发处理
- 低内存占用

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request!
