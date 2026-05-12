#!/bin/bash

# Version and build count management script
# Simply increments version and success count on every successful build/run
#
# Usage:
#   - Xcode: Called from pre-build (prepare version) and post-build (update counts)
#   - CLI: Called with success/failure after build

set +e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -n "${SRCROOT}" ]; then
    PROJECT_ROOT="${SRCROOT}"
elif [ -n "${PROJECT_ROOT}" ]; then
    :
else
    PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"
fi

# Configuration
RESOURCES_INFO_PLIST="${PROJECT_ROOT}/MacaqueSVG/Resources/Info.plist"
ACTION="${1:-auto}"

# Auto-detect mode
MODE=""
if [ "$ACTION" = "prepare" ]; then
    MODE="prepare"
elif [ "$ACTION" = "success" ] || [ "$ACTION" = "failure" ]; then
    MODE="$ACTION"
elif [ -n "${SRCROOT}" ]; then
    MODE="success"
elif [ -n "$BUILD_EXIT_CODE" ]; then
    if [ "$BUILD_EXIT_CODE" -eq 0 ]; then
        MODE="success"
    else
        MODE="failure"
    fi
else
    MODE="success"
fi

if [ ! -f "$RESOURCES_INFO_PLIST" ]; then
    echo "❌ Resources/Info.plist not found at: $RESOURCES_INFO_PLIST" >&2
    exit 1
fi

