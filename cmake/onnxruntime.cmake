# Copyright (c) 2022 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include(ExternalProject)

set(ONNXRUNTIME_PROJECT "extern_onnxruntime")
set(ONNXRUNTIME_PREFIX_DIR ${THIRD_PARTY_PATH}/onnxruntime)
set(ONNXRUNTIME_SOURCE_DIR
    ${THIRD_PARTY_PATH}/onnxruntime/src/${ONNXRUNTIME_PROJECT})
set(ONNXRUNTIME_INSTALL_DIR ${THIRD_PARTY_PATH}/install/onnxruntime)

# 检查是否存在 xcframework（用于 macOS 和 iOS）
set(ONNXRUNTIME_XCFRAMEWORK_PATH "${PROJECT_SOURCE_DIR}/third_party/onnxruntime.xcframework")
set(USE_XCFRAMEWORK OFF)

if(APPLE AND EXISTS "${ONNXRUNTIME_XCFRAMEWORK_PATH}" AND NOT ORT_DIRECTORY)
  set(USE_XCFRAMEWORK ON)
  message(STATUS "Found onnxruntime.xcframework at: ${ONNXRUNTIME_XCFRAMEWORK_PATH}")
  
  # 根据平台和架构确定 xcframework 中的路径
  set(XCFRAMEWORK_PLATFORM_DIR "")
  set(XCFRAMEWORK_HEADERS_DIR "")
  set(XCFRAMEWORK_LIB_FILE "")
  
  if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    # iOS 平台
    # 判断是真机还是模拟器：检查 CMAKE_OSX_SYSROOT 是否包含 "simulator"
    if(CMAKE_OSX_SYSROOT MATCHES ".*simulator.*" OR CMAKE_OSX_SYSROOT MATCHES ".*Simulator.*")
      # iOS 模拟器
      message(STATUS "Detected iOS Simulator")
      set(XCFRAMEWORK_PLATFORM_DIR "${ONNXRUNTIME_XCFRAMEWORK_PATH}/ios-arm64_x86_64-simulator/onnxruntime.framework")
      set(XCFRAMEWORK_HEADERS_DIR "${XCFRAMEWORK_PLATFORM_DIR}/Headers")
      set(XCFRAMEWORK_LIB_FILE "${XCFRAMEWORK_PLATFORM_DIR}/onnxruntime")
    else()
      # iOS 真机
      message(STATUS "Detected iOS Device")
      set(XCFRAMEWORK_PLATFORM_DIR "${ONNXRUNTIME_XCFRAMEWORK_PATH}/ios-arm64/onnxruntime.framework")
      set(XCFRAMEWORK_HEADERS_DIR "${XCFRAMEWORK_PLATFORM_DIR}/Headers")
      set(XCFRAMEWORK_LIB_FILE "${XCFRAMEWORK_PLATFORM_DIR}/onnxruntime")
    endif()
  else()
    # macOS 平台
    message(STATUS "Detected macOS")
    set(XCFRAMEWORK_PLATFORM_DIR "${ONNXRUNTIME_XCFRAMEWORK_PATH}/macos-arm64_x86_64/onnxruntime.framework")
    set(XCFRAMEWORK_HEADERS_DIR "${XCFRAMEWORK_PLATFORM_DIR}/Versions/A/Headers")
    set(XCFRAMEWORK_LIB_FILE "${XCFRAMEWORK_PLATFORM_DIR}/Versions/A/onnxruntime")
  endif()
  
  # 验证文件是否存在
  if(NOT EXISTS "${XCFRAMEWORK_LIB_FILE}")
    message(WARNING "onnxruntime library not found at ${XCFRAMEWORK_LIB_FILE}, falling back to download")
    set(USE_XCFRAMEWORK OFF)
  else()
    message(STATUS "Using onnxruntime from xcframework:")
    message(STATUS "  Platform: ${CMAKE_SYSTEM_NAME}")
    message(STATUS "  Architecture: ${CMAKE_OSX_ARCHITECTURES}")
    message(STATUS "  Library: ${XCFRAMEWORK_LIB_FILE}")
    message(STATUS "  Headers: ${XCFRAMEWORK_HEADERS_DIR}")
    
    # 设置路径
    set(ONNXRUNTIME_INC_DIR
        "${XCFRAMEWORK_HEADERS_DIR}"
        CACHE PATH "onnxruntime include directory." FORCE)
    set(ONNXRUNTIME_LIB_DIR
        "${CMAKE_CURRENT_BINARY_DIR}/onnxruntime_extracted"
        CACHE PATH "onnxruntime lib directory." FORCE)
    
    # 创建临时目录并复制库文件
    file(MAKE_DIRECTORY ${ONNXRUNTIME_LIB_DIR})
    
    # 如果库文件是 universal binary 且只需要特定架构，可以提取
    # 但 CMake 会根据 CMAKE_OSX_ARCHITECTURES 自动处理，所以直接复制即可
    file(COPY "${XCFRAMEWORK_LIB_FILE}" DESTINATION ${ONNXRUNTIME_LIB_DIR})
    
    # 设置库文件路径（使用复制的文件）
    set(ONNXRUNTIME_LIB "${ONNXRUNTIME_LIB_DIR}/onnxruntime")
  endif()
