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
    # cmake/variables.cmake 用 ${ML_BASE_PATH}/lib/libxml2.so 链接 libxml2，
    # 而 3rd_party.cmake 是按 *.so.2 把 libxml2 拷贝进产物的，两个名字都需要
    ln -sf $ORI_LIB/libxml2.so $NEW_LIB/libxml2.so
    ln -sf "$(readlink -f $ORI_LIB/libxml2.so)" $NEW_LIB/libxml2.so.2
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

patch_3rd_party()
{
    local CMAKE_3RD="${SRC}/3rd_party/3rd_party.cmake"

    # loongarch64 上 b2 --layout=versioned 生成的 Boost 库名里架构标签是 l64
    # (x86 是 x64、arm64 是 a64)，3rd_party.cmake 只区分了 aarch64 与 x64，
    # 不补这个分支就匹配不到任何 Boost 库("Boost not found"，configure 阶段非致命，
    # 但后果是第三方库不会被拷贝进产物)
    if ! grep -q 'set(BOOST_ARCH "l64")' "${CMAKE_3RD}"; then
        sed -i 's|if( "${ARCH}" STREQUAL "aarch64" )|if( "${ARCH}" STREQUAL "loongarch64" )\n      set(BOOST_ARCH "l64")\n    elseif( "${ARCH}" STREQUAL "aarch64" )|' "${CMAKE_3RD}"
    fi
    grep -q 'set(BOOST_ARCH "l64")' "${CMAKE_3RD}"
}

patch()
{
    echo "patching ..."
    set_env
    add_file
    patch_code
    patch_3rd_party
    echo "done"
}

patch
