#!/bin/bash
# build_linux.sh - Build and package inout for Linux
set -e

ARCH=${1:-x86_64}
VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | tr -d '+')
APP_NAME="inout"

# Architecture mapping
DEB_ARCH=$([ "$ARCH" = "aarch64" ] && echo "arm64" || echo "amd64")
ARCHIVE_NAME="${APP_NAME}-${VERSION}-linux-${ARCH}"

echo "Building inout ${VERSION} for Linux ${ARCH}..."

# Download dufs binary
DUFS_ARCH=$([ "$ARCH" = "aarch64" ] && echo "aarch64-unknown-linux-musl" || echo "x86_64-unknown-linux-musl")
DUFS_URL="https://github.com/sigoden/dufs/releases/download/v0.45.0/dufs-v0.45.0-${DUFS_ARCH}.tar.gz"
echo "Downloading dufs for ${DUFS_ARCH}..."
curl -sL "$DUFS_URL" | tar xz -C /tmp/
mkdir -p assets/dufs
cp /tmp/dufs "assets/dufs/dufs-linux-${ARCH}"
chmod +x "assets/dufs/dufs-linux-${ARCH}"

# Build Flutter Linux
flutter build linux --release

# Flutter outputs to build/linux/{x64|arm64}/release/bundle
FLUTTER_ARCH=$([ "$ARCH" = "aarch64" ] && echo "arm64" || echo "x64")
BUILD_DIR="build/linux/${FLUTTER_ARCH}/release/bundle"
OUTPUT_DIR="build/linux/output"
mkdir -p "$OUTPUT_DIR"

# Copy build output for packaging
PKG_DIR="${OUTPUT_DIR}/${APP_NAME}"
cp -r "$BUILD_DIR" "$PKG_DIR"

# Include dufs binary in the bundle
cp "assets/dufs/dufs-linux-${ARCH}" "${PKG_DIR}/dufs"
chmod +x "${PKG_DIR}/dufs"

# ==================== AppImage ====================
echo "Creating AppImage..."
APPDIR="${OUTPUT_DIR}/${APP_NAME}.AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/share/applications" "${APPDIR}/usr/share/icons/hicolor/256x256/apps"

# Copy app files
cp -r "${PKG_DIR}/"* "${APPDIR}/usr/bin/"

# Create desktop entry
cat > "${APPDIR}/${APP_NAME}.desktop" << 'DESKTOP'
[Desktop Entry]
Name=inout
Comment=Files in and out, that's all.
Exec=inout_flutter
Icon=inout
Type=Application
Categories=Utility;FileTransfer;
Terminal=false
DESKTOP

cp "${APPDIR}/${APP_NAME}.desktop" "${APPDIR}/usr/share/applications/${APP_NAME}.desktop"

# Copy icon
if [ -f "assets/icon/app_icon.png" ]; then
  cp "assets/icon/app_icon.png" "${APPDIR}/inout.png"
  cp "assets/icon/app_icon.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png"
fi

# AppRun
cat > "${APPDIR}/AppRun" << 'APPRUN'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE="${SELF%/*}"
export LD_LIBRARY_PATH="${HERE}/usr/bin/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/inout_flutter" "$@"
APPRUN
chmod +x "${APPDIR}/AppRun"

# Download appimagetool (architecture-specific)
APPIMAGE_ARCH=$([ "$ARCH" = "aarch64" ] && echo "aarch64" || echo "x86_64")
if [ ! -f /tmp/appimagetool ]; then
  curl -sL "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage" -o /tmp/appimagetool
  chmod +x /tmp/appimagetool
fi

export ARCH=${APPIMAGE_ARCH}
/tmp/appimagetool --comp gzip "${APPDIR}" "${OUTPUT_DIR}/${ARCHIVE_NAME}.AppImage"
echo "Created: ${OUTPUT_DIR}/${ARCHIVE_NAME}.AppImage"

# ==================== .deb ====================
echo "Creating .deb package..."
DEB_DIR="${OUTPUT_DIR}/${APP_NAME}-deb"
rm -rf "${DEB_DIR}"
mkdir -p "${DEB_DIR}/DEBIAN" "${DEB_DIR}/opt/${APP_NAME}" "${DEB_DIR}/usr/share/applications" "${DEB_DIR}/usr/bin"

