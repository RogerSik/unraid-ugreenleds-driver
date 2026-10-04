#!/bin/bash
# Build the plugin package and render the plg for one version.
# Usage: build-plugin.sh <version, e.g. 2026.10.04> <output dir>
set -euo pipefail

PLUGIN_NAME="ugreenleds-driver"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$1"
OUT_DIR="$(mkdir -p "$2" && cd "$2" && pwd)"
PKG_DIR="$(mktemp -d)"

# slackware package, same layout and permissions as makepkg -l y -c y
cp -R "$REPO_DIR/source/usr" "$PKG_DIR/"
chmod -R 755 "$PKG_DIR"
chmod 644 "$PKG_DIR/usr/local/emhttp/plugins/$PLUGIN_NAME/"*.page "$PKG_DIR/usr/local/emhttp/plugins/$PLUGIN_NAME/"*.cfg
tar --owner=0 --group=0 --sort=name --xform='sx^\./\(.\)x\1x' -C "$PKG_DIR" -cJf "$OUT_DIR/$PLUGIN_NAME-$VERSION.txz" .
rm -rf "$PKG_DIR"
MD5="$(md5sum "$OUT_DIR/$PLUGIN_NAME-$VERSION.txz" | awk '{print $1}')"
echo "$MD5" > "$OUT_DIR/$PLUGIN_NAME-$VERSION.txz.md5"

# plg with version and md5 filled in
sed -e "s/@VERSION@/$VERSION/" -e "s/@MD5@/$MD5/" "$REPO_DIR/$PLUGIN_NAME.plg" > "$OUT_DIR/$PLUGIN_NAME.plg"

# assets the plg downloads from the release
cp "$REPO_DIR/packages/i2c-tools-"*"-x86_64-1.txz" "$OUT_DIR/"
cp "$REPO_DIR/images/$PLUGIN_NAME.png" "$OUT_DIR/"

# release notes: CHANGES entry of this version
awk -v v="###$VERSION" '$0==v{f=1;next} /^###/{f=0} f' "$REPO_DIR/$PLUGIN_NAME.plg" | sed '/^$/d' > "$OUT_DIR/notes.md"
ls -l "$OUT_DIR"
