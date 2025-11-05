#!/bin/bash
set -e

# ===================== 配置路径 =====================
FASTDEPLOY_ROOT=$(pwd)
BUILD_DIR=$FASTDEPLOY_ROOT/build_ios
FRAMEWORK_NAME=fastdeploy
FRAMEWORK_DIR=$FASTDEPLOY_ROOT/$FRAMEWORK_NAME.framework
OPENCVDIR=/usr/local/opencv-4.10.0-static/lib/cmake/opencv4
THIRD_INSTALL_DIR=$BUILD_DIR/third_libs/install

# ===================== 1️⃣ 创建构建目录 =====================
rm -rf "$FRAMEWORK_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ===================== 2️⃣ 配置 CMake =====================
cmake .. \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DENABLE_ORT_BACKEND=ON \
    -DENABLE_VISION=ON \
    -DENABLE_TEXT=ON \
    -DCMAKE_CXX_FLAGS="-fembed-bitcode -O3" \
    -DCMAKE_CXX_STANDARD=17 \
    -DOPENCV_DIRECTORY=$OPENCVDIR \
    -DWITH_OPENCV_STATIC=ON


# ===================== 3️⃣ 编译主库 =====================
cmake --build . --target fastdeploy -j8

# ===================== 4️⃣ 创建 framework 目录结构 =====================
rm -rf "$FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR/Headers"
mkdir -p "$FRAMEWORK_DIR/Modules"
mkdir -p "$FRAMEWORK_DIR/Libraries"

# ===================== 5️⃣ 拷贝主 dylib =====================
FD_DYLIB="$BUILD_DIR/libfastdeploy.dylib"
if [ ! -f "$FD_DYLIB" ]; then
    echo "❌ 未找到 libfastdeploy.dylib，请确认已成功编译"
    exit 1
fi
cp "$FD_DYLIB" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# 修改 dylib install_name 和 rpath
install_name_tool -id @rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
install_name_tool -add_rpath @loader_path/Libraries "$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# ===================== 6️⃣ 拷贝第三方 dylib 并修改依赖 =====================
echo "📦 处理第三方依赖 dylib..."
for LIB_DIR in "$THIRD_INSTALL_DIR"/*; do
    if [ -d "$LIB_DIR/lib" ]; then
        for dylib in "$LIB_DIR/lib/"*.dylib; do
            [ -f "$dylib" ] || continue
            cp "$dylib" "$FRAMEWORK_DIR/Libraries/"
            dylib_name=$(basename "$dylib")
            # 修改第三方 dylib install_name
            install_name_tool -id @rpath/$dylib_name "$FRAMEWORK_DIR/Libraries/$dylib_name"
            # 修改主库依赖路径
            install_name_tool -change "$dylib_name" "@rpath/$dylib_name" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
        done
    fi
done

# ===================== 7️⃣ 拷贝头文件 =====================
# FastDeploy 自身头文件
cp -a "$FASTDEPLOY_ROOT/fastdeploy/"* "$FRAMEWORK_DIR/Headers/" 2>/dev/null || true
# 第三方头文件
for LIB_DIR in "$THIRD_INSTALL_DIR"/*; do
    if [ -d "$LIB_DIR/include" ]; then
        cp -a "$LIB_DIR/include/"* "$FRAMEWORK_DIR/Headers/" 2>/dev/null || true
    fi
done

# ===================== 8️⃣ 创建 module.modulemap =====================
cat > "$FRAMEWORK_DIR/Modules/module.modulemap" <<EOF
framework module $FRAMEWORK_NAME {
    umbrella header "fastdeploy.h"
    export *
    module * { export * }
}
EOF

# ===================== 9️⃣ 生成 Info.plist =====================
cat > "$FRAMEWORK_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.fastdeploy.$FRAMEWORK_NAME</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
EOF

echo "✅ $FRAMEWORK_NAME.framework 已生成到: $FRAMEWORK_DIR"
echo "包含:"
echo "  • 主 dylib: $FRAMEWORK_NAME"
echo "  • 第三方 dylib (onnxruntime / paddle2onnx / fast_tokenizer)"
echo "  • 头文件和 modulemap"
