#!/bin/bash
# Build script for llama.cpp iOS library
# This script builds llama.cpp as a static library for iOS with Metal support

set -e  # Exit on error

echo "🔨 Building llama.cpp for iOS..."
echo ""

# Configuration
LLAMA_CPP_DIR="${1:-$HOME/Documents/llama.cpp}"
BUILD_DIR="$LLAMA_CPP_DIR/build-ios"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DEPLOYMENT_TARGET="13.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if llama.cpp directory exists
if [ ! -d "$LLAMA_CPP_DIR" ]; then
    echo -e "${YELLOW}⚠️  llama.cpp directory not found at: $LLAMA_CPP_DIR${NC}"
    echo "   Cloning llama.cpp..."
    
    mkdir -p "$(dirname "$LLAMA_CPP_DIR")"
    cd "$(dirname "$LLAMA_CPP_DIR")"
    git clone https://github.com/ggerganov/llama.cpp.git
    cd llama.cpp
    git checkout master || git checkout main
fi

echo -e "${GREEN}✅ Using llama.cpp at: $LLAMA_CPP_DIR${NC}"

# Navigate to llama.cpp directory
cd "$LLAMA_CPP_DIR"

# Create build directory
echo ""
echo "📁 Creating build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure CMake for iOS with Metal support
echo ""
echo "⚙️  Configuring CMake for iOS (ARM64) with Metal..."
cmake -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DGGML_METAL=ON \
      -DLLAMA_CURL=OFF \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_BUILD_SERVER=OFF \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      ..

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ CMake configuration failed!${NC}"
    exit 1
fi

# Build the library
echo ""
echo "🔨 Building library (this may take 5-15 minutes)..."
xcodebuild -project llama.cpp.xcodeproj \
           -scheme llama \
           -configuration Release \
           -sdk iphoneos \
           ARCHS=arm64 \
           ONLY_ACTIVE_ARCH=NO \
           -derivedDataPath ./build \
           clean build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Find the built libraries
LIB_PATH=$(find . -path "*/Release-iphoneos/libllama.a" -type f | head -1)
GGML_PATH=$(find . -path "*/Release-iphoneos/libggml.a" -type f | head -1)
GGML_BASE_PATH=$(find . -path "*/Release-iphoneos/libggml-base.a" -type f | head -1)
GGML_CPU_PATH=$(find . -path "*/Release-iphoneos/libggml-cpu.a" -type f | head -1)
GGML_METAL_PATH=$(find . -path "*/Release-iphoneos/libggml-metal.a" -type f | head -1)
GGML_BLAS_PATH=$(find . -path "*/Release-iphoneos/libggml-blas.a" -type f | head -1)

if [ -z "$LIB_PATH" ]; then
    echo -e "${RED}❌ Could not find libllama.a after build!${NC}"
    echo "Searching in: $(pwd)"
    find . -name "*.a" -type f
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Build successful!${NC}"
echo -e "${GREEN}   libllama.a: $LIB_PATH${NC}"
echo -e "${GREEN}   libggml.a: $GGML_PATH${NC}"

# Copy header files to project
echo ""
echo "📋 Copying header files to project..."

LLAMA_HEADERS_DIR="$PROJECT_DIR/ios/llama.cpp"
mkdir -p "$LLAMA_HEADERS_DIR"

# Copy essential headers
cp "$LLAMA_CPP_DIR/include/llama.h" "$LLAMA_HEADERS_DIR/" 2>/dev/null || cp "$LLAMA_CPP_DIR/llama.h" "$LLAMA_HEADERS_DIR/" 2>/dev/null || echo "⚠️  llama.h not found"
cp "$LLAMA_CPP_DIR/ggml/include/ggml.h" "$LLAMA_HEADERS_DIR/" 2>/dev/null || cp "$LLAMA_CPP_DIR/ggml.h" "$LLAMA_HEADERS_DIR/" 2>/dev/null || echo "⚠️  ggml.h not found"

echo -e "${GREEN}✅ Headers copied to: $LLAMA_HEADERS_DIR${NC}"

# Copy all libraries
cp "$LIB_PATH" "$LLAMA_HEADERS_DIR/"
[ -n "$GGML_PATH" ] && cp "$GGML_PATH" "$LLAMA_HEADERS_DIR/"
[ -n "$GGML_BASE_PATH" ] && cp "$GGML_BASE_PATH" "$LLAMA_HEADERS_DIR/"
[ -n "$GGML_CPU_PATH" ] && cp "$GGML_CPU_PATH" "$LLAMA_HEADERS_DIR/"
[ -n "$GGML_METAL_PATH" ] && cp "$GGML_METAL_PATH" "$LLAMA_HEADERS_DIR/"
[ -n "$GGML_BLAS_PATH" ] && cp "$GGML_BLAS_PATH" "$LLAMA_HEADERS_DIR/"

# Copy Metal shader file if present
METAL_SHADER=$(find "$LLAMA_CPP_DIR" -name "ggml-metal.metal" -type f | head -1)
[ -n "$METAL_SHADER" ] && cp "$METAL_SHADER" "$LLAMA_HEADERS_DIR/"

echo -e "${GREEN}✅ Libraries copied to: $LLAMA_HEADERS_DIR${NC}"
ls -la "$LLAMA_HEADERS_DIR/"

echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Open Xcode: open $PROJECT_DIR/ios/Runner.xcworkspace"
echo "2. Add llama.cpp directory to Xcode project"
echo "3. Link libllama.a in Build Phases"
echo "4. Set Header Search Paths to include llama.cpp directory"
echo ""
echo "See ios/INTEGRATION_STEPS.md for detailed Xcode configuration"