endif()

if(NOT USE_XCFRAMEWORK)
  # 使用传统方式（下载或用户指定路径）
  if (ORT_DIRECTORY)
    message(STATUS "Use the onnxruntime lib specified by user. The ONNXRuntime path: ${ORT_DIRECTORY}")
    STRING(REGEX REPLACE "\\\\" "/" ORT_DIRECTORY ${ORT_DIRECTORY})
    set(ONNXRUNTIME_INC_DIR
      "${ORT_DIRECTORY}/include"
      CACHE PATH "onnxruntime include directory." FORCE)

    set(ONNXRUNTIME_LIB_DIR
      "${ORT_DIRECTORY}/lib"
      CACHE PATH "onnxruntime lib directory." FORCE)
  else()
    message(STATUS "Use the default onnxruntime lib. The ONNXRuntime path: ${ONNXRUNTIME_INSTALL_DIR}")
    set(ONNXRUNTIME_INC_DIR
        "${ONNXRUNTIME_INSTALL_DIR}/include"
        CACHE PATH "onnxruntime include directory." FORCE)
    set(ONNXRUNTIME_LIB_DIR
        "${ONNXRUNTIME_INSTALL_DIR}/lib"
        CACHE PATH "onnxruntime lib directory." FORCE)
  endif()
endif()

set(CMAKE_BUILD_RPATH "${CMAKE_BUILD_RPATH}" "${ONNXRUNTIME_LIB_DIR}")

set(ONNXRUNTIME_VERSION "1.21.0")
set(ONNXRUNTIME_URL_PREFIX "https://bj.bcebos.com/paddle2onnx/libs/")

if(WIN32) 
  if(WITH_GPU)
    set(ONNXRUNTIME_FILENAME "onnxruntime-win-x64-gpu-${ONNXRUNTIME_VERSION}.zip")
  elseif(WITH_DIRECTML)
    set(ONNXRUNTIME_FILENAME "onnxruntime-directml-win-x64.zip")
  else()
    set(ONNXRUNTIME_FILENAME "onnxruntime-win-x64-${ONNXRUNTIME_VERSION}.zip")
  endif()
  if(NOT CMAKE_CL_64)
    if(WITH_DIRECTML)
      set(ONNXRUNTIME_FILENAME "onnxruntime-directml-win-x86.zip")
    else()
      set(ONNXRUNTIME_FILENAME "onnxruntime-win-x86-${ONNXRUNTIME_VERSION}.zip")
    endif()
  endif()
elseif(APPLE)
  if(CURRENT_OSX_ARCH MATCHES "arm64")
    set(ONNXRUNTIME_FILENAME "onnxruntime-osx-arm64-${ONNXRUNTIME_VERSION}.tgz")
  else()
    set(ONNXRUNTIME_FILENAME "onnxruntime-osx-x86_64-${ONNXRUNTIME_VERSION}.tgz")
  endif()
