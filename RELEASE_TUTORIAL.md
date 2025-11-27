# 📚 Solana Localhost 发布教程

本教程将详细指导你如何将 solana-localhost 项目发布到 GitHub Releases，包含完整的步骤说明和常见问题解决方案。

## 📋 目录

1. [环境准备](#环境准备)
2. [快速发布（推荐）](#快速发布推荐)
3. [发布方式对比](#发布方式对比)
4. [详细步骤说明](#详细步骤说明)
5. [常见问题与解决](#常见问题与解决)

## 🔧 环境准备

### 必需工具

```bash
# 检查 Git
git --version

# 检查 Rust
rustc --version
cargo --version
```

### 推荐工具（可选但建议安装）

```bash
# macOS 安装 GitHub CLI
brew install gh

# 登录 GitHub
gh auth login

# macOS 安装 Zig（用于交叉编译 Linux）
brew install zig
cargo install cargo-zigbuild
```

## 🚀 快速发布（推荐）

### 方式 1：使用发布脚本（最简单）

```bash
# 1. 确保 config.toml 存在（会自动创建默认配置）
ls config.toml

# 2. 运行发布脚本（自动构建所有平台并发布）
./release.sh v1.0.0

# 可选参数：
./release.sh -z v1.0.0   # 强制使用 zigbuild（macOS 推荐）
./release.sh -d v1.0.0   # 创建草稿 release
./release.sh -c          # 仅检查环境，不执行发布
```

### 方式 2：使用 GitHub Actions（全自动）

```bash
# 1. 提交所有代码
git add .
git commit -m "准备发布 v1.0.0"
git push

# 2. 创建并推送 tag（自动触发 Actions）
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 3. 访问 GitHub Actions 页面查看进度
# https://github.com/你的用户名/solana-localhost/actions
```

## 📊 发布方式对比

| 特性 | 发布脚本 (release.sh) | GitHub Actions | 手动发布 |
|------|------------------------|----------------|----------|
| **难度** | ⭐ 简单 | ⭐ 简单 | ⭐⭐⭐ 复杂 |
| **速度** | 快速（本地构建） | 中等（云端构建） | 慢（手动操作） |
| **依赖** | 需要 GitHub CLI | 无需本地工具 | 无特殊依赖 |
| **自动化** | 半自动 | 全自动 | 手动 |
| **适用场景** | 日常发布 | CI/CD 集成 | 特殊需求 |
| **构建方式** | 支持 zigbuild | 支持 zigbuild | 需手动选择 |

## 📝 详细步骤说明

### 步骤 1：准备发布内容

#### 1.1 更新版本号

编辑 `Cargo.toml`：
```toml
[package]
name = "solana-localhost"
version = "1.0.0"  # 更新此处版本号
```

#### 1.2 确认 config.toml 存在

```bash
# 检查配置文件
ls config.toml

# 如不存在，脚本会自动创建默认配置
# 或手动创建：
cat > config.toml << 'EOF'
[proxy]
listen_host = "127.0.0.1"
listen_port = 8899
target_host = "api.mainnet-beta.solana.com"
target_port = 443

[logging]
level = "info"
EOF
```

### 步骤 2：选择构建方式

#### 选项 A：使用 Zigbuild（macOS 推荐，无需 Docker）

```bash
# 安装 zigbuild
brew install zig
cargo install cargo-zigbuild

# 使用 zigbuild 构建
./build-zigbuild.sh

# 或通过 release.sh
./release.sh -z v1.0.0
```

**优势：**
- ✅ 无需 Docker
- ✅ 构建速度快
- ✅ 支持所有平台交叉编译
- ✅ 资源占用少

#### 选项 B：使用传统 Docker 构建

```bash
# 确保 Docker 已启动
docker --version

# 使用传统方式构建
./build.sh all

# 或通过 release.sh
./release.sh -t v1.0.0
```

### 步骤 3：创建发布

#### 使用发布脚本（推荐）

```bash
# 完整流程示例
# 1. 检查环境
./release.sh -c

# 2. 构建并发布
./release.sh v1.0.0

# 脚本会自动：
# - 构建所有平台版本
# - 将 config.toml 打包进每个压缩包
# - 创建 Git tag
# - 生成 changelog
# - 上传到 GitHub Releases
```

#### 手动创建发布

```bash
# 1. 构建
./build-zigbuild.sh  # 或 ./build.sh all

# 2. 创建 tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 3. 使用 GitHub CLI 创建 release
gh release create v1.0.0 \
  --title "v1.0.0" \
  --notes "发布说明" \
  dist/*.tar.gz \
  dist/*.zip

# 或在 GitHub 网页上手动创建
```

### 步骤 4：验证发布

```bash
# 查看发布页面
gh release view v1.0.0

# 或访问
# https://github.com/你的用户名/solana-localhost/releases
```

## ❓ 常见问题与解决

### Q1: 构建 Linux 版本失败

**问题**：在 macOS 上无法编译 Linux 版本

**解决方案**：
```bash
# 使用 zigbuild 代替传统方式
brew install zig
cargo install cargo-zigbuild
./build-zigbuild.sh

# 或强制使用 zigbuild
./release.sh -z v1.0.0
```

### Q2: GitHub CLI 认证失败

**问题**：`gh: authentication required`

**解决方案**：
```bash
# 重新登录
gh auth login

# 选择认证方式：
# 1. GitHub.com
# 2. HTTPS
# 3. 使用浏览器认证
```

### Q3: Tag 已存在

**问题**：`fatal: tag 'v1.0.0' already exists`

**解决方案**：
```bash
# 删除本地 tag
git tag -d v1.0.0

# 删除远程 tag（谨慎）
git push origin :refs/tags/v1.0.0

# 或使用新版本号
./release.sh v1.0.1
```

### Q4: 发布包缺少 config.toml

**问题**：下载的压缩包中没有配置文件

**解决方案**：
```bash
# 确保 config.toml 存在
ls config.toml

# 使用更新后的脚本重新发布
./release.sh v1.0.0
```

### Q5: Windows 编译失败

**问题**：Windows 目标编译失败

**解决方案**：
```bash
# 在 macOS 上使用 zigbuild 编译 Windows 版本
cargo zigbuild --release --target x86_64-pc-windows-gnu

# 或使用 GitHub Actions 构建
# （Actions 会在 Windows 环境中原生编译）
```

## 📦 发布内容说明

每个发布包包含：

```
solana-localhost-<platform>.tar.gz/
├── solana-localhost       # 可执行文件
├── config.toml            # 配置文件
└── README.md             # 使用说明
```

### 平台文件命名

- **macOS Intel**: `solana-localhost-x86_64-apple-darwin.tar.gz`
- **macOS M1/M2**: `solana-localhost-aarch64-apple-darwin.tar.gz`
- **Linux x64**: `solana-localhost-x86_64-unknown-linux-gnu.tar.gz`
- **Linux ARM64**: `solana-localhost-aarch64-unknown-linux-gnu.tar.gz`
- **Windows x64**: `solana-localhost-x86_64-pc-windows-msvc.zip`

## 🎯 最佳实践

1. **版本管理**
   - 遵循语义化版本规范 (v主.次.修订)
   - 重要功能更新升级次版本
   - Bug 修复升级修订版本

2. **发布说明**
   - 列出主要更新内容
   - 说明破坏性变更
   - 提供升级指南

3. **测试验证**
   - 发布前在本地测试
   - 使用草稿 release 预览
   - 下载并验证发布包

4. **自动化优先**
   - 优先使用 GitHub Actions
   - 备用 release.sh 脚本
   - 避免手动操作

## 🔗 相关资源

- [GitHub Releases 官方文档](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Zig 官网](https://ziglang.org/)
- [cargo-zigbuild 项目](https://github.com/rust-cross/cargo-zigbuild)
- [GitHub CLI 文档](https://cli.github.com/manual/)

## 📞 获取帮助

如遇到问题：
1. 查看本文档的常见问题部分
2. 运行 `./release.sh -h` 查看帮助
3. 查看 GitHub Actions 日志
4. 在项目 Issues 中提问

---

*最后更新：2024*