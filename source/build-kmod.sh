#!/bin/bash
# Build the led-ugreen kernel module package for one unRAID kernel.
# Usage: build-kmod.sh <unraid kernel src dir, e.g. .../src/linux-6.18.38-Unraid> <output dir>
# The src dir comes from unRAID's bzmodules (config, *.patch, drivers/).
set -euo pipefail

UNRAID_SRC="$(cd "$1" && pwd)"
OUT_DIR="$(mkdir -p "$2" && cd "$2" && pwd)"
WORK_DIR="${WORK_DIR:-$(mktemp -d)}"
DRIVER_REPO="${DRIVER_REPO:-https://github.com/miskcoo/ugreen_leds_controller}"
DRIVER_REF="${DRIVER_REF:-master}"
PACKAGE="ugreen_leds"

KREL="$(basename "$UNRAID_SRC" | sed 's/^linux-//')"
KVER="${KREL%%-*}"
echo "Building ${PACKAGE} for kernel ${KREL}"

# vanilla kernel + unRAID patches and config
cd "$WORK_DIR"
curl -sfL "https://cdn.kernel.org/pub/linux/kernel/v${KVER%%.*}.x/linux-${KVER}.tar.xz" | tar -xJ
cd "linux-${KVER}"
cp -r "$UNRAID_SRC/drivers/." drivers/
for p in "$UNRAID_SRC"/*.patch; do
  patch -p1 -s < "$p"
done
cp "$UNRAID_SRC/config" .config
make -s olddefconfig
make -s -j"$(nproc)" modules_prepare
if [ "$(make -s kernelrelease)" != "$KREL" ]; then
  echo "kernelrelease $(make -s kernelrelease) does not match ${KREL}" >&2
  exit 1
fi

# driver module
cd "$WORK_DIR"
git clone -q "$DRIVER_REPO" driver
git -C driver checkout -q "$DRIVER_REF"
DRIVER_VERSION="$(git -C driver log -1 --format=%cs | sed 's/-//g')"
# no Module.symvers without a full kernel build; fine as unRAID has CONFIG_MODVERSIONS off
make -s -C "$WORK_DIR/linux-${KVER}" M="$WORK_DIR/driver/kmod" KBUILD_MODPOST_WARN=1 modules
if ! modinfo -F vermagic "$WORK_DIR/driver/kmod/led-ugreen.ko" | grep -q "^${KREL} "; then
  echo "vermagic does not match ${KREL}" >&2
  exit 1
fi

# slackware package
PKG_DIR="$WORK_DIR/pkg"
mkdir -p "$PKG_DIR/lib/modules/${KREL}/extra" "$PKG_DIR/install"
cp "$WORK_DIR/driver/kmod/led-ugreen.ko" "$PKG_DIR/lib/modules/${KREL}/extra/"
xz --check=crc32 --lzma2 "$PKG_DIR/lib/modules/${KREL}/extra/led-ugreen.ko"
cat > "$PKG_DIR/install/slack-desc" <<EOF
       |-----handy-ruler------------------------------------------------------|
${PACKAGE}: ${PACKAGE} Package contents:
${PACKAGE}:
${PACKAGE}: Source: ${DRIVER_REPO}
${PACKAGE}:
${PACKAGE}:
${PACKAGE}: Custom ${PACKAGE} package for Unraid Kernel v${KVER}
${PACKAGE}:
EOF
find "$PKG_DIR" -type d -exec chmod 755 {} +
find "$PKG_DIR" -type f -exec chmod 644 {} +
PKG_NAME="${PACKAGE}-${DRIVER_VERSION}-${KREL}-1.txz"
tar --owner=0 --group=0 --sort=name --xform='sx^\./\(.\)x\1x' -C "$PKG_DIR" -cJf "$OUT_DIR/$PKG_NAME" .
(cd "$OUT_DIR" && md5sum "$PKG_NAME" | awk '{print $1}' > "$PKG_NAME.md5")
echo "$OUT_DIR/$PKG_NAME"
