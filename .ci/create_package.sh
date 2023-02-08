#!/usr/bin/env bash

set -ex

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$ROOT_DIR/build"

# create build dir
mkdir -p "$BUILD_DIR"

# change to root dir
cd "$ROOT_DIR"

# copy required files
cp -v -t "$BUILD_DIR" \
    docker-autoheal.service \
    docker-entrypoint \
    README.md \
    LICENSE

# copy installer
cp -v "$ROOT_DIR/install" "$BUILD_DIR/install.sh"

# convert the installer to local only
sed -i '7 i# this makes the installer local only for release packages\nLOCAL_INSTALL=\"true\"' "$BUILD_DIR/install.sh"

# create package
zip -j -o systemd-docker-autoheal.zip -r "$BUILD_DIR"
