#!/bin/bash

set -euo pipefail

SRC="$1"

set_env()
{
    local ORI_BIN=/usr/bin
    local NEW_BIN=/usr/local/gcc133/bin
    local ORI_LIB=/usr/lib/loongarch64-linux-gnu
    local NEW_LIB=/usr/local/gcc133/lib
    
    mkdir -p $NEW_BIN
    ln -sf $ORI_BIN/gcc $NEW_BIN/gcc
    ln -sf $ORI_BIN/g++ $NEW_BIN/g++
    ln -sf $ORI_BIN/ar $NEW_BIN/ar
    ln -sf $ORI_BIN/ranlib $NEW_BIN/ranlib
    ln -sf $ORI_BIN/strip $NEW_BIN/strip
    ln -sf $ORI_BIN/ld $NEW_BIN/ld

    mkdir -p $NEW_LIB
    ln -sf $ORI_LIB/libxml2.so $NEW_LIB/libxml2.so
}

add_file()
{
    CMAKE_1="${SRC}/cmake/linux-loongarch64.cmake"
    CMAKE_2="${SRC}/cmake/architecture/loongarch64.cmake"

    cp "${SRC}/cmake/linux-x86_64.cmake" "${CMAKE_1}"
    sed -i "s/x86_64/loongarch64/" "${CMAKE_1}"

    cat << 'EOF' > ${CMAKE_2}
message(STATUS "loongarch64 detected for target")
set(ARCHCFLAGS "-march=loongarch64" "-mabi=lp64d" "-ffp-contract=on")
EOF
}

patch_code()
{
    # 禁用 pytorch（待适配）
    sed -i "s/add_subdirectory(pytorch_inference)/#&/" "${SRC}/bin/CMakeLists.txt"
    # 沙箱
    sed -i "s/defined(__aarch64__)/& || defined(__loongarch64)/" "${SRC}/lib/seccomp/CSystemCallFilter_Linux.cc"
    # 异常现场还原
    sed -i '/defined(REG_EIP)/i\
#elif defined(__loongarch64) \
    errorAddress = reinterpret_cast<void*>(uContext->uc_mcontext.__pc);' "${SRC}/lib/core/CCrashHandler_Linux.cc"
}

patch()
{
    echo "patching ..."
    set_env
    add_file
    patch_code
    echo "done"
}

patch