# Control file
cat > "${DEB_DIR}/DEBIAN/control" << CONTROL
Package: ${APP_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${DEB_ARCH}
Depends: libgtk-3-0, libglib2.0-0
Maintainer: zocs <zocs@live.com>
Description: Files in and out, that's all.
 A graphical file sharing server based on dufs.
CONTROL

# Copy files
cp -r "${PKG_DIR}/"* "${DEB_DIR}/opt/${APP_NAME}/"

# Symlink to /usr/bin
cat > "${DEB_DIR}/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
ln -sf /opt/inout/inout_flutter /usr/bin/inout
chmod +x /opt/inout/inout_flutter
POSTINST
chmod 755 "${DEB_DIR}/DEBIAN/postinst"

cat > "${DEB_DIR}/DEBIAN/prerm" << 'PRERM'
#!/bin/bash
rm -f /usr/bin/inout
PRERM
chmod 755 "${DEB_DIR}/DEBIAN/prerm"

# Desktop entry
cat > "${DEB_DIR}/usr/share/applications/${APP_NAME}.desktop" << 'DESKTOP'
[Desktop Entry]
Name=inout
Comment=Files in and out, that's all.
Exec=/opt/inout/inout_flutter
Icon=utilities-terminal
Type=Application
Categories=Utility;FileTransfer;
Terminal=false
DESKTOP

dpkg-deb --build "${DEB_DIR}" "${OUTPUT_DIR}/${ARCHIVE_NAME}.deb"
echo "Created: ${OUTPUT_DIR}/${ARCHIVE_NAME}.deb"

# ==================== .rpm ====================
echo "Creating .rpm package..."
if command -v rpmbuild &> /dev/null; then
  RPM_DIR="${OUTPUT_DIR}/rpm-build"
  mkdir -p "${RPM_DIR}/BUILD" "${RPM_DIR}/RPMS" "${RPM_DIR}/SOURCES" "${RPM_DIR}/SPECS" "${RPM_DIR}/SRPMS"
  cp -r "${PKG_DIR}" "${RPM_DIR}/BUILD/${APP_NAME}"

  cat > "${RPM_DIR}/SPECS/${APP_NAME}.spec" << SPEC
Name: ${APP_NAME}
Version: ${VERSION}
Release: 1
Summary: Files in and out, that's all.
License: MIT
Requires: gtk3 glib2

%description
A graphical file sharing server based on dufs.

%install
mkdir -p %{buildroot}/opt/${APP_NAME}
cp -r ${APP_NAME}/* %{buildroot}/opt/${APP_NAME}/
mkdir -p %{buildroot}/usr/bin
ln -sf /opt/${APP_NAME}/inout_flutter %{buildroot}/usr/bin/inout

%files
/opt/${APP_NAME}/*
/usr/bin/inout
SPEC

  rpmbuild -bb --define "_topdir ${RPM_DIR}" --define "_builddir ${RPM_DIR}/BUILD" "${RPM_DIR}/SPECS/${APP_NAME}.spec" 2>&1 || echo "RPM build failed, continuing..."
  # Copy RPM if created
  RPM_FILE=$(find "${RPM_DIR}/RPMS" -name "*.rpm" 2>/dev/null | head -1)
  if [ -n "$RPM_FILE" ]; then
    cp "$RPM_FILE" "${OUTPUT_DIR}/${ARCHIVE_NAME}.rpm"
    echo "Created: ${OUTPUT_DIR}/${ARCHIVE_NAME}.rpm"
  else
    echo "RPM not created, skipping"
  fi
else
  echo "rpmbuild not found, skipping .rpm"
fi

# ==================== .tar.gz (for Arch/AUR) ====================
echo "Creating .tar.gz..."
tar -czf "${OUTPUT_DIR}/${ARCHIVE_NAME}.tar.gz" -C "${OUTPUT_DIR}" "${APP_NAME}"
echo "Created: ${OUTPUT_DIR}/${ARCHIVE_NAME}.tar.gz"

echo ""
echo "Build complete! Output files:"
ls -la "${OUTPUT_DIR}/"*.AppImage "${OUTPUT_DIR}/"*.deb "${OUTPUT_DIR}/"*.tar.gz 2>/dev/null || true
ls -la "${OUTPUT_DIR}/"*.rpm 2>/dev/null || true
