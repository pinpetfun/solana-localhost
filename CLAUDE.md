# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个基于 Rust + Tokio + Hyper 的高性能 HTTP 反向代理工具,主要用于将本地端口映射到远程服务器(例如 Solana RPC 节点代理)。

## 核心架构

### 单文件架构
- **src/main.rs** - 所有代码都在单个文件中,包含:
  - `Config/ProxyConfig/LoggingConfig` - TOML 配置解析结构体
  - `ProxyState` - 代理状态,包含目标 URL 和 HTTP 客户端
  - `proxy_handler()` - 异步请求转发处理函数(核心逻辑)
  - `main()` - Tokio 异步运行时入口,负责初始化和监听连接

### 请求转发流程
1. TCP 监听器接受连接(main.rs:161-187)
2. 为每个连接 spawn 异步任务
3. `proxy_handler()` 接收请求,重写 URI,使用 Hyper Client 转发
4. 返回响应或 502 错误(连接失败时)

### 关键依赖
- **Tokio** - 异步运行时,使用 `#[tokio::main]`
- **Hyper v1 + hyper-util** - HTTP 服务器和客户端(注意使用 Hyper v1 API)
- **Tracing** - 结构化日志,日志级别可通过 `config.toml` 或 `RUST_LOG` 环境变量设置

## 常用命令

### 开发
```bash
# 编译开发版本
cargo build

# 运行(会读取 config.toml)
cargo run

# 发布版本编译
cargo build --release

# 运行编译好的二进制
./target/release/solana-localhost
```

### 测试
项目当前无测试套件。

### 跨平台编译

使用提供的构建脚本:
```bash
# macOS/Linux
./build.sh list                        # 查看支持的平台
./build.sh all                         # 构建所有平台
./build.sh x86_64-unknown-linux-gnu    # 构建特定平台

# Windows (PowerShell)
.\build.ps1 list
.\build.ps1 all
.\build.ps1 x86_64-pc-windows-msvc
```

构建产物会输出到 `dist/` 目录并自动打包。

手动编译特定平台:
```bash
# 添加编译目标
rustup target add x86_64-unknown-linux-gnu

# 编译
cargo build --release --target x86_64-unknown-linux-gnu
```

## 配置文件

**config.toml** - 必需的配置文件,包含:
- `[proxy]` - 监听地址/端口 + 目标地址/端口
- `[logging]` - 日志级别(trace/debug/info/warn/error)

程序启动时从当前目录读取此文件,修改后需重启程序。

## 开发注意事项

### Hyper v1 API 变更
本项目使用 Hyper v1,与旧版 API 有显著差异:
- 使用 `hyper_util::client::legacy::Client` 而非 `hyper::Client`
- 需要 `TokioExecutor::new()` 来构建客户端
- Body 类型使用 `BoxBody<Bytes, hyper::Error>`

### 错误处理
- 使用 `anyhow::Result` 进行错误传播
- 连接失败时返回 502 Bad Gateway
- 所有错误通过 `tracing::error!` 记录

### 日志调试
修改日志级别有两种方式:
```bash
# 方式1: 环境变量(优先级更高)
RUST_LOG=debug cargo run

# 方式2: 修改 config.toml 中的 logging.level
```