else()
  if(WITH_GPU)
    if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "aarch64")
      message("Cannot compile with onnxruntime-gpu while in linux-aarch64 platform, fallback to onnxruntime-cpu")
      set(ONNXRUNTIME_FILENAME "onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}.tgz")
    else()
      set(ONNXRUNTIME_FILENAME "onnxruntime-linux-x64-gpu-${ONNXRUNTIME_VERSION}.tgz")
    endif()
  else()
    if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "aarch64")
      set(ONNXRUNTIME_FILENAME "onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}.tgz")
    else()
      # cross-compling while the host is x64 but the target is aarch64.
      if ((CMAKE_SYSTEM_PROCESSOR MATCHES "arm64") OR (CMAKE_SYSTEM_PROCESSOR MATCHES "arm"))
        set(ONNXRUNTIME_FILENAME "onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}.tgz")
      else()
        set(ONNXRUNTIME_FILENAME "onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}.tgz")
      endif()
    endif()
  endif()
endif()
set(ONNXRUNTIME_URL "${ONNXRUNTIME_URL_PREFIX}${ONNXRUNTIME_FILENAME}")

include_directories(${ONNXRUNTIME_INC_DIR})
# For ONNXRUNTIME code to include internal headers.

if(NOT USE_XCFRAMEWORK)
  # 使用传统方式，设置库文件路径
  if(WIN32)
    set(ONNXRUNTIME_LIB
        "${ONNXRUNTIME_LIB_DIR}/onnxruntime.lib"
        CACHE FILEPATH "ONNXRUNTIME shared library." FORCE)
  elseif(APPLE)
    set(ONNXRUNTIME_LIB
        "${ONNXRUNTIME_LIB_DIR}/libonnxruntime.dylib"
        CACHE FILEPATH "ONNXRUNTIME shared library." FORCE)
  else()
    set(ONNXRUNTIME_LIB
        "${ONNXRUNTIME_LIB_DIR}/libonnxruntime.so"
        CACHE FILEPATH "ONNXRUNTIME shared library." FORCE)
  endif()

  if (NOT ORT_DIRECTORY)
    ExternalProject_Add(
      ${ONNXRUNTIME_PROJECT}
      ${EXTERNAL_PROJECT_LOG_ARGS}
      URL ${ONNXRUNTIME_URL}
      PREFIX ${ONNXRUNTIME_PREFIX_DIR}
      DOWNLOAD_NO_PROGRESS 1
      CONFIGURE_COMMAND ""
      BUILD_COMMAND ""
      UPDATE_COMMAND ""
      INSTALL_COMMAND
        ${CMAKE_COMMAND} -E remove_directory ${ONNXRUNTIME_INSTALL_DIR} &&
        ${CMAKE_COMMAND} -E make_directory ${ONNXRUNTIME_INSTALL_DIR} &&
        ${CMAKE_COMMAND} -E rename ${ONNXRUNTIME_SOURCE_DIR}/lib/ ${ONNXRUNTIME_INSTALL_DIR}/lib &&
        ${CMAKE_COMMAND} -E copy_directory ${ONNXRUNTIME_SOURCE_DIR}/include
        ${ONNXRUNTIME_INC_DIR}
      BUILD_BYPRODUCTS ${ONNXRUNTIME_LIB})
    
    add_library(external_onnxruntime STATIC IMPORTED GLOBAL)
    set_property(TARGET external_onnxruntime PROPERTY IMPORTED_LOCATION ${ONNXRUNTIME_LIB})
    add_dependencies(external_onnxruntime ${ONNXRUNTIME_PROJECT})
  else()
    # 用户指定路径，不需要 ExternalProject
    add_library(external_onnxruntime STATIC IMPORTED GLOBAL)
    set_property(TARGET external_onnxruntime PROPERTY IMPORTED_LOCATION ${ONNXRUNTIME_LIB})
  endif()
else()
  # 使用 xcframework 静态库
  message(STATUS "Using onnxruntime static library from xcframework")
  add_library(external_onnxruntime STATIC IMPORTED GLOBAL)
  set_property(TARGET external_onnxruntime PROPERTY IMPORTED_LOCATION ${ONNXRUNTIME_LIB})
  # 不需要 ExternalProject，因为库文件已经在本地
endif()