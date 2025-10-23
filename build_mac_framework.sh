#!/bin/bash
set -e

# ===================== 配置路径 =====================
FASTDEPLOY_ROOT=$(pwd)
BUILD_DIR=$FASTDEPLOY_ROOT/build_ios
FRAMEWORK_NAME=FastDeploy
FRAMEWORK_DIR=$FASTDEPLOY_ROOT/$FRAMEWORK_NAME.framework
OPENCVDIR=/Users/yan/Code/Opencv/opencv/opencv_xcframework_output/macos/build/build-arm64-macosx/install
# 第三方依赖（如 fast_tokenizer / onnxruntime / paddle2onnx）
THIRD_INSTALL_DIR=$BUILD_DIR/third_libs/install

# ===================== 1️⃣ 创建构建目录 =====================
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ===================== 2️⃣ 配置 CMake =====================
cmake .. \
    -DIOS_PLATFORM=OS64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_ORT_BACKEND=ON \
     -DENABLE_VISION=ON \
    -DENABLE_TEXT=ON \
    -DCMAKE_CXX_FLAGS="-fembed-bitcode -O3" \
    -DCMAKE_CXX_STANDARD=17 \
    -DOPENCV_DIRECTORY=$OPENCVDIR 

# ===================== 3️⃣ 编译动态库 =====================
cmake --build . --target fastdeploy -j8

# ===================== 4️⃣ 创建 Framework 目录结构 =====================
rm -rf "$FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR/Headers"
mkdir -p "$FRAMEWORK_DIR/Modules"
mkdir -p "$FRAMEWORK_DIR/Libraries"

# ===================== 5️⃣ 拷贝主库（动态库） =====================
FD_DYLIB="$BUILD_DIR/libfastdeploy.dylib"
if [ ! -f "$FD_DYLIB" ]; then
    echo "❌ 未找到 libfastdeploy.dylib，请确认已成功编译"
    exit 1
fi
cp "$FD_DYLIB" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# ===================== 6️⃣ 拷贝第三方依赖 =====================
echo "📦 拷贝第三方依赖库和头文件..."

for LIB_DIR in "$THIRD_INSTALL_DIR"/*; do
    NAME=$(basename "$LIB_DIR")
    echo "➡️  处理依赖: $NAME"

    # 库文件 (.dylib)
    if [ -d "$LIB_DIR/lib" ]; then
        cp -a "$LIB_DIR/lib/"*.dylib "$FRAMEWORK_DIR/Libraries/" 2>/dev/null || true
    fi

    # 头文件
    if [ -d "$LIB_DIR/include" ]; then
        cp -a "$LIB_DIR/include/"* "$FRAMEWORK_DIR/Headers/" 2>/dev/null || true
    fi
done

# ===================== 7️⃣ 拷贝 FastDeploy 自身头文件 =====================
cp -a "$FASTDEPLOY_ROOT/fastdeploy/"* "$FRAMEWORK_DIR/Headers/" 2>/dev/null || true

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
echo "  • $FD_DYLIB"
echo "  • 第三方依赖 (onnxruntime / paddle2onnx / fast_tokenizer)"
echo "  • 所有头文件和 modulemap"
