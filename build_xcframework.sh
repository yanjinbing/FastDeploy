#!/bin/bash
set -e

# ===================== 配置 =====================
ROOT_DIR=$(pwd)
BUILD_DIR=${ROOT_DIR}/build_ios
INSTALL_DIR=${ROOT_DIR}/install
LIB_NAME=fastdeploy
XCFRAMEWORK_NAME=${LIB_NAME}.xcframework
OPENCVDIR=/usr/local/opencv-4.10.0-static/lib/cmake/opencv4

# 清理旧文件
rm -rf ${BUILD_DIR} ${INSTALL_DIR} ${XCFRAMEWORK_NAME}

# 检查架构
if [ "$(uname -m)" != "arm64" ]; then
    echo "❌ 错误：此脚本仅支持在 Apple Silicon (arm64) Mac 上运行"
    exit 1
fi

# 公共 CMake 参数
COMMON_CMAKE_ARGS=(
  -DCMAKE_BUILD_TYPE=MinSizeRel
  -DENABLE_ORT_BACKEND=ON
  -DENABLE_VISION=ON
  -DENABLE_TEXT=OFF
  -DENABLE_PADDLE2ONNX=OFF
  -DCMAKE_CXX_STANDARD=17
  -DOPENCV_DIRECTORY=${OPENCVDIR}
  -DWITH_OPENCV_STATIC=ON
  -DWITH_STATIC_LIB=ON
)

# ===================== 构建 iOS 真机 (arm64) =====================
echo "📦 构建 iOS 真机 (arm64)..."
IOS_ARM64=${BUILD_DIR}/ios/arm64
cmake -S . -B ${IOS_ARM64} \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_CXX_FLAGS="-fembed-bitcode -O3" \
  "${COMMON_CMAKE_ARGS[@]}"

cmake --build ${IOS_ARM64} --target fastdeploy -j8

# ===================== 构建 iOS 模拟器 (arm64) =====================
echo "📦 构建 iOS 模拟器 (arm64)..."
IOS_SIM=${BUILD_DIR}/ios/simulator
cmake -S . -B ${IOS_SIM} \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  "${COMMON_CMAKE_ARGS[@]}"

cmake --build ${IOS_SIM} --target fastdeploy -j8

# ===================== 构建 macOS (arm64) =====================
echo "📦 构建 macOS (arm64)..."
MACOS_BUILD=${BUILD_DIR}/macos
cmake -S . -B ${MACOS_BUILD} \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  "${COMMON_CMAKE_ARGS[@]}"

cmake --build ${MACOS_BUILD} --target fastdeploy -j8

# ===================== 合并静态库和收集头文件 =====================
echo "📦 处理静态库和头文件..."

merge_static_libs() {
    local BUILD_PATH=$1
    local OUTPUT_DIR=$2
    
    mkdir -p ${OUTPUT_DIR}/lib ${OUTPUT_DIR}/include
    
    local MAIN_LIB=${BUILD_PATH}/lib${LIB_NAME}.a
    [ -f "${MAIN_LIB}" ] || { echo "❌ 未找到 ${MAIN_LIB}"; exit 1; }
    
    local STATIC_LIBS=("${MAIN_LIB}")
    local THIRD_INSTALL_DIR=${BUILD_PATH}/third_libs/install
    
    if [ -d "${THIRD_INSTALL_DIR}" ]; then
        for LIB_DIR in ${THIRD_INSTALL_DIR}/*; do
            [ -d "${LIB_DIR}/lib" ] || continue
            for static_lib in ${LIB_DIR}/lib/*.a; do
                [ -f "${static_lib}" ] && STATIC_LIBS+=("${static_lib}")
            done
        done
    fi
    
    if [ ${#STATIC_LIBS[@]} -eq 1 ]; then
        cp "${MAIN_LIB}" "${OUTPUT_DIR}/lib/lib${LIB_NAME}.a"
    else
        /usr/bin/libtool -static -o "${OUTPUT_DIR}/lib/lib${LIB_NAME}.a" "${STATIC_LIBS[@]}"
    fi
    
    cp -a ${ROOT_DIR}/fastdeploy ${OUTPUT_DIR}/include/
    if [ -d "${THIRD_INSTALL_DIR}" ]; then
        for LIB_DIR in ${THIRD_INSTALL_DIR}/*; do
            [ -d "${LIB_DIR}/include" ] && cp -a ${LIB_DIR}/include/* ${OUTPUT_DIR}/include/ 2>/dev/null || true
        done
    fi
}

merge_static_libs ${IOS_ARM64} ${BUILD_DIR}/ios_arm64_output
merge_static_libs ${IOS_SIM} ${BUILD_DIR}/ios_sim_output
merge_static_libs ${MACOS_BUILD} ${BUILD_DIR}/macos_output

# ===================== 打包 XCFramework =====================
echo "📦 创建 XCFramework..."
mkdir -p ${INSTALL_DIR}

xcodebuild -create-xcframework \
  -library ${BUILD_DIR}/ios_arm64_output/lib/lib${LIB_NAME}.a -headers ${BUILD_DIR}/ios_arm64_output/include \
  -library ${BUILD_DIR}/ios_sim_output/lib/lib${LIB_NAME}.a -headers ${BUILD_DIR}/ios_sim_output/include \
  -library ${BUILD_DIR}/macos_output/lib/lib${LIB_NAME}.a -headers ${BUILD_DIR}/macos_output/include \
  -output ${INSTALL_DIR}/${XCFRAMEWORK_NAME} 2>&1 | tee /tmp/xcframework_create.log || true


echo ""
echo "✅ XCFramework created at ${INSTALL_DIR}/${XCFRAMEWORK_NAME}"
