#!/bin/bash
# build_dufs.sh - Compile dufs from source for a given platform
# Usage: bash scripts/build_dufs.sh <platform>
#   platform: android-arm64 | linux-x86_64 | linux-arm64 | windows-x86_64 | macos-arm64 | macos-x86_64 | ios-arm64
#
# Builds dufs as a cdylib (shared library) for FFI embedding in Flutter.
# The output is a .so / .dll / .dylib that exposes dufs_start / dufs_stop / dufs_is_running.
set -e

DUFS_VERSION="v0.45.0"
DUFS_REPO="https://github.com/zocs/dufs.git"
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

# Apply inout's FFI modifications (lib.rs + Cargo.toml [lib] section)
DUFS_FFI_DIR="${SCRIPT_DIR}/dufs-ffi"
if [ -d "$DUFS_FFI_DIR" ]; then
  echo "Applying FFI modifications..."
  cp "${DUFS_FFI_DIR}/lib.rs" "${DUFS_SRC}/src/lib.rs"
  # Ensure Cargo.toml has [lib] section
  if ! grep -q '^\[lib\]' "${DUFS_SRC}/Cargo.toml"; then
    sed -i '1i\[lib]\nname = "dufs"\ncrate-type = ["cdylib", "rlib"]\n' "${DUFS_SRC}/Cargo.toml"
  fi
fi

cd "$DUFS_SRC"

case "$PLATFORM" in
  android-arm64)
    RUST_TARGET="aarch64-linux-android"

    command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"

    if [ -n "$ANDROID_NDK_HOME" ]; then
      NDK="$ANDROID_NDK_HOME"
    elif [ -n "$ANDROID_HOME" ]; then
      NDK=$(find "$ANDROID_HOME/ndk" -maxdepth 1 -type d | sort -V | tail -1)
    else
      echo "ERROR: ANDROID_NDK_HOME or ANDROID_NDK_HOME must be set"
      exit 1
    fi

    TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt"
    case "$(uname -s)" in
      Linux*)  HOST_TAG="linux-x86_64" ;;
      Darwin*) HOST_TAG="darwin-x86_64" ;;
      *)       echo "Unsupported host"; exit 1 ;;
    esac
    LINKER="${TOOLCHAIN}/${HOST_TAG}/bin/aarch64-linux-android24-clang"

    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[target.aarch64-linux-android]
linker = "${LINKER}"
EOF

    export CC="${LINKER}"
    export AR="${TOOLCHAIN}/${HOST_TAG}/bin/llvm-ar"
    export RANLIB="${TOOLCHAIN}/${HOST_TAG}/bin/llvm-ranlib"

    cargo build --lib --release --target "$RUST_TARGET"

    LIB_OUTPUT="${PROJECT_DIR}/android/app/src/main/jniLibs/arm64-v8a/libdufs.so"
    mkdir -p "$(dirname "$LIB_OUTPUT")"
    cp "target/${RUST_TARGET}/release/libdufs.so" "$LIB_OUTPUT"
    echo "Built: $LIB_OUTPUT ($(du -h "$LIB_OUTPUT" | cut -f1))"
    ;;

  linux-x86_64)
    RUST_TARGET="x86_64-unknown-linux-gnu"

    command -v rustup &>/dev/null && rustup target add "$RUST_TARGET"
    cargo build --lib --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/libdufs.so" "${OUTPUT_DIR}/libdufs-linux-x86_64.so"
    echo "Built: ${OUTPUT_DIR}/libdufs-linux-x86_64.so ($(du -h "${OUTPUT_DIR}/libdufs-linux-x86_64.so" | cut -f1))"
    ;;

  linux-arm64)
    RUST_TARGET="aarch64-unknown-linux-gnu"

    command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"
    sudo apt-get update && sudo apt-get install -y gcc-aarch64-linux-gnu

    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
EOF

    export CC="aarch64-linux-gnu-gcc"
    cargo build --lib --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/libdufs.so" "${OUTPUT_DIR}/libdufs-linux-aarch64.so"
    echo "Built: ${OUTPUT_DIR}/libdufs-linux-aarch64.so ($(du -h "${OUTPUT_DIR}/libdufs-linux-aarch64.so" | cut -f1))"
    ;;

  windows-x86_64)
    RUST_TARGET="x86_64-pc-windows-gnu"

    command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"
    sudo apt-get update && sudo apt-get install -y gcc-mingw-w64-x86-64

    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
EOF

    export CC="x86_64-w64-mingw32-gcc"
    cargo build --lib --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/dufs.dll" "${OUTPUT_DIR}/dufs-windows-x86_64.dll"
    echo "Built: ${OUTPUT_DIR}/dufs-windows-x86_64.dll ($(du -h "${OUTPUT_DIR}/dufs-windows-x86_64.dll" | cut -f1))"
    ;;

  macos-arm64)
    RUST_TARGET="aarch64-apple-darwin"

    command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"
    cargo build --lib --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/libdufs.dylib" "${OUTPUT_DIR}/libdufs-macos-arm64.dylib"
    echo "Built: ${OUTPUT_DIR}/libdufs-macos-arm64.dylib ($(du -h "${OUTPUT_DIR}/libdufs-macos-arm64.dylib" | cut -f1))"
    ;;

  macos-x86_64)
    RUST_TARGET="x86_64-apple-darwin"

    command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"
    cargo build --lib --release --target "$RUST_TARGET"

    cp "target/${RUST_TARGET}/release/libdufs.dylib" "${OUTPUT_DIR}/libdufs-macos-x86_64.dylib"
    echo "Built: ${OUTPUT_DIR}/libdufs-macos-x86_64.dylib ($(du -h "${OUTPUT_DIR}/libdufs-macos-x86_64.dylib" | cut -f1))"
    ;;

  ios-arm64)
    RUST_TARGET="aarch64-apple-ios"
    FRAMEWORKS_DIR="${PROJECT_DIR}/ios/Frameworks"

    command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"
    cargo build --lib --release --target "$RUST_TARGET"

    mkdir -p "$FRAMEWORKS_DIR"
    cp "target/${RUST_TARGET}/release/libdufs.a" "${FRAMEWORKS_DIR}/libdufs.a"
    echo "Built: ${FRAMEWORKS_DIR}/libdufs.a ($(du -h "${FRAMEWORKS_DIR}/libdufs.a" | cut -f1))"
    ;;

  *)
    echo "Unknown platform: $PLATFORM"
    echo "Supported: android-arm64, linux-x86_64, linux-arm64, windows-x86_64, macos-arm64, macos-x86_64, ios-arm64"
    exit 1
    ;;
esac
