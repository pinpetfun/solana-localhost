#!/bin/bash

# GitHub Release 发布脚本
# 用于快速创建 release 并上传构建产物

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."

    if ! command_exists git; then
        print_error "Git 未安装"
        exit 1
    fi

    if ! command_exists gh; then
        print_warning "GitHub CLI (gh) 未安装"
        echo "请安装 GitHub CLI: https://cli.github.com/"
        echo "macOS: brew install gh"
        echo "Linux: 参考 https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        echo ""
        echo "或者使用手动发布方式（见 RELEASE_GUIDE.md）"
        exit 1
    fi

    print_success "依赖检查完成"
}

# 检查是否有未提交的更改
check_git_status() {
    print_info "检查 Git 状态..."

    if ! git diff-index --quiet HEAD --; then
        print_warning "检测到未提交的更改："
        git status --short
        echo ""
        read -p "是否继续？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "已取消"
            exit 1
        fi
    fi

    print_success "Git 状态检查完成"
}

# 创建默认配置文件
create_default_config() {
    cat > config.toml << 'EOF'
[proxy]
# 监听地址和端口
listen_host = "127.0.0.1"
listen_port = 8899

# 目标服务器地址和端口
target_host = "api.mainnet-beta.solana.com"
target_port = 443

[logging]
# 日志级别：trace, debug, info, warn, error
level = "info"
EOF
    print_success "已创建默认 config.toml 文件"
}

# 获取版本号
get_version() {
    if [ -z "$1" ]; then
        # 从 Cargo.toml 读取版本号
        if [ -f "Cargo.toml" ]; then
            VERSION=$(grep "^version" Cargo.toml | head -1 | cut -d'"' -f2)
            print_info "从 Cargo.toml 读取版本: $VERSION"
        else
            print_error "未找到 Cargo.toml，请手动指定版本号"
            exit 1
        fi
    else
        VERSION=$1
    fi

    # 确保版本号以 v 开头
    if [[ ! "$VERSION" == v* ]]; then
        VERSION="v$VERSION"
    fi

    echo "$VERSION"
}

