#!/bin/bash
# build_dufs.sh - Compile dufs from source for a given platform
# Usage: bash scripts/build_dufs.sh <platform>
#   platform: android-arm64 | linux-x86_64 | linux-arm64 | windows-x86_64 | macos-arm64 | macos-x86_64 | ios-arm64
#
# Builds dufs as a cdylib (shared library) for FFI embedding in Flutter.
# The output is a .so / .dll / .dylib that exposes dufs_start / dufs_stop / dufs_is_running.
set -e

DUFS_VERSION="v0.45.0-fix1"
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
  # Ensure Cargo.toml has [lib] section (BSD/GNU sed compatible)
  if ! grep -q '^\[lib\]' "${DUFS_SRC}/Cargo.toml"; then
    TMPFILE="${DUFS_SRC}/Cargo.toml.tmp"
    printf '%s\n\n%s\n' '[lib]
name = "dufs"
crate-type = ["cdylib", "rlib"]' "$(cat "${DUFS_SRC}/Cargo.toml")" > "$TMPFILE"
    mv "$TMPFILE" "${DUFS_SRC}/Cargo.toml"
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
    # IMPORTANT: link against a low API level (matches AndroidManifest minSdk=24).
    # If we let `sort -V | tail -1` pick the highest clang wrapper (e.g. API 35 in
    # NDK r27), lld emits DT_RELR packed relocations — the Android dynamic linker
    # only understands those from API 30+. On older devices (tested API 26) the
    # linker logs "unused DT entry: type 0x6fffe000/01/03" then the binary
    # segfaults at SEGV_MAPERR on its first PLT call. Pinning to API 24 keeps lld
    # on the legacy relocation format that works everywhere from minSdk up.
    ANDROID_API="${ANDROID_API:-24}"
    LINKER="${TOOLCHAIN}/${HOST_TAG}/bin/aarch64-linux-android${ANDROID_API}-clang"
    if [ ! -x "$LINKER" ]; then
      echo "ERROR: Missing ${LINKER}. Available aarch64 clang wrappers:"
      ls "${TOOLCHAIN}/${HOST_TAG}/bin/" 2>/dev/null | grep 'aarch64-linux-android.*-clang$' | head -20
      exit 1
    fi

    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[target.aarch64-linux-android]
linker = "${LINKER}"
# Belt-and-suspenders: forbid DT_RELR packed relocations even if a future lld
# default changes. --pack-dyn-relocs=none ≥ API 23 compatible unconditionally.
rustflags = ["-C", "link-arg=-Wl,--pack-dyn-relocs=none"]
EOF

    export CC="${LINKER}"
    export AR="${TOOLCHAIN}/${HOST_TAG}/bin/llvm-ar"
    export RANLIB="${TOOLCHAIN}/${HOST_TAG}/bin/llvm-ranlib"

    cargo build --release --target "$RUST_TARGET"

    LIB_OUTPUT="${PROJECT_DIR}/android/app/src/main/jniLibs/arm64-v8a/libdufs.so"
    mkdir -p "$(dirname "$LIB_OUTPUT")"
    cp "target/${RUST_TARGET}/release/dufs" "$LIB_OUTPUT"
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
    mkdir -p .cargo
    if [ "$(uname -s | cut -c1-6)" = "MINGW" ] || [ "$(uname -s | cut -c1-5)" = "MSYS" ]; then
      # Native Windows build (CI runs on windows-latest)
      RUST_TARGET="x86_64-pc-windows-msvc"
      cargo build --lib --release --target "$RUST_TARGET"
      cp "target/${RUST_TARGET}/release/dufs.dll" "${OUTPUT_DIR}/dufs-windows-x86_64.dll"
    else
      # Cross-compile from Linux
      RUST_TARGET="x86_64-pc-windows-gnu"
      command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"
      sudo apt-get update && sudo apt-get install -y gcc-mingw-w64-x86-64
      cat > .cargo/config.toml <<XEOF
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
XEOF
      export CC="x86_64-w64-mingw32-gcc"
      cargo build --lib --release --target "$RUST_TARGET"
      cp "target/${RUST_TARGET}/release/dufs.dll" "${OUTPUT_DIR}/dufs-windows-x86_64.dll"
    fi
    echo "Built: ${OUTPUT_DIR}/dufs-windows-x86_64.dll"
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
    # iOS doesn't support cdylib — build as binary (subprocess approach)
    RUST_TARGET="aarch64-apple-ios"
    FRAMEWORKS_DIR="${PROJECT_DIR}/ios/Frameworks"

    command -v rustup >/dev/null 2>&1 && rustup target add "$RUST_TARGET"
    cargo build --release --target "$RUST_TARGET"

    mkdir -p "$FRAMEWORKS_DIR"
    cp "target/${RUST_TARGET}/release/dufs" "${FRAMEWORKS_DIR}/dufs"
    echo "Built: ${FRAMEWORKS_DIR}/dufs"
    ;;

  *)
    echo "Unknown platform: $PLATFORM"
    echo "Supported: android-arm64, linux-x86_64, linux-arm64, windows-x86_64, macos-arm64, macos-x86_64, ios-arm64"
    exit 1
    ;;
esac
