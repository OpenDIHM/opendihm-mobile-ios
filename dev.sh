#!/usr/bin/env bash
set -euo pipefail

# Configuration
readonly SCHEME="OpenDIHM"
readonly BUILD_DIR="${PWD}/build"
readonly IPA_NAME="${SCHEME}.ipa"

log_info() { echo -e "\033[0;34mINFO:\033[0m $1"; }
log_success() { echo -e "\033[0;32mSUCCESS:\033[0m $1"; }
log_error() { echo -e "\033[0;31mERROR:\033[0m $1"; exit 1; }

# 1. Projeyi her seferinde yeniden oluştur (Bu adım eksikti!)
log_info "Regenerating Xcode project via xcodegen..."
xcodegen >/dev/null || log_error "xcodegen failed!"

# 2. Build işlemi
log_info "Building for iOS device..."
xcodebuild build \
    -scheme "${SCHEME}" \
    -destination "generic/platform=iOS" \
    CONFIGURATION_BUILD_DIR="${BUILD_DIR}" \
    CODE_SIGNING_ALLOWED=NO \
    ASSETCATALOG_COMPILER_APPICON_NAME="" \
    -quiet

# 3. Paketleme
log_info "Packaging .app into .ipa..."
mkdir -p "${BUILD_DIR}/Payload"
cp -r "${BUILD_DIR}/${SCHEME}.app" "${BUILD_DIR}/Payload/"
cd "${BUILD_DIR}" && zip -ry "${IPA_NAME}" "Payload/" >/dev/null
rm -rf "${BUILD_DIR}/Payload"
log_success "IPA generated at: ${BUILD_DIR}/${IPA_NAME}"
