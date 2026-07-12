cmake_minimum_required(VERSION 3.22.1)
project(sgp_whisper_jni)

add_library(
        sgp_whisper_jni
        SHARED
        sgp_whisper_jni.cpp)

find_library(log-lib log)

target_link_libraries(
        sgp_whisper_jni
        ${log-lib})
