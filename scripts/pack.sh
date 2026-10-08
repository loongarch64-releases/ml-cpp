#!/bin/bash

set -euo pipefail

SRC=${1}
DEPS_ZIP=${2}
NODEPS_ZIP=${3}

# ml-cpp 的构建产物目录。第三方库(boost、libxml2 等)由 3rd_party.cmake 在 configure
# 阶段拷贝到平台的 lib 目录，这里按文件名拆分，与官方 build.gradle 的划分保持一致：
#   nodeps = libMl* + bin + resources + licenses
#   deps   = 其余全部(即平台 lib 目录里的第三方库)
BUILD_OUT="${SRC}/build/distribution"
PLATFORM_DIR="${BUILD_OUT}/platform/linux-loongarch64"

init_framework()
{
    local BASE=${1}
    local PACK_DIR=${2}

    mkdir -p "${PACK_DIR}/bin"
    mkdir -p "${PACK_DIR}/lib"
    mkdir -p "${PACK_DIR}/resources"
    mkdir -p "${BASE}/platform/licenses"
}

pack_nodeps()
{
    local NODEPS_BASE="/tmp/nodeps"
    local NODEPS_PACK_DIR="${NODEPS_BASE}/platform/linux-loongarch64"
    init_framework "${NODEPS_BASE}" "${NODEPS_PACK_DIR}"

    cp -a "${BUILD_OUT}/platform/licenses/." "${NODEPS_BASE}/platform/licenses/"

    # es 内部共享库
    find "${PLATFORM_DIR}/lib" -maxdepth 1 -name "libMl*.so" -type f -exec cp -t "${NODEPS_PACK_DIR}/lib/" {} +

    # 可执行文件
    find "${PLATFORM_DIR}/bin" -maxdepth 1 -type f -exec cp -t "${NODEPS_PACK_DIR}/bin/" {} +

    # 资源文件
    if [ -d "${PLATFORM_DIR}/resources" ]; then
        find "${PLATFORM_DIR}/resources" -maxdepth 1 -type f -exec cp -t "${NODEPS_PACK_DIR}/resources/" {} +
    fi

    if [ -z "$(ls -A "${NODEPS_PACK_DIR}/lib")" ] || [ -z "$(ls -A "${NODEPS_PACK_DIR}/bin")" ]; then
        echo "❌ Error: ml-cpp libraries or programs not found in ${PLATFORM_DIR}" >&2
        exit 1
    fi

    pushd "${NODEPS_BASE}"
    zip -r -q "${NODEPS_ZIP}" platform/
    popd
}

pack_deps()
{
    local DEPS_BASE="/tmp/deps"
    local DEPS_PACK_DIR="${DEPS_BASE}/platform/linux-loongarch64"
    mkdir -p "${DEPS_PACK_DIR}/lib"

    # 三方库
    find "${PLATFORM_DIR}/lib" -maxdepth 1 -type f ! -name "libMl*" -exec cp -t "${DEPS_PACK_DIR}/lib/" {} +

    if [ -z "$(ls -A "${DEPS_PACK_DIR}/lib")" ]; then
        echo "❌ Error: third party libraries not found in ${PLATFORM_DIR}/lib" >&2
        exit 1
    fi

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
