# GitHub Releases 发布指南

本文档介绍如何将 solana-localhost 项目编译好的各平台版本发布到 GitHub Releases。

## 目录
- [手动发布流程](#手动发布流程)
- [GitHub Actions 自动发布](#github-actions-自动发布)
- [版本命名规范](#版本命名规范)
- [发布前检查清单](#发布前检查清单)

## 版本命名规范

采用语义化版本号 (Semantic Versioning):
- 格式: `v主版本.次版本.修订号` (例如: `v1.0.0`, `v1.2.3`)
- 主版本: 不兼容的 API 修改
- 次版本: 向下兼容的功能性新增
- 修订号: 向下兼容的问题修正

## 手动发布流程

### 1. 准备发布文件

首先，使用构建脚本编译所有平台版本:

```bash
# macOS/Linux
./build.sh all

# Windows PowerShell
.\build.ps1 all
```

编译完成后，`dist/` 目录会包含所有平台的压缩包:
- `solana-localhost-aarch64-apple-darwin.tar.gz`
- `solana-localhost-x86_64-apple-darwin.tar.gz`
- `solana-localhost-x86_64-unknown-linux-gnu.tar.gz`
- `solana-localhost-aarch64-unknown-linux-gnu.tar.gz`
- `solana-localhost-x86_64-pc-windows-msvc.zip`

### 2. 创建 Git Tag

```bash
# 确保代码已提交
git add .
git commit -m "准备发布 v1.0.0"

# 创建标签
git tag -a v1.0.0 -m "Release v1.0.0"

# 推送标签到 GitHub
git push origin v1.0.0
```

### 3. 在 GitHub 上创建 Release

1. 访问项目的 GitHub 页面
2. 点击右侧的 "Releases" 或访问 `https://github.com/你的用户名/solana-localhost/releases`
3. 点击 "Draft a new release"
4. 选择刚创建的 tag (v1.0.0)
5. 填写 Release 信息:
   - **Release title**: `v1.0.0`
   - **Description**: 填写更新内容，例如:
   ```markdown
   ## 更新内容
   - 初始版本发布
   - 支持 HTTP/HTTPS 代理
   - 支持多平台编译

   ## 支持平台
   - macOS (Intel/Apple Silicon)
   - Linux (x86_64/ARM64)
   - Windows (x86_64)
   ```
6. 上传编译好的文件 (从 `dist/` 目录拖拽所有压缩包)
7. 点击 "Publish release"

## GitHub Actions 自动发布

### 设置自动化发布工作流

创建 `.github/workflows/release.yml` 文件，当推送新的 tag 时自动构建并发布。

该工作流会:
1. 检测到新的版本 tag (v*.*.*)
2. 自动构建所有平台的二进制文件
3. 创建 GitHub Release 并上传文件

### 使用 GitHub Actions 发布

1. 更新版本号 (如需要，修改 Cargo.toml 中的版本)
2. 提交代码:
   ```bash
   git add .
   git commit -m "Bump version to 1.0.0"
   ```
3. 创建并推送 tag:
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```
4. GitHub Actions 会自动触发，构建并发布

## 使用 GitHub CLI 发布 (gh)

如果安装了 GitHub CLI，可以使用命令行创建 release:

```bash
# 安装 GitHub CLI (如未安装)
# macOS: brew install gh
# Linux: 参考 https://github.com/cli/cli/blob/trunk/docs/install_linux.md
# Windows: winget install --id GitHub.cli

# 登录 GitHub
gh auth login

# 创建 release 并上传文件
gh release create v1.0.0 \
  --title "v1.0.0" \
  --notes "初始版本发布" \
  dist/*.tar.gz \
  dist/*.zip
```

## 发布前检查清单

- [ ] 所有代码已提交并推送
- [ ] 更新了 `Cargo.toml` 中的版本号
- [ ] 更新了 `README.md` (如有必要)
- [ ] 本地测试通过
- [ ] 使用构建脚本成功编译所有平台版本
- [ ] 准备好发布说明 (changelog)
- [ ] 确认版本号遵循语义化版本规范

## 发布说明模板

```markdown
## 🚀 新功能
- 功能描述

## 🐛 修复
- 修复的问题

## 📝 改进
- 改进内容

## ⚠️ 重要变更
- 需要注意的变更

## 📦 下载说明

### macOS
- Intel: `solana-localhost-x86_64-apple-darwin.tar.gz`
- Apple Silicon: `solana-localhost-aarch64-apple-darwin.tar.gz`

### Linux
- x86_64: `solana-localhost-x86_64-unknown-linux-gnu.tar.gz`
- ARM64: `solana-localhost-aarch64-unknown-linux-gnu.tar.gz`

### Windows
- x86_64: `solana-localhost-x86_64-pc-windows-msvc.zip`

### 使用方法
```bash
# 解压 (macOS/Linux)
tar -xzf solana-localhost-*.tar.gz

# 解压 (Windows)
# 使用系统自带解压或 PowerShell:
Expand-Archive solana-localhost-*.zip -DestinationPath .

# 运行
./solana-localhost
```
```

## 故障排除

### 问题: GitHub Actions 构建失败
- 检查 workflow 文件语法
- 确认所有依赖都正确安装
- 查看 Actions 日志定位问题

### 问题: 上传文件过大
- GitHub Release 单个文件限制为 2GB
- 考虑使用 UPX 压缩二进制文件
- 或提供下载脚本而非直接上传

### 问题: 跨平台编译失败
- 确保安装了必要的交叉编译工具链
- 对于 Linux，可能需要安装 `cross` 工具
- Windows 编译可能需要安装 Visual Studio Build Tools

## 相关链接

- [GitHub Releases 文档](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [语义化版本规范](https://semver.org/lang/zh-CN/)
- [GitHub CLI 文档](https://cli.github.com/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)