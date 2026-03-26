#!/bin/bash
# build_dufs.sh - Compile dufs from source for a given platform
# Usage: bash scripts/build_dufs.sh <platform>
#   platform: android-arm64 | linux-x86_64 | linux-arm64 | windows-x86_64 | macos-arm64 | macos-x86_64 | ios-arm64
set -e

DUFS_VERSION="v0.45.0"
DUFS_REPO="https://github.com/sigoden/dufs.git"
PLATFORM=${1:?Usage: $0 <platform>}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/assets/dufs"

mkdir -p "$OUTPUT_DIR"

# Ensure Rust is available
if ! command -v cargo &> /dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
fi

# Clone dufs source
DUFS_SRC="/tmp/dufs-src-${DUFS_VERSION}"
if [ ! -d "$DUFS_SRC" ]; then
  git clone --depth 1 --branch "$DUFS_VERSION" "$DUFS_REPO" "$DUFS_SRC"
fi

cd "$DUFS_SRC"

case "$PLATFORM" in
  android-arm64)
    RUST_TARGET="aarch64-linux-android"
    OUTPUT_NAME="dufs-android-arm64"
    LIB_OUTPUT="${PROJECT_DIR}/android/app/src/main/jniLibs/arm64-v8a/libdufs.so"

    rustup target add "$RUST_TARGET"

    # Find NDK toolchain
    if [ -n "$ANDROID_NDK_HOME" ]; then
      NDK="$ANDROID_NDK_HOME"
    elif [ -n "$ANDROID_HOME" ]; then
      NDK=$(find "$ANDROID_HOME/ndk" -maxdepth 1 -type d | sort -V | tail -1)
    else
      echo "ERROR: ANDROID_NDK_HOME or ANDROID_HOME must be set"
      exit 1
    fi

    # Set up NDK linker
    TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt"
    case "$(uname -s)" in
      Linux*)  HOST_TAG="linux-x86_64" ;;
      Darwin*) HOST_TAG="darwin-x86_64" ;;
      *)       echo "Unsupported host"; exit 1 ;;
    esac
    LINKER="${TOOLCHAIN}/${HOST_TAG}/bin/aarch64-linux-android21-clang"

    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[target.aarch64-linux-android]
linker = "${LINKER}"
EOF

    export CC="${LINKER}"
    export AR="${TOOLCHAIN}/${HOST_TAG}/bin/llvm-ar"
    export RANLIB="${TOOLCHAIN}/${HOST_TAG}/bin/llvm-ranlib"

    cargo build --release --target "$RUST_TARGET"

    mkdir -p "$(dirname "$LIB_OUTPUT")"
    cp "target/${RUST_TARGET}/release/dufs" "$LIB_OUTPUT"
    echo "Built: $LIB_OUTPUT ($(du -h "$LIB_OUTPUT" | cut -f1))"
    ;;

  linux-x86_64)
    RUST_TARGET="x86_64-unknown-linux-gnu"
    OUTPUT_NAME="dufs-linux-x86_64"

    rustup target add "$RUST_TARGET"
    cargo build --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/dufs" "${OUTPUT_DIR}/${OUTPUT_NAME}"
    echo "Built: ${OUTPUT_DIR}/${OUTPUT_NAME} ($(du -h "${OUTPUT_DIR}/${OUTPUT_NAME}" | cut -f1))"
    ;;

  linux-arm64)
    RUST_TARGET="aarch64-unknown-linux-gnu"
    OUTPUT_NAME="dufs-linux-aarch64"

    rustup target add "$RUST_TARGET"
    sudo apt-get update && sudo apt-get install -y gcc-aarch64-linux-gnu

    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
EOF

    export CC="aarch64-linux-gnu-gcc"
    cargo build --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/dufs" "${OUTPUT_DIR}/${OUTPUT_NAME}"
    echo "Built: ${OUTPUT_DIR}/${OUTPUT_NAME} ($(du -h "${OUTPUT_DIR}/${OUTPUT_NAME}" | cut -f1))"
    ;;

  windows-x86_64)
    RUST_TARGET="x86_64-pc-windows-gnu"
    OUTPUT_NAME="dufs-windows.exe"

    rustup target add "$RUST_TARGET"
    sudo apt-get update && sudo apt-get install -y gcc-mingw-w64-x86-64

    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
EOF

    export CC="x86_64-w64-mingw32-gcc"
    cargo build --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/dufs.exe" "${OUTPUT_DIR}/${OUTPUT_NAME}"
    echo "Built: ${OUTPUT_DIR}/${OUTPUT_NAME} ($(du -h "${OUTPUT_DIR}/${OUTPUT_NAME}" | cut -f1))"
    ;;

  macos-arm64)
    RUST_TARGET="aarch64-apple-darwin"
    OUTPUT_NAME="dufs-macos-arm64"

    rustup target add "$RUST_TARGET"
    cargo build --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/dufs" "${OUTPUT_DIR}/${OUTPUT_NAME}"
    echo "Built: ${OUTPUT_DIR}/${OUTPUT_NAME} ($(du -h "${OUTPUT_DIR}/${OUTPUT_NAME}" | cut -f1))"
    ;;

  macos-x86_64)
    RUST_TARGET="x86_64-apple-darwin"
    OUTPUT_NAME="dufs-macos-x86_64"

    rustup target add "$RUST_TARGET"
    cargo build --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/dufs" "${OUTPUT_DIR}/${OUTPUT_NAME}"
    echo "Built: ${OUTPUT_DIR}/${OUTPUT_NAME} ($(du -h "${OUTPUT_DIR}/${OUTPUT_NAME}" | cut -f1))"
    ;;

  ios-arm64)
    RUST_TARGET="aarch64-apple-ios"
    FRAMEWORKS_DIR="${PROJECT_DIR}/ios/Frameworks"

    rustup target add "$RUST_TARGET"
    cargo build --release --target "$RUST_TARGET"

    mkdir -p "$FRAMEWORKS_DIR"
    cp "target/${RUST_TARGET}/release/dufs" "${FRAMEWORKS_DIR}/dufs"
    echo "Built: ${FRAMEWORKS_DIR}/dufs ($(du -h "${FRAMEWORKS_DIR}/dufs" | cut -f1))"
    ;;

  *)
    echo "Unknown platform: $PLATFORM"
    echo "Supported: android-arm64, linux-x86_64, linux-arm64, windows-x86_64, macos-arm64, macos-x86_64, ios-arm64"
    exit 1
    ;;
esac
