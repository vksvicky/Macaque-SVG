#!/bin/bash

# After merging branches, set Info.plist build success/failure counts to the maximum
# of both branches so we don't lose build history. Run from repo root after
# "git merge" (or pass two plist paths).
#
# Usage:
#   From repo root during/after merge:  scripts/version/merge_info_plist_counts.sh
#   With explicit paths:               scripts/version/merge_info_plist_counts.sh /path/to/ours.plist /path/to/theirs.plist

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
PLIST="${PROJECT_ROOT}/MacaqueSVG/Resources/Info.plist"

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
    [ ! -f "$plist_file" ] && return 1
    chmod u+w "$plist_file" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_file" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist_file" 2>/dev/null
}

ge_version() {
    local a_val="$1"
    local b_val="$2"
    [ -z "$b_val" ] && return 0
    [ -z "$a_val" ] && return 1
    [[ "$a_val" > "$b_val" || "$a_val" == "$b_val" ]] && return 0
    return 1
}

ge_int() {
    local a_val="${1:-0}"
    local b_val="${2:-0}"
    a_val=$((10#$a_val))
    b_val=$((10#$b_val))
    [ "$a_val" -ge "$b_val" ] && return 0
    return 1
}

OURS_PLIST=""
THEIRS_PLIST=""
if [ -n "$1" ] && [ -n "$2" ]; then
    OURS_PLIST="$1"
    THEIRS_PLIST="$2"
elif [ -f "$PROJECT_ROOT/.git/MERGE_HEAD" ]; then
    OURS_PLIST=$(mktemp)
    THEIRS_PLIST=$(mktemp)
    trap "rm -f '$OURS_PLIST' '$THEIRS_PLIST'" EXIT
    git show HEAD:MacaqueSVG/Resources/Info.plist >"$OURS_PLIST" 2>/dev/null || true
    git show MERGE_HEAD:MacaqueSVG/Resources/Info.plist >"$THEIRS_PLIST" 2>/dev/null || true
    if [ ! -s "$OURS_PLIST" ] || [ ! -s "$THEIRS_PLIST" ]; then
        echo "Could not read both sides of merge (HEAD and MERGE_HEAD)." >&2
        exit 1
    fi
    if [ ! -f "$PLIST" ]; then
        echo "MacaqueSVG/Resources/Info.plist not found. Create merge result first." >&2
        exit 1
    fi
else
    echo "Usage: $0 [ours.plist theirs.plist]" >&2
    echo "Or run from repo root during a merge (MERGE_HEAD present)." >&2
    exit 1
fi

COUNT_KEYS="BuildSuccessCount BuildFailureCount BuildSuccessCountYear BuildFailureCountYear"
LIFETIME_KEYS="BuildSuccessCountLifetime BuildFailureCountLifetime"

for key in $COUNT_KEYS; do
    v1=$(get_plist_value "$OURS_PLIST" "$key")
    v2=$(get_plist_value "$THEIRS_PLIST" "$key")
    if ge_version "$v1" "$v2"; then
        final="$v1"
    else
        final="$v2"
    fi
    [ -n "$final" ] && set_plist_value "$PLIST" "$key" "$final"
done

for key in $LIFETIME_KEYS; do
    v1=$(get_plist_value "$OURS_PLIST" "$key")
    v2=$(get_plist_value "$THEIRS_PLIST" "$key")
    if ge_int "$v1" "$v2"; then
        final="$v1"
    else
        final="$v2"
    fi
    [ -n "$final" ] && set_plist_value "$PLIST" "$key" "$final"
done

echo "Info.plist build counts updated to max of both branches."
