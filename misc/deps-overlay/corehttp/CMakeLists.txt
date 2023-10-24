project(corehttp)

include(${CMAKE_CURRENT_LIST_DIR}/httpFilePaths.cmake)
set(corehttp ${HTTP_SOURCES})

add_library(corehttp ${corehttp})
target_include_directories(corehttp PUBLIC ${HTTP_INCLUDE_PUBLIC_DIRS})
target_link_libraries(corehttp)