mkdir build
cd build

cmake .. -G "Visual Studio 17 2022" -A x64 ^
         -DCMAKE_CXX_STANDARD=17 ^
         -DENABLE_ORT_BACKEND=OFF ^
         -DENABLE_OPENVINO_BACKEND=OFF ^
         -DENABLE_PADDLE_BACKEND=ON ^
         -DENABLE_VISION=OFF ^
         -DCMAKE_INSTALL_PREFIX=./install


cmake --build . --config Release --target install -- /m