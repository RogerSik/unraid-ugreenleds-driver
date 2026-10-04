#!/bin/bash
# build the plugin package from this source dir (run on unRAID, needs makepkg)
PLUGIN_NAME="ugreenleds-driver"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="/tmp/${PLUGIN_NAME}_"$(echo $RANDOM)""
VERSION="${1:-$(date +'%Y.%m.%d')}"

mkdir -p $TMP_DIR/$VERSION
cd $TMP_DIR/$VERSION
cp -R $SRC_DIR/usr $TMP_DIR/$VERSION/
chmod -R 755 $TMP_DIR/$VERSION/
chmod 644 $TMP_DIR/$VERSION/usr/local/emhttp/plugins/$PLUGIN_NAME/*.page $TMP_DIR/$VERSION/usr/local/emhttp/plugins/$PLUGIN_NAME/*.cfg
makepkg -l y -c y $TMP_DIR/$PLUGIN_NAME-$VERSION.txz
md5sum $TMP_DIR/$PLUGIN_NAME-$VERSION.txz | awk '{print $1}' > $TMP_DIR/$PLUGIN_NAME-$VERSION.txz.md5
rm -R $TMP_DIR/$VERSION/
chmod -R 755 $TMP_DIR/*
echo "$TMP_DIR"