# 构建所有平台
build_all() {
    local build_method=${1:-"auto"}

    print_info "开始构建所有平台..."

    # 自动选择构建方式
    if [ "$build_method" = "auto" ]; then
        if [ -f "./build-simple.sh" ] && [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "检测到 macOS 环境，使用简化构建脚本"
            build_method="simple"
        elif [ -f "./build-zigbuild.sh" ] && [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "检测到 macOS 环境，优先使用 zigbuild 构建（无需 Docker）"
            build_method="zigbuild"
        elif [ -f "./build.sh" ]; then
            build_method="traditional"
        else
            print_error "未找到构建脚本"
            exit 1
        fi
    fi

    # 执行构建
    case $build_method in
        simple)
            if [ -f "./build-simple.sh" ]; then
                print_info "使用简化构建脚本..."
                ./build-simple.sh

                # 检查 config.toml 是否存在
                if [ ! -f "config.toml" ]; then
                    print_warning "未找到 config.toml 文件，将使用默认配置"
                fi

                # 准备发布目录
                mkdir -p dist
                if [ -d "release" ]; then
                    print_info "准备发布文件，加入 config.toml..."

                    # 处理 tar.gz 文件
                    for archive in release/*.tar.gz; do
                        if [ -f "$archive" ]; then
                            basename=$(basename "$archive" .tar.gz)
                            # 创建临时目录
                            mkdir -p "dist/tmp_${basename}"
                            # 解压
                            tar -xzf "$archive" -C "dist/tmp_${basename}"
                            # 添加配置文件
                            cp config.toml "dist/tmp_${basename}/config.toml"
                            # 创建 README
                            cat > "dist/tmp_${basename}/README.md" << 'READMEEOF'
# Solana Localhost Proxy

## 快速开始

1. 编辑 `config.toml` 配置文件
2. 运行程序:
   ```bash
   ./solana-localhost-macos-x64  # macOS
   ```

## 配置说明

编辑 `config.toml`:

```toml
[proxy]
listen_addr = "127.0.0.1"   # 本地监听地址
listen_port = 8899          # 本地监听端口
target_addr = "192.168.18.5" # 目标 Solana 节点地址
target_port = 8899          # 目标 Solana 节点端口

[logging]
level = "info"  # 日志级别: trace, debug, info, warn, error
```
READMEEOF
                            # 重新打包
                            cd "dist/tmp_${basename}"
                            tar -czf "../${basename}.tar.gz" .
                            cd ../..
                            # 清理
                            rm -rf "dist/tmp_${basename}"
                            print_success "打包: ${basename}.tar.gz"
                        fi
                    done

                    # 处理 zip 文件
                    for archive in release/*.zip; do
                        if [ -f "$archive" ]; then
                            basename=$(basename "$archive" .zip)
                            # 创建临时目录
                            mkdir -p "dist/tmp_${basename}"
                            # 解压
                            unzip -q "$archive" -d "dist/tmp_${basename}"
                            # 添加配置文件
                            cp config.toml "dist/tmp_${basename}/config.toml"
                            # 创建 README
                            cat > "dist/tmp_${basename}/README.md" << 'READMEEOF'
# Solana Localhost Proxy

## 快速开始

1. 编辑 `config.toml` 配置文件
2. 运行程序:
   ```
   solana-localhost-windows-x64.exe
   ```

## 配置说明

编辑 `config.toml`:

```toml
[proxy]
listen_addr = "127.0.0.1"   # 本地监听地址
listen_port = 8899          # 本地监听端口
target_addr = "192.168.18.5" # 目标 Solana 节点地址
target_port = 8899          # 目标 Solana 节点端口

[logging]
level = "info"  # 日志级别: trace, debug, info, warn, error
```
READMEEOF
                            # 重新打包
                            cd "dist/tmp_${basename}"
                            zip -q "../${basename}.zip" *
                            cd ../..
                            # 清理
                            rm -rf "dist/tmp_${basename}"
                            print_success "打包: ${basename}.zip"
                        fi
                    done
                fi

                print_success "简化构建完成（已包含 config.toml 和 README）"
            else
                print_error "未找到 build-simple.sh 脚本"
                exit 1
            fi
            ;;
        zigbuild)
            if [ -f "./build-zigbuild.sh" ]; then
                print_info "使用 zigbuild 构建（推荐，无需 Docker）..."
                ./build-zigbuild.sh

                # 检查 config.toml 是否存在
                if [ ! -f "config.toml" ]; then
                    print_warning "未找到 config.toml 文件，将创建默认配置"
                    create_default_config
                fi

                # 将 release 目录的文件重新打包，加入 config.toml
                mkdir -p dist
                if [ -d "release" ]; then
                    print_info "重新打包，加入 config.toml..."

                    # 处理每个压缩包
                    for archive in release/*.tar.gz; do
                        if [ -f "$archive" ]; then
                            basename=$(basename "$archive" .tar.gz)
                            # 解压原文件
                            tar -xzf "$archive" -C release/
                            # 创建临时目录
                            mkdir -p "release/tmp_${basename}"
                            # 移动文件到临时目录并添加 config.toml
                            mv "release/${basename%-*}" "release/tmp_${basename}/" 2>/dev/null || \
                            mv release/solana-localhost* "release/tmp_${basename}/" 2>/dev/null
                            cp config.toml "release/tmp_${basename}/"
                            # 重新打包
                            cd release
                            tar -czf "../dist/${basename}.tar.gz" -C "tmp_${basename}" .
                            cd ..
                            # 清理临时文件
                            rm -rf "release/tmp_${basename}"
                        fi
                    done

                    for archive in release/*.zip; do
                        if [ -f "$archive" ]; then
                            basename=$(basename "$archive" .zip)
                            # 解压原文件
                            unzip -q "$archive" -d "release/tmp_${basename}"
                            # 添加 config.toml
                            cp config.toml "release/tmp_${basename}/"
                            # 重新打包
                            cd "release/tmp_${basename}"
                            zip -q "../../dist/${basename}.zip" *
                            cd ../..
                            # 清理临时文件
                            rm -rf "release/tmp_${basename}"
                        fi
                    done
                fi

                print_success "zigbuild 构建完成（已包含 config.toml）"
            else
                print_error "未找到 build-zigbuild.sh 脚本"
                exit 1
            fi
            ;;
        traditional|docker)
            if [ -f "./build.sh" ]; then
                print_info "使用传统方式构建（需要 Docker）..."
                ./build.sh all
                print_success "构建完成"
            else
                print_error "未找到 build.sh 脚本"
                exit 1
            fi
            ;;
        *)
            print_error "未知的构建方式: $build_method"
            exit 1
            ;;
    esac
}

# 创建 release
create_release() {
    local version=$1
    local draft=${2:-false}

    print_info "创建 Release: $version"

    # 检查 tag 是否已存在
    if git rev-parse "$version" >/dev/null 2>&1; then
        print_warning "Tag $version 已存在"
        read -p "是否使用现有 tag？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "已取消"
            exit 1
        fi
    else
        # 创建 tag
        print_info "创建 Git tag: $version"
        git tag -a "$version" -m "Release $version"
        git push origin "$version"
        print_success "Tag 创建成功"
    fi

    # 生成 changelog
    print_info "生成 changelog..."
    PREV_TAG=$(git describe --tags --abbrev=0 "$version^" 2>/dev/null || echo "")
    if [ -z "$PREV_TAG" ]; then
        CHANGELOG=$(git log --pretty=format:"- %s" HEAD)
    else
        CHANGELOG=$(git log --pretty=format:"- %s" "${PREV_TAG}..$version")
    fi

    # 创建 release notes
    NOTES="## 📋 更新内容

$CHANGELOG

## 📦 下载说明

### macOS
- Intel: \`solana-localhost-x86_64-apple-darwin.tar.gz\`
- Apple Silicon: \`solana-localhost-aarch64-apple-darwin.tar.gz\`

### Linux
- x86_64: \`solana-localhost-x86_64-unknown-linux-gnu.tar.gz\`
- ARM64: \`solana-localhost-aarch64-unknown-linux-gnu.tar.gz\`

### Windows
- x86_64: \`solana-localhost-x86_64-pc-windows-msvc.zip\`

### 使用方法
\`\`\`bash
# 解压 (macOS/Linux)
tar -xzf solana-localhost-*.tar.gz

# 运行
./solana-localhost
\`\`\`"

    # 创建 release
    if [ "$draft" = true ]; then
        print_info "创建草稿 Release..."
        gh release create "$version" \
            --draft \
            --title "$version" \
            --notes "$NOTES" \
            dist/*.tar.gz \
            dist/*.zip
    else
        print_info "创建正式 Release..."
        gh release create "$version" \
            --title "$version" \
            --notes "$NOTES" \
            dist/*.tar.gz \
            dist/*.zip
    fi

    print_success "Release 创建成功！"
    echo "访问: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/releases/tag/$version"
}

# 显示帮助
show_help() {
    cat << EOF
用法: ./release.sh [选项] [版本号]

选项:
    -h, --help          显示帮助信息
    -b, --build         构建所有平台（默认：是）
    -n, --no-build      跳过构建步骤
    -d, --draft         创建草稿 release
    -c, --check         仅检查，不执行发布
    -z, --zigbuild      强制使用 zigbuild 构建（macOS 推荐）
    -t, --traditional   强制使用传统 Docker 构建

示例:
    ./release.sh                # 自动选择构建方式，使用 Cargo.toml 版本
    ./release.sh v1.0.0         # 指定版本号
    ./release.sh -z v1.0.0      # 使用 zigbuild 构建（无需 Docker）
    ./release.sh -t v1.0.0      # 使用传统 Docker 构建
    ./release.sh -n v1.0.0      # 跳过构建，直接发布
    ./release.sh -d v1.0.0      # 创建草稿
    ./release.sh -c             # 仅检查环境

说明:
    - macOS 环境下自动优先使用 zigbuild（无需 Docker）
    - 构建产物会自动包含 config.toml 配置文件
    - 如无 config.toml，将自动创建默认配置

EOF
}

# 主函数
main() {
    local version=""
    local do_build=true
    local draft=false
    local check_only=false
    local build_method="auto"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--build)
                do_build=true
                shift
                ;;
            -n|--no-build)
                do_build=false
                shift
                ;;
            -d|--draft)
                draft=true
                shift
                ;;
            -c|--check)
                check_only=true
                shift
                ;;
            -z|--zigbuild)
                build_method="zigbuild"
                shift
                ;;
            -t|--traditional)
                build_method="traditional"
                shift
                ;;
            -*)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                version=$1
                shift
                ;;
        esac
    done

    # 检查依赖
    check_dependencies

    # 检查 git 状态
    check_git_status

    if [ "$check_only" = true ]; then
        print_success "环境检查完成，一切就绪！"
        exit 0
    fi

    # 获取版本号
    version=$(get_version "$version")
    print_info "准备发布版本: $version"

    # 构建
    if [ "$do_build" = true ]; then
        build_all "$build_method"
    else
        print_warning "跳过构建步骤"
        if [ ! -d "dist" ] || [ -z "$(ls -A dist/*.tar.gz dist/*.zip 2>/dev/null)" ]; then
            print_error "dist 目录中没有找到构建产物"
            print_info "请先运行 ./build.sh all 构建所有平台"
            exit 1
        fi
    fi

    # 创建 release
    create_release "$version" "$draft"
}

# 执行主函数
main "$@"