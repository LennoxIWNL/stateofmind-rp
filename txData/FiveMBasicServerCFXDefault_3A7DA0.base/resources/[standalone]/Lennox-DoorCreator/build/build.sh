#!/bin/bash
# =========================================================================
#  Lennox Door Creator — Production Build Script
# =========================================================================

set -e

VERSION="1.0.0"
NAME="Lennox-DoorCreator"
DIST_DIR="dist"
OUTPUT="${NAME}-v${VERSION}"

echo "[Lennox] Building ${NAME} v${VERSION}..."

# 1. Build React NUI
echo "[Lennox] Building NUI..."
cd web
npm ci --silent
npm run build
cd ..

# 2. Create dist directory
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}/${OUTPUT}"

# 3. Copy files
echo "[Lennox] Copying files..."
cp fxmanifest.lua "${DIST_DIR}/${OUTPUT}/"
cp config.lua "${DIST_DIR}/${OUTPUT}/"
cp secrets.lua.example "${DIST_DIR}/${OUTPUT}/"
cp README.md "${DIST_DIR}/${OUTPUT}/"
cp LICENSE "${DIST_DIR}/${OUTPUT}/"

# Server
mkdir -p "${DIST_DIR}/${OUTPUT}/server/framework"
cp server/*.lua "${DIST_DIR}/${OUTPUT}/server/"
cp server/framework/*.lua "${DIST_DIR}/${OUTPUT}/server/framework/"

# Client
mkdir -p "${DIST_DIR}/${OUTPUT}/client"
cp client/*.lua "${DIST_DIR}/${OUTPUT}/client/"

# Shared
mkdir -p "${DIST_DIR}/${OUTPUT}/shared"
cp shared/*.lua "${DIST_DIR}/${OUTPUT}/shared/"

# SQL
mkdir -p "${DIST_DIR}/${OUTPUT}/sql"
cp sql/*.sql "${DIST_DIR}/${OUTPUT}/sql/"

# Web build
mkdir -p "${DIST_DIR}/${OUTPUT}/web/build"
cp -r web/build/* "${DIST_DIR}/${OUTPUT}/web/build/"

# 4. Package
echo "[Lennox] Packaging..."
cd "${DIST_DIR}"
zip -r "${OUTPUT}.zip" "${OUTPUT}" -x "*.DS_Store" "*__MACOSX*"
cd ..

echo "[Lennox] Build complete: ${DIST_DIR}/${OUTPUT}.zip"
echo "[Lennox] Files included:"
find "${DIST_DIR}/${OUTPUT}" -type f | wc -l
echo " files"
