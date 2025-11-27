#!/bin/bash

# 使用 zigbuild 进行跨平台编译（不需要 Docker）
# 适用于 macOS 编译 Linux 版本 

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 加载 Rust 环境
source "$HOME/.cargo/env"

# 项目名称
PROJECT_NAME="solana-localhost"

# 创建发布目录
RELEASE_DIR="release"
mkdir -p "$RELEASE_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Zigbuild 跨平台构建脚本${NC}"
echo -e "${GREEN}  无需 Docker 即可编译 Linux 版本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查 zig 是否安装
check_zig() {
    if ! command -v zig &> /dev/null; then
        echo -e "${YELLOW}未检测到 zig，正在安装...${NC}"
        if command -v brew &> /dev/null; then
            brew install zig
        else
            echo -e "${RED}请先安装 zig: https://ziglang.org/download/${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Zig 版本: $(zig version)${NC}"
    fi
}

# 检查 cargo-zigbuild 是否安装
check_zigbuild() {
    if ! command -v cargo-zigbuild &> /dev/null; then
        echo -e "${YELLOW}未检测到 cargo-zigbuild，正在安装...${NC}"
        cargo install cargo-zigbuild
    else
        echo -e "${GREEN}✓ cargo-zigbuild 已安装${NC}"
    fi
}

# 构建函数
build_target() {
    local TARGET=$1
    local OUTPUT_NAME=$2
    local USE_ZIGBUILD=$3

    echo -e "\n${YELLOW}正在构建: $OUTPUT_NAME${NC}"
    echo -e "目标架构: $TARGET"

    # 添加目标
    rustup target add "$TARGET" 2>/dev/null

    # 选择构建命令
    if [ "$USE_ZIGBUILD" = "true" ]; then
        cargo zigbuild --release --target "$TARGET"
    else
        cargo build --release --target "$TARGET"
    fi

    if [ $? -eq 0 ]; then
        # 复制编译结果到发布目录
        if [[ "$TARGET" == *"windows"* ]]; then
            cp "target/$TARGET/release/${PROJECT_NAME}.exe" "$RELEASE_DIR/$OUTPUT_NAME" 2>/dev/null || \
            cp "target/$TARGET/release/${PROJECT_NAME}" "$RELEASE_DIR/$OUTPUT_NAME"
        else
            cp "target/$TARGET/release/${PROJECT_NAME}" "$RELEASE_DIR/$OUTPUT_NAME"
        fi

        # 压缩文件
        cd "$RELEASE_DIR"
        if [[ "$OUTPUT_NAME" == *.exe ]]; then
            zip "${OUTPUT_NAME%.exe}.zip" "$OUTPUT_NAME"
        else
            tar czf "${OUTPUT_NAME}.tar.gz" "$OUTPUT_NAME"
        fi
        cd ..

        echo -e "${GREEN}✓ 成功构建: $OUTPUT_NAME${NC}"
        return 0
    else
        echo -e "${RED}✗ 构建失败: $OUTPUT_NAME${NC}"
        return 1
    fi
}

# 环境准备
echo -e "\n${BLUE}=== 环境检查 ===${NC}"
check_zig
check_zigbuild

# macOS 本地编译（不需要 zigbuild）
echo -e "\n${BLUE}=== macOS 版本 ===${NC}"
build_target "x86_64-apple-darwin" "${PROJECT_NAME}-macos-x64" "false"

# 如果是 Apple Silicon Mac，也编译 ARM64 版本
if [[ $(uname -m) == "arm64" ]]; then
    build_target "aarch64-apple-darwin" "${PROJECT_NAME}-macos-arm64" "false"
fi

# Linux 版本（使用 zigbuild）
echo -e "\n${BLUE}=== Linux 版本 (使用 zigbuild) ===${NC}"
build_target "x86_64-unknown-linux-gnu" "${PROJECT_NAME}-linux-x64" "true"
build_target "aarch64-unknown-linux-gnu" "${PROJECT_NAME}-linux-arm64" "true"

# Windows 版本（可以用 zigbuild 也可以用 mingw）
echo -e "\n${BLUE}=== Windows 版本 ===${NC}"
# 尝试使用 zigbuild
build_target "x86_64-pc-windows-gnu" "${PROJECT_NAME}-windows-x64.exe" "true"

# 显示构建结果
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  构建完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n发布文件位于: ${RELEASE_DIR}/"
ls -lh "$RELEASE_DIR"/*.{zip,tar.gz} 2>/dev/null

echo -e "\n${YELLOW}优势说明:${NC}"
echo -e "• 不需要 Docker，直接在 macOS 上编译"
echo -e "• 使用 Zig 作为 C/C++ 编译器和链接器"
echo -e "• 支持所有主流平台的交叉编译"
echo -e "• 编译速度更快，资源占用更少"