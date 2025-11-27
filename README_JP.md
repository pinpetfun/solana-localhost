# Solana Localhost プロキシ

[English](./README.md) | **日本語** | [中文](./README_CN.md)

ローカルポート 8899 をリモート Solana ノード（47.109.157.92:8899）に転送し、Phantom ウォレットをローカルノードに接続できるようにします。

## ダウンロード

最新リリースをダウンロード

お使いのシステムに合うバージョンを選択してください：
- **Windows**: `solana-localhost-windows-x64.zip`
- **macOS Intel**: `solana-localhost-macos-x64.tar.gz`
- **macOS M1/M2/M3**: `solana-localhost-macos-arm64.tar.gz`
- **Linux x64**: `solana-localhost-linux-x64.tar.gz`
- **Linux ARM64**: `solana-localhost-linux-arm64.tar.gz`

## 使用方法

### 1. ファイルの展開

**Windows:**
```bash
# zipファイルを展開（Windows内蔵の展開機能または任意の解凍ツールを使用）
# solana-localhost-windows-x64.zip を右クリックして「すべて展開」を選択
```

**macOS Intel:**
```bash
tar -xzf solana-localhost-macos-x64.tar.gz
```

**macOS Apple Silicon (M1/M2/M3):**
```bash
tar -xzf solana-localhost-macos-arm64.tar.gz
```

**Linux x64:**
```bash
tar -xzf solana-localhost-linux-x64.tar.gz
```

**Linux ARM64:**
```bash
tar -xzf solana-localhost-linux-arm64.tar.gz
```

### 2. 設定の変更（オプション）

`config.toml` ファイルを編集します。デフォルト設定は既に 47.109.157.92:8899 への転送に設定されています：

```toml
[proxy]
listen_addr = "127.0.0.1"   # ローカルリスニングアドレス
listen_port = 8899          # ローカルリスニングポート
target_addr = "47.109.157.92"  # ターゲット Solana ノードアドレス
target_port = 8899          # ターゲットポート

[logging]
level = "info"
```

### 3. アプリケーションの実行

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

### 4. Phantom ウォレットの設定

1. Phantom ウォレットを開く
2. 設定 → 開発者設定に移動
3. RPC ノードを `http://localhost:8899` に設定
4. Phantom ウォレットがローカルノードに接続されました

## 実行時の出力

プログラムが起動すると、以下が表示されます：
```
2025-11-26T10:00:00.000Z  INFO solana_localhost: Starting HTTP proxy server
2025-11-26T10:00:00.001Z  INFO solana_localhost: Listening on: 127.0.0.1:8899
2025-11-26T10:00:00.002Z  INFO solana_localhost: Forwarding to: http://47.109.157.92:8899
2025-11-26T10:00:00.003Z  INFO solana_localhost: Server started successfully
```

## ライセンス

MIT License