#!/bin/bash

# Cross-platform build script for solana-localhost
# This script builds the project for multiple platforms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project name
PROJECT_NAME="solana-localhost"

# Output directory
OUTPUT_DIR="./dist"

# Supported targets
TARGETS=(
    "x86_64-unknown-linux-gnu"
    "x86_64-unknown-linux-musl"
    "x86_64-pc-windows-gnu"
    "x86_64-apple-darwin"
    "aarch64-apple-darwin"
)

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if a target is installed
check_target() {
    local target=$1
    if rustup target list --installed | grep -q "$target"; then
        return 0
    else
        return 1
    fi
}

# Install target if not present
install_target() {
    local target=$1
    print_info "Installing target: $target"
    rustup target add "$target"
}

# Build for a specific target
build_target() {
    local target=$1
    print_info "Building for target: $target"

    if ! check_target "$target"; then
        print_warning "Target $target not installed"
        install_target "$target"
    fi

    cargo build --release --target "$target"

    if [ $? -eq 0 ]; then
        print_info "Successfully built for $target"

        # Create output directory if it doesn't exist
        mkdir -p "$OUTPUT_DIR"

        # Copy binary to output directory
        local binary_name="$PROJECT_NAME"
        local output_name="$PROJECT_NAME-${target}"

        if [[ $target == *"windows"* ]]; then
            binary_name="${PROJECT_NAME}.exe"
            output_name="${output_name}.exe"
        fi

        cp "target/$target/release/$binary_name" "$OUTPUT_DIR/$output_name"
        print_info "Binary copied to: $OUTPUT_DIR/$output_name"

        # Create archive
        cd "$OUTPUT_DIR"
        if [[ $target == *"windows"* ]]; then
            zip "${PROJECT_NAME}-${target}.zip" "$output_name"
            print_info "Created archive: ${PROJECT_NAME}-${target}.zip"
        else
            tar czf "${PROJECT_NAME}-${target}.tar.gz" "$output_name"
            print_info "Created archive: ${PROJECT_NAME}-${target}.tar.gz"
        fi
        cd - > /dev/null
    else
        print_error "Failed to build for $target"
        return 1
    fi
}

# Build for all targets
build_all() {
    print_info "Building for all supported targets..."

    for target in "${TARGETS[@]}"; do
        # Skip macOS targets if not on macOS
        if [[ $target == *"apple"* ]] && [[ "$OSTYPE" != "darwin"* ]]; then
            print_warning "Skipping $target (requires macOS)"
            continue
        fi

        # Skip Windows MSVC targets if not on Windows (use mingw instead)
        if [[ $target == *"pc-windows-msvc"* ]] && [[ "$OSTYPE" != "msys" ]]; then
            print_warning "Skipping $target (requires Windows with MSVC)"
            continue
        fi

        build_target "$target" || true
    done

    print_info "Build complete! Binaries are in: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"
}

# Clean build artifacts
clean() {
    print_info "Cleaning build artifacts..."
    cargo clean
    rm -rf "$OUTPUT_DIR"
    print_info "Clean complete!"
}

# Show usage
usage() {
    echo "Usage: $0 [command] [target]"
    echo ""
    echo "Commands:"
    echo "  all              Build for all supported targets"
    echo "  clean            Clean build artifacts"
    echo "  list             List available targets"
    echo "  <target>         Build for specific target"
    echo ""
    echo "Supported targets:"
    for target in "${TARGETS[@]}"; do
        echo "  - $target"
    done
    echo ""
    echo "Examples:"
    echo "  $0 all                           # Build for all targets"
    echo "  $0 x86_64-unknown-linux-gnu      # Build for Linux x86_64"
    echo "  $0 x86_64-pc-windows-gnu         # Build for Windows x86_64"
}

# Main
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    case "$1" in
        all)
            build_all
            ;;
        clean)
            clean
            ;;
        list)
            echo "Available targets:"
            for target in "${TARGETS[@]}"; do
                if check_target "$target"; then
                    echo -e "  ${GREEN}✓${NC} $target"
                else
                    echo -e "  ${RED}✗${NC} $target"
                fi
            done
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            # Check if the argument is a valid target
            if [[ " ${TARGETS[@]} " =~ " $1 " ]]; then
                build_target "$1"
            else
                print_error "Unknown target: $1"
                usage
                exit 1
            fi
            ;;
    esac
}

main "$@"
