#!/bin/bash

set -euo pipefail

SRC=${1}
DEPS_ZIP=${2}
NODEPS_ZIP=${3}
BUILD_OUT="${SRC}/build/distribution"

pack_nodeps()
{
    pushd "${BUILD_OUT}"
    zip -r -q "${NODEPS_ZIP}" platform/
    popd
}

pack_deps()
{
    local DEPS_BASE="/tmp/deps"
    local DEPS_PACK_DIR="${DEPS_BASE}/platform/linux-loongarch64"

    mkdir -p "${DEPS_PACK_DIR}/bin"
    mkdir -p "${DEPS_PACK_DIR}/lib"
    mkdir -p "${DEPS_PACK_DIR}/resources"
    mkdir -p "${DEPS_BASE}/platform/licenses"

    # 三方库
    find "/usr/local/lib" -name "libboost*.so.1.86.0" -type f -exec cp -L -t "$DEPS_PACK_DIR/lib/" {} +
    find "/usr/lib/loongarch64-linux-gnu" -name "libxml2*so*" -type f -exec cp -L -t  "$DEPS_PACK_DIR/lib" {} +

    pushd "${DEPS_BASE}"
    zip -r -q "${DEPS_ZIP}" platform/
    popd
}

pack()
{
    pack_nodeps
    pack_deps
}

pack