get_plist_value() {
    local plist_file="$1"
    local key="$2"
    if [ -f "$plist_file" ]; then
        /usr/libexec/PlistBuddy -c "Print :$key" "$plist_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

set_plist_value() {
    local plist_file="$1"
    local key="$2"
    local value="$3"

    if [ ! -f "$plist_file" ]; then
        echo "❌ Plist file not found: $plist_file" >&2
        return 1
    fi

    chmod u+w "$plist_file" 2>/dev/null || true

    if /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_file" 2>/dev/null; then
        return 0
    fi

    if /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist_file" 2>/dev/null; then
        return 0
    fi

    echo "❌ Failed to set $key = $value in $plist_file" >&2
    return 1
}

update_both_plists() {
    local key="$1"
    local value="$2"

    set_plist_value "$RESOURCES_INFO_PLIST" "$key" "$value"

    BUILT_PLIST=""
    if [ -n "${BUILT_PRODUCTS_DIR}" ] && [ -n "${PRODUCT_NAME}" ]; then
        BUILT_PLIST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Info.plist"
        [ ! -f "$BUILT_PLIST" ] && BUILT_PLIST=""
    fi

    if [ -z "$BUILT_PLIST" ] && [ -n "${TARGET_BUILD_DIR}" ] && [ -n "${PRODUCT_NAME}" ]; then
        BUILT_PLIST="${TARGET_BUILD_DIR}/${PRODUCT_NAME}.app/Contents/Info.plist"
        [ ! -f "$BUILT_PLIST" ] && BUILT_PLIST=""
    fi

    if [ -z "$BUILT_PLIST" ] && [ -n "${CONFIGURATION_BUILD_DIR}" ] && [ -n "${PRODUCT_NAME}" ]; then
        BUILT_PLIST="${CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}.app/Contents/Info.plist"
        [ ! -f "$BUILT_PLIST" ] && BUILT_PLIST=""
    fi

    if [ -n "$BUILT_PLIST" ] && [ -f "$BUILT_PLIST" ]; then
        chmod u+w "$BUILT_PLIST" 2>/dev/null || true
        set_plist_value "$BUILT_PLIST" "$key" "$value"
    fi
}

CURRENT_YEAR=$(date +%Y)
CURRENT_MONTH=$(date +%m)
CURRENT_DAY=$(date +%d)
TODAY="${CURRENT_YEAR}.${CURRENT_MONTH}.${CURRENT_DAY}"

CURRENT_VERSION=$(get_plist_value "$RESOURCES_INFO_PLIST" "CFBundleShortVersionString")
CURRENT_SUCCESS=$(get_plist_value "$RESOURCES_INFO_PLIST" "BuildSuccessCount")
CURRENT_FAILURE=$(get_plist_value "$RESOURCES_INFO_PLIST" "BuildFailureCount")
CURRENT_SUCCESS_YEAR=$(get_plist_value "$RESOURCES_INFO_PLIST" "BuildSuccessCountYear")
CURRENT_FAILURE_YEAR=$(get_plist_value "$RESOURCES_INFO_PLIST" "BuildFailureCountYear")
CURRENT_SUCCESS_LIFETIME=$(get_plist_value "$RESOURCES_INFO_PLIST" "BuildSuccessCountLifetime")
CURRENT_FAILURE_LIFETIME=$(get_plist_value "$RESOURCES_INFO_PLIST" "BuildFailureCountLifetime")

if [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" = "" ]; then
    CURRENT_VERSION="${TODAY}-01"
fi
if [ -z "$CURRENT_SUCCESS" ] || [ "$CURRENT_SUCCESS" = "" ]; then
    CURRENT_SUCCESS="${CURRENT_YEAR}.${CURRENT_MONTH}.000"
fi
if [ -z "$CURRENT_FAILURE" ] || [ "$CURRENT_FAILURE" = "" ]; then
    CURRENT_FAILURE="${CURRENT_YEAR}.${CURRENT_MONTH}.000"
fi
if [ -z "$CURRENT_SUCCESS_YEAR" ] || [ "$CURRENT_SUCCESS_YEAR" = "" ]; then
    CURRENT_SUCCESS_YEAR="${CURRENT_YEAR}.000"
fi
if [ -z "$CURRENT_FAILURE_YEAR" ] || [ "$CURRENT_FAILURE_YEAR" = "" ]; then
    CURRENT_FAILURE_YEAR="${CURRENT_YEAR}.000"
fi
if [ -z "$CURRENT_SUCCESS_LIFETIME" ] || [ "$CURRENT_SUCCESS_LIFETIME" = "" ]; then
    CURRENT_SUCCESS_LIFETIME="0"
fi
if [ -z "$CURRENT_FAILURE_LIFETIME" ] || [ "$CURRENT_FAILURE_LIFETIME" = "" ]; then
    CURRENT_FAILURE_LIFETIME="0"
fi

SUCCESS_YEAR_KEY=$(echo "$CURRENT_SUCCESS_YEAR" | cut -d. -f1)
SUCCESS_YEAR_NUM=$(echo "$CURRENT_SUCCESS_YEAR" | cut -d. -f2)
FAILURE_YEAR_KEY=$(echo "$CURRENT_FAILURE_YEAR" | cut -d. -f1)
FAILURE_YEAR_NUM=$(echo "$CURRENT_FAILURE_YEAR" | cut -d. -f2)
if [ "$SUCCESS_YEAR_KEY" != "$CURRENT_YEAR" ]; then
    SUCCESS_YEAR_NUM="000"
fi
if [ "$FAILURE_YEAR_KEY" != "$CURRENT_YEAR" ]; then
    FAILURE_YEAR_NUM="000"
fi

SUCCESS_YEAR=$(echo "$CURRENT_SUCCESS" | cut -d. -f1)
SUCCESS_MONTH=$(echo "$CURRENT_SUCCESS" | cut -d. -f2)
SUCCESS_BUILD=$(echo "$CURRENT_SUCCESS" | cut -d. -f3)

FAILURE_YEAR=$(echo "$CURRENT_FAILURE" | cut -d. -f1)
FAILURE_MONTH=$(echo "$CURRENT_FAILURE" | cut -d. -f2)
FAILURE_BUILD=$(echo "$CURRENT_FAILURE" | cut -d. -f3)

if [ "$SUCCESS_YEAR" != "$CURRENT_YEAR" ] || [ "$SUCCESS_MONTH" != "$CURRENT_MONTH" ]; then
    SUCCESS_YEAR="$CURRENT_YEAR"
    SUCCESS_MONTH="$CURRENT_MONTH"
    SUCCESS_BUILD="000"
fi

if [ "$FAILURE_YEAR" != "$CURRENT_YEAR" ] || [ "$FAILURE_MONTH" != "$CURRENT_MONTH" ]; then
    FAILURE_YEAR="$CURRENT_YEAR"
    FAILURE_MONTH="$CURRENT_MONTH"
    FAILURE_BUILD="000"
fi

if [ "$MODE" = "prepare" ]; then
    BUILD_MARKER=""
    SUCCESS_MARKER=""
    if [ -n "${TARGET_BUILD_DIR}" ] && [ "${TARGET_BUILD_DIR}" != "/" ]; then
        BUILD_MARKER="${TARGET_BUILD_DIR}/.prebuild_marker"
        SUCCESS_MARKER="${TARGET_BUILD_DIR}/.build_succeeded_marker"
    fi

    if [ -n "$BUILD_MARKER" ] && [ -f "$BUILD_MARKER" ] && [ -n "$SUCCESS_MARKER" ] && [ ! -f "$SUCCESS_MARKER" ]; then
        echo "⚠️ Previous build failed - incrementing failure count" >&2
        CURRENT_BUILD_INT=$((10#$FAILURE_BUILD))
        FAILURE_BUILD_INT=$((CURRENT_BUILD_INT + 1))
        FAILURE_BUILD=$(printf "%03d" "$FAILURE_BUILD_INT")
        NEW_FAILURE="${FAILURE_YEAR}.${FAILURE_MONTH}.${FAILURE_BUILD}"
        update_both_plists "BuildFailureCount" "$NEW_FAILURE"
        FAILURE_YEAR_NUM_INT=$((10#$FAILURE_YEAR_NUM))
        FAILURE_YEAR_NUM_INT=$((FAILURE_YEAR_NUM_INT + 1))
        FAILURE_YEAR_NUM=$(printf "%03d" "$FAILURE_YEAR_NUM_INT")
        NEW_FAILURE_YEAR="${CURRENT_YEAR}.${FAILURE_YEAR_NUM}"
        FAILURE_LIFETIME=$((CURRENT_FAILURE_LIFETIME + 1))
        update_both_plists "BuildFailureCountYear" "$NEW_FAILURE_YEAR"
        update_both_plists "BuildFailureCountLifetime" "$FAILURE_LIFETIME"
        echo "❌ Previous build failure recorded - Failure count: $NEW_FAILURE" >&2
    fi

    rm -f "$SUCCESS_MARKER"

    if echo "$CURRENT_VERSION" | grep -qE "^[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]{2}$"; then
        VERSION_DATE=$(echo "$CURRENT_VERSION" | cut -d- -f1)
        VERSION_BUILD=$(echo "$CURRENT_VERSION" | cut -d- -f2)
        VERSION_BUILD_INT=$((10#$VERSION_BUILD))

        if [ "$VERSION_DATE" != "$TODAY" ]; then
            BUILD_NUMBER=1
        else
            BUILD_NUMBER=$((VERSION_BUILD_INT + 1))
        fi

        NEW_VERSION="${TODAY}-$(printf "%02d" "$BUILD_NUMBER")"
    else
        NEW_VERSION="${TODAY}-01"
    fi

    set_plist_value "$RESOURCES_INFO_PLIST" "CFBundleShortVersionString" "$NEW_VERSION"
    set_plist_value "$RESOURCES_INFO_PLIST" "CFBundleVersion" "$NEW_VERSION"

    if [ -n "${TARGET_BUILD_DIR}" ] && [ "${TARGET_BUILD_DIR}" != "/" ]; then
        mkdir -p "${TARGET_BUILD_DIR}"
        touch "$BUILD_MARKER"
    fi

    exit 0

elif [ "$MODE" = "success" ]; then
    CURRENT_BUILD_INT=$((10#$SUCCESS_BUILD))
    SUCCESS_BUILD_INT=$((CURRENT_BUILD_INT + 1))
    SUCCESS_BUILD=$(printf "%03d" "$SUCCESS_BUILD_INT")
    NEW_SUCCESS="${SUCCESS_YEAR}.${SUCCESS_MONTH}.${SUCCESS_BUILD}"

    SUCCESS_YEAR_NUM_INT=$((10#$SUCCESS_YEAR_NUM))
    SUCCESS_YEAR_NUM_INT=$((SUCCESS_YEAR_NUM_INT + 1))
    SUCCESS_YEAR_NUM=$(printf "%03d" "$SUCCESS_YEAR_NUM_INT")
    NEW_SUCCESS_YEAR="${CURRENT_YEAR}.${SUCCESS_YEAR_NUM}"
    SUCCESS_LIFETIME=$((CURRENT_SUCCESS_LIFETIME + 1))

    NEW_VERSION=$(get_plist_value "$RESOURCES_INFO_PLIST" "CFBundleShortVersionString")

    update_both_plists "BuildSuccessCount" "$NEW_SUCCESS"
    update_both_plists "BuildSuccessCountYear" "$NEW_SUCCESS_YEAR"
    update_both_plists "BuildSuccessCountLifetime" "$SUCCESS_LIFETIME"
    update_both_plists "CFBundleShortVersionString" "$NEW_VERSION"
    update_both_plists "CFBundleVersion" "$NEW_VERSION"

    if [ -n "${TARGET_BUILD_DIR}" ] && [ "${TARGET_BUILD_DIR}" != "/" ]; then
        mkdir -p "${TARGET_BUILD_DIR}"
        touch "${TARGET_BUILD_DIR}/.build_succeeded_marker"
        rm -f "${TARGET_BUILD_DIR}/.build_failed_marker"
    fi

    echo "✅ Build succeeded - Version: $NEW_VERSION, Success: $NEW_SUCCESS" >&2

elif [ "$MODE" = "failure" ]; then
    CURRENT_BUILD_INT=$((10#$FAILURE_BUILD))
    FAILURE_BUILD_INT=$((CURRENT_BUILD_INT + 1))
    FAILURE_BUILD=$(printf "%03d" "$FAILURE_BUILD_INT")
    NEW_FAILURE="${FAILURE_YEAR}.${FAILURE_MONTH}.${FAILURE_BUILD}"

    FAILURE_YEAR_NUM_INT=$((10#$FAILURE_YEAR_NUM))
    FAILURE_YEAR_NUM_INT=$((FAILURE_YEAR_NUM_INT + 1))
    FAILURE_YEAR_NUM=$(printf "%03d" "$FAILURE_YEAR_NUM_INT")
    NEW_FAILURE_YEAR="${CURRENT_YEAR}.${FAILURE_YEAR_NUM}"
    FAILURE_LIFETIME=$((CURRENT_FAILURE_LIFETIME + 1))

    update_both_plists "BuildFailureCount" "$NEW_FAILURE"
    update_both_plists "BuildFailureCountYear" "$NEW_FAILURE_YEAR"
    update_both_plists "BuildFailureCountLifetime" "$FAILURE_LIFETIME"

    echo "❌ Build failed - Failure count: $NEW_FAILURE" >&2
else
    echo "❌ Invalid mode: $MODE" >&2
    exit 1
fi

exit 0
