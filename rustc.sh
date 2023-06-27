#!/usr/bin/env bash

set -e

pushd $(dirname "$0") >/dev/null
export GCC_PATH=$(cat gcc_path)
export LD_LIBRARY_PATH="$GCC_PATH"
export LIBRARY_PATH="$GCC_PATH"
export CHANNEL=release
source config.sh
popd >/dev/null

echo $RUSTC
$RUSTC --target $TARGET_JSON "$@"
