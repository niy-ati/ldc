cmake_minimum_required(VERSION 3.20)
project(ldc_dcompute_dx_harness LANGUAGES CXX)

add_executable(ldc_dx_harness main.cpp)
target_compile_features(ldc_dx_harness PRIVATE cxx_std_17)
if(MSVC)
  target_compile_options(ldc_dx_harness PRIVATE /W4 /permissive-)
endif()

target_link_libraries(ldc_dx_harness PRIVATE d3d12.lib dxgi.lib ole32.lib)
