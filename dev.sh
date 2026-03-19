#!/usr/bin/env bash

# ==============================================================================
# OpenDIHM Mobile iOS - Development Script
# Automates the cleanup, project generation, and simulator deployment.
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

readonly MODE="${1:-sim}"
readonly APP_BUNDLE_ID="com.opendihm.mobile-ios"
readonly SCHEME="OpenDIHM"
readonly BUILD_DIR="${PWD}/build"

# Logging Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}WARNING:${NC} $1" >&2
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

check_dependencies() {
    if ! command -v xcodegen >/dev/null 2>&1; then
        log_error "xcodegen is not installed. Please install it (e.g., brew install xcodegen) to continue."
        exit 1
    fi
}

# ==============================================================================
# Core Operations
# ==============================================================================

cleanup() {
    log_info "Cleaning build artifacts and Xcode project files..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${SCHEME}.xcodeproj"
    rm -rf "${SCHEME}.xcworkspace"
}

generate_project() {
    log_info "Regenerating Xcode project via xcodegen..."
    xcodegen >/dev/null
}

find_simulator() {
    local device_id
    # Extract the first available iPhone simulator UUID using regex
    device_id=$(xcrun simctl list devices available | awk '/iPhone/ { match($0, /[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/); if (RSTART) { print substr($0, RSTART, RLENGTH); exit } }')
    
    if [[ -z "${device_id}" ]]; then
        log_error "No available iPhone simulator could be found."
        exit 1
    fi
    echo "${device_id}"
}

prepare_simulator() {
    local device_id="$1"
    log_info "Targeting Simulator Device ID: ${device_id}"
    
    # Boot the simulator; redirect stderr as it naturally returns an error if already booted
    if ! xcrun simctl boot "${device_id}" 2>/dev/null; then
        local boot_status
        boot_status=$(xcrun simctl list devices | grep "${device_id}" | grep -o 'Booted' || true)
        if [[ "${boot_status}" != "Booted" ]]; then
            log_warn "Simulator boot command failed, but it may already be running or initializing."
        fi
    fi

    # Ensure the Simulator UI is launched
    open -a Simulator
}

build_app() {
    local device_id="$1"
    log_info "Building the OpenDIHM target..."

    xcodebuild build \
        -scheme "${SCHEME}" \
        -destination "id=${device_id}" \
        CONFIGURATION_BUILD_DIR="${BUILD_DIR}" \
        CODE_SIGNING_ALLOWED=NO \
        -quiet
}

deploy_and_run() {
    local device_id="$1"
    log_info "Installing the application onto the simulator..."
    xcrun simctl install "${device_id}" "${BUILD_DIR}/${SCHEME}.app"

    log_info "Launching the application..."
    xcrun simctl launch "${device_id}" "${APP_BUNDLE_ID}"
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

main() {
    check_dependencies
    
    if [[ "${MODE}" != "sim" && "${MODE}" != "deploy" ]]; then
        log_error "Usage: ./dev.sh [sim|deploy]"
        exit 1
    fi
    
    cleanup
    generate_project
    
    if [[ "${MODE}" == "deploy" ]]; then
        log_warn "Physical device deployment requires Code Signing via Apple Developer."
        log_info "Opening Xcode to handle code signing and physical deployment natively..."
        open "${SCHEME}.xcodeproj"
        log_success "Project generated and opened in Xcode!"
        exit 0
    fi
    
    # Simulator flow
    local simulator_id
    simulator_id=$(find_simulator)
    
    prepare_simulator "${simulator_id}"
    build_app "${simulator_id}"
    deploy_and_run "${simulator_id}"
    
    log_success "Development workflow completed. App is running in the simulator."
}

main "$@"
