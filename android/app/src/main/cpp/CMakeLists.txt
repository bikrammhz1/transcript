cmake_minimum_required(VERSION 3.10)
project(llama_android)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add compile options
add_compile_options(-Wall -Wextra -Wno-unused-parameter)

# Find required libraries
find_library(log-lib log)
find_library(android-lib android)

# Include directories
# NOTE: Adjust these paths based on your llama.cpp installation
# Option 1: If llama.cpp is a subdirectory
# add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../../llama.cpp llama-cpp)

# Option 2: If llama.cpp is installed separately
# set(LLAMA_CPP_DIR "/path/to/llama.cpp")
# include_directories(${LLAMA_CPP_DIR})
# link_directories(${LLAMA_CPP_DIR}/build)

# Option 3: If using pre-compiled library
# find_library(llama-lib llama
#     PATHS ${CMAKE_CURRENT_SOURCE_DIR}/../../../llama.cpp/build
# )

# Create JNI library
add_library(llama SHARED
    llama_android.cpp
)

# Link libraries
target_link_libraries(llama
    ${log-lib}
    ${android-lib}
    # Uncomment when llama.cpp is properly linked:
    # llama-cpp
    # OR:
    # ${llama-lib}
)

# Include directories for JNI
target_include_directories(llama PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    # Add llama.cpp include directory when available:
    # ${LLAMA_CPP_DIR}/include
)

# Notes for actual implementation:
# 1. Download and compile llama.cpp separately first
# 2. Build llama.cpp as a static or shared library
# 3. Point CMAKE to the compiled llama.cpp library location
# 4. Include llama.h header files
# 5. Link against the compiled llama library


