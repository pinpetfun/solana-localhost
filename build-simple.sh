#!/bin/bash

# 简化版构建脚本 - 不需要 Docker
# 只编译 macOS 和 Windows 版本

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 加载 Rust 环境
source "$HOME/.cargo/env"

# 项目名称
PROJECT_NAME="solana-localhost"

# 创建发布目录
RELEASE_DIR="release"
mkdir -p "$RELEASE_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  快速构建脚本 - $PROJECT_NAME${NC}"
echo -e "${GREEN}  (macOS + Windows)${NC}"
echo -e "${GREEN}========================================${NC}"

# macOS x64
echo -e "\n${YELLOW}构建 macOS x64 版本...${NC}"
cargo build --release --target x86_64-apple-darwin
if [ $? -eq 0 ]; then
    cp "target/x86_64-apple-darwin/release/${PROJECT_NAME}" "$RELEASE_DIR/${PROJECT_NAME}-macos-x64"
    cd "$RELEASE_DIR"
    tar czf "${PROJECT_NAME}-macos-x64.tar.gz" "${PROJECT_NAME}-macos-x64"
    cd ..
    echo -e "${GREEN}✓ macOS x64 版本构建成功${NC}"
fi

# macOS ARM64 (Apple Silicon)
echo -e "\n${YELLOW}构建 macOS ARM64 版本...${NC}"
rustup target add aarch64-apple-darwin 2>/dev/null
cargo build --release --target aarch64-apple-darwin
if [ $? -eq 0 ]; then
    cp "target/aarch64-apple-darwin/release/${PROJECT_NAME}" "$RELEASE_DIR/${PROJECT_NAME}-macos-arm64"
    cd "$RELEASE_DIR"
    tar czf "${PROJECT_NAME}-macos-arm64.tar.gz" "${PROJECT_NAME}-macos-arm64"
    cd ..
    echo -e "${GREEN}✓ macOS ARM64 版本构建成功${NC}"
fi

# Windows x64
echo -e "\n${YELLOW}构建 Windows x64 版本...${NC}"
cargo build --release --target x86_64-pc-windows-gnu
if [ $? -eq 0 ]; then
    cp "target/x86_64-pc-windows-gnu/release/${PROJECT_NAME}.exe" "$RELEASE_DIR/${PROJECT_NAME}-windows-x64.exe"
    cd "$RELEASE_DIR"
    zip "${PROJECT_NAME}-windows-x64.zip" "${PROJECT_NAME}-windows-x64.exe"
    cd ..
    echo -e "${GREEN}✓ Windows x64 版本构建成功${NC}"
fi

# 显示结果
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  构建完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n发布文件:"
ls -lh "$RELEASE_DIR"/*.{zip,tar.gz} 2>/dev/null

echo -e "\n${YELLOW}注意:${NC}"
echo -e "• 此脚本只构建 macOS 和 Windows 版本"
echo -e "• 如需构建 Linux 版本，请使用 ./build-cross-platform.sh"
echo -e "• Linux 版本需要安装并运行 Docker Desktop"