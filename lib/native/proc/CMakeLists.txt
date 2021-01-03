cmake_minimum_required (VERSION 2.6)
project (eli_proc_native)

file(GLOB eli_proc_native_sources ./src/**.c)
SET(eli_proc_native ${eli_proc_native_sources})

ADD_LIBRARY (eli_proc_native ${eli_proc_native})
TARGET_LINK_LIBRARIES (eli_proc_native)