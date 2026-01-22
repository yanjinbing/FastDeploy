mkdir build
cd build
set CMAKE_CXX_STANDARD=17
set CMAKE_CXX_STANDARD_REQUIRED=ON

cmake .. -G "Visual Studio 17 2022" -A x64 ^
         -DCMAKE_CXX_STANDARD=17 ^
         -DCMAKE_CXX_STANDARD_REQUIRED=ON ^
         -DCMAKE_CXX_EXTENSIONS=OFF ^
         -DENABLE_ORT_BACKEND=OFF ^
         -DENABLE_OPENVINO_BACKEND=OFF ^
         -DENABLE_PADDLE_BACKEND=ON ^
         -DENABLE_VISION=ON ^
         -DOPENCV_DIRECTORY="D:/Downloads/opencv/build" ^
         -DCMAKE_INSTALL_PREFIX=./install


cmake --build . --config Release --target install -- /m