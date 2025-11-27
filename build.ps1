# Cross-platform build script for solana-localhost (PowerShell)
# This script builds the project for multiple platforms on Windows

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    [Parameter(Position=1)]
    [string]$Target = ""
)

$ErrorActionPreference = "Stop"

# Project name
$PROJECT_NAME = "solana-localhost"

# Output directory
$OUTPUT_DIR = "./dist"

# Supported targets
$TARGETS = @(
    "x86_64-unknown-linux-gnu",
    "x86_64-unknown-linux-musl",
    "x86_64-pc-windows-msvc",
    "x86_64-pc-windows-gnu",
    "x86_64-apple-darwin",
    "aarch64-apple-darwin"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Check if a target is installed
function Test-Target {
    param([string]$TargetName)
    $installed = rustup target list --installed
    return $installed -match $TargetName
}

# Install target if not present
function Install-Target {
    param([string]$TargetName)
    Write-Info "Installing target: $TargetName"
    rustup target add $TargetName
}

# Build for a specific target
function Build-Target {
    param([string]$TargetName)
    Write-Info "Building for target: $TargetName"

    if (-not (Test-Target $TargetName)) {
        Write-Warning "Target $TargetName not installed"
        Install-Target $TargetName
    }

    cargo build --release --target $TargetName

    if ($LASTEXITCODE -eq 0) {
        Write-Info "Successfully built for $TargetName"

        # Create output directory if it doesn't exist
        New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null

        # Copy binary to output directory
        $binaryName = $PROJECT_NAME
        $outputName = "$PROJECT_NAME-$TargetName"

        if ($TargetName -like "*windows*") {
            $binaryName = "$PROJECT_NAME.exe"
            $outputName = "$outputName.exe"
        }

        $sourcePath = "target/$TargetName/release/$binaryName"
        $destPath = "$OUTPUT_DIR/$outputName"

        Copy-Item $sourcePath $destPath -Force
        Write-Info "Binary copied to: $destPath"

        # Create archive
        Push-Location $OUTPUT_DIR
        if ($TargetName -like "*windows*") {
            $archiveName = "$PROJECT_NAME-$TargetName.zip"
            Compress-Archive -Path $outputName -DestinationPath $archiveName -Force
            Write-Info "Created archive: $archiveName"
        } else {
            # For non-Windows targets, try to create tar.gz if tar is available
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                $archiveName = "$PROJECT_NAME-$TargetName.tar.gz"
                tar -czf $archiveName $outputName
                Write-Info "Created archive: $archiveName"
            } else {
                Write-Warning "tar command not found, skipping archive creation for $TargetName"
            }
        }
        Pop-Location
    } else {
        Write-ErrorMessage "Failed to build for $TargetName"
        return $false
    }
    return $true
}

# Build for all targets
function Build-All {
    Write-Info "Building for all supported targets..."

    foreach ($target in $TARGETS) {
        # Skip non-Windows targets if cross-compilation is not set up
        if (($target -like "*linux*" -or $target -like "*apple*") -and -not $env:CROSS_COMPILE) {
            Write-Warning "Skipping $target (cross-compilation not configured)"
            Write-Info "To enable cross-compilation, install cross: cargo install cross"
            continue
        }

        Build-Target $target | Out-Null
    }

    Write-Info "Build complete! Binaries are in: $OUTPUT_DIR"
    Get-ChildItem $OUTPUT_DIR
}

# Clean build artifacts
function Clean-Build {
    Write-Info "Cleaning build artifacts..."
    cargo clean
    if (Test-Path $OUTPUT_DIR) {
        Remove-Item -Recurse -Force $OUTPUT_DIR
    }
    Write-Info "Clean complete!"
}

# List available targets
function List-Targets {
    Write-Host "Available targets:"
    foreach ($target in $TARGETS) {
        if (Test-Target $target) {
            Write-Host "  ✓ $target" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $target" -ForegroundColor Red
        }
    }
}

# Show usage
function Show-Usage {
    Write-Host "Usage: .\build.ps1 [command] [target]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  all              Build for all supported targets"
    Write-Host "  clean            Clean build artifacts"
    Write-Host "  list             List available targets"
    Write-Host "  <target>         Build for specific target"
    Write-Host ""
    Write-Host "Supported targets:"
    foreach ($target in $TARGETS) {
        Write-Host "  - $target"
    }
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\build.ps1 all                           # Build for all targets"
    Write-Host "  .\build.ps1 x86_64-pc-windows-msvc        # Build for Windows x86_64 MSVC"
    Write-Host "  .\build.ps1 x86_64-unknown-linux-gnu      # Build for Linux x86_64"
}

# Main
switch ($Command.ToLower()) {
    "all" {
        Build-All
    }
    "clean" {
        Clean-Build
    }
    "list" {
        List-Targets
    }
    "help" {
        Show-Usage
    }
    "-h" {
        Show-Usage
    }
    "--help" {
        Show-Usage
    }
    default {
        if ($TARGETS -contains $Command) {
            Build-Target $Command
        } else {
            Write-ErrorMessage "Unknown command or target: $Command"
            Show-Usage
            exit 1
        }
    }
}
