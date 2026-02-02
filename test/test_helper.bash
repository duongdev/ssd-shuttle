#!/usr/bin/env bash
#
# BATS test helper for Shuttle CLI tests
# Provides isolated test environment with mock SSD and config isolation
#

# Get the directory containing the shuttle script
SHUTTLE_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
SHUTTLE_CMD="$SHUTTLE_DIR/shuttle"

#---------------------------------------
# Load BATS helpers (with fallbacks)
#---------------------------------------

# Try to load bats-support
_load_bats_support() {
    local paths=(
        "${BATS_TEST_DIRNAME}/bats-support/load.bash"
        "/opt/homebrew/lib/bats-support/load.bash"
        "/usr/local/lib/bats-support/load.bash"
        "/usr/lib/bats-support/load.bash"
    )
    for path in "${paths[@]}"; do
        if [[ -f "$path" ]]; then
            source "$path"
            return 0
        fi
    done
    return 1
}

# Try to load bats-assert
_load_bats_assert() {
    local paths=(
        "${BATS_TEST_DIRNAME}/bats-assert/load.bash"
        "/opt/homebrew/lib/bats-assert/load.bash"
        "/usr/local/lib/bats-assert/load.bash"
        "/usr/lib/bats-assert/load.bash"
    )
    for path in "${paths[@]}"; do
        if [[ -f "$path" ]]; then
            source "$path"
            return 0
        fi
    done
    return 1
}

# Load helpers or use fallbacks
_load_bats_support || true
if ! _load_bats_assert; then
    # Fallback implementations when bats-assert is not available
    assert_success() {
        if [[ "$status" -ne 0 ]]; then
            echo "Expected success (exit code 0) but got $status" >&2
            echo "Output: $output" >&2
            return 1
        fi
    }

    assert_failure() {
        if [[ "$status" -eq 0 ]]; then
            echo "Expected failure (non-zero exit code) but got $status" >&2
            echo "Output: $output" >&2
            return 1
        fi
    }

    assert_output() {
        local partial=false
        local expected=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --partial)
                    partial=true
                    shift
                    ;;
                *)
                    expected="$1"
                    shift
                    ;;
            esac
        done

        if $partial; then
            if [[ "$output" != *"$expected"* ]]; then
                echo "Expected output to contain: $expected" >&2
                echo "Actual output: $output" >&2
                return 1
            fi
        else
            if [[ "$output" != "$expected" ]]; then
                echo "Expected output: $expected" >&2
                echo "Actual output: $output" >&2
                return 1
            fi
        fi
    }

    assert_equal() {
        if [[ "$1" != "$2" ]]; then
            echo "Expected: $2" >&2
            echo "Actual: $1" >&2
            return 1
        fi
    }

    assert() {
        if ! "$@"; then
            echo "Assertion failed: $*" >&2
            return 1
        fi
    }
fi

#---------------------------------------
# Setup/Teardown
#---------------------------------------

setup_test_environment() {
    # Create unique temp directory for this test
    export BATS_TEST_TMPDIR="$(mktemp -d)"

    # Isolated HOME directory
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"

    # Isolated config directory using XDG
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME"

    # Mock SSD path
    export MOCK_SSD_PATH="$BATS_TEST_TMPDIR/mock_ssd"
    mkdir -p "$MOCK_SSD_PATH"

    # Create shuttle config with CONFIRM=false for non-interactive testing
    mkdir -p "$XDG_CONFIG_HOME/shuttle"
    cat > "$XDG_CONFIG_HOME/shuttle/config" << EOF
# Shuttle Test Configuration
SSD_PATH="$MOCK_SSD_PATH"
STORAGE_DIR="Shuttle"
CONFIRM=false
EOF

    # Initialize empty manifest
    echo '{"items":[]}' > "$XDG_CONFIG_HOME/shuttle/manifest.json"
}

teardown_test_environment() {
    if [[ -n "$BATS_TEST_TMPDIR" && -d "$BATS_TEST_TMPDIR" ]]; then
        rm -rf "$BATS_TEST_TMPDIR"
    fi
}

#---------------------------------------
# Helper Functions
#---------------------------------------

# Run shuttle command
shuttle() {
    "$SHUTTLE_CMD" "$@"
}

# Create a test directory with optional content
create_test_dir() {
    local name="${1:-test_dir}"
    local path="$HOME/$name"
    mkdir -p "$path"
    echo "test content" > "$path/file.txt"
    echo "$path"
}

# Create a test directory with specific size (creates multiple files)
create_test_dir_with_size() {
    local name="${1:-test_dir}"
    local num_files="${2:-5}"
    local path="$HOME/$name"
    mkdir -p "$path"

    for i in $(seq 1 "$num_files"); do
        dd if=/dev/zero of="$path/file_$i.bin" bs=1024 count=10 2>/dev/null
    done
    echo "$path"
}

# Create nested directory structure
create_nested_dir() {
    local name="${1:-nested}"
    local path="$HOME/$name/level1/level2/level3"
    mkdir -p "$path"
    echo "deep content" > "$path/deep_file.txt"
    echo "$HOME/$name"
}

# Create directory with spaces in name
create_dir_with_spaces() {
    local name="${1:-My Test Dir}"
    local path="$HOME/$name"
    mkdir -p "$path"
    echo "content with spaces" > "$path/file.txt"
    echo "$path"
}

# Create directory with special characters
create_dir_with_special_chars() {
    local name="${1:-test-dir_2.0}"
    local path="$HOME/$name"
    mkdir -p "$path"
    echo "special content" > "$path/file.txt"
    echo "$path"
}

# Check if path is a symlink pointing to mock SSD
is_symlink_to_ssd() {
    local path="$1"
    [[ -L "$path" ]] && [[ "$(readlink "$path")" == "$MOCK_SSD_PATH"* ]]
}

# Check if path is a regular directory (not symlink)
is_regular_dir() {
    local path="$1"
    [[ -d "$path" ]] && [[ ! -L "$path" ]]
}

# Get the number of items in manifest
get_manifest_count() {
    jq '.items | length' "$XDG_CONFIG_HOME/shuttle/manifest.json" 2>/dev/null || echo "0"
}

# Check if path is in manifest
is_in_manifest() {
    local path="$1"
    jq -e --arg p "$path" '.items[] | select(.original == $p)' "$XDG_CONFIG_HOME/shuttle/manifest.json" >/dev/null 2>&1
}

# Get storage path on mock SSD
get_ssd_storage_path() {
    echo "$MOCK_SSD_PATH/Shuttle"
}

# Simulate SSD disconnection
disconnect_ssd() {
    if [[ -d "$MOCK_SSD_PATH" ]]; then
        mv "$MOCK_SSD_PATH" "${MOCK_SSD_PATH}.disconnected"
    fi
}

# Simulate SSD reconnection
reconnect_ssd() {
    if [[ -d "${MOCK_SSD_PATH}.disconnected" ]]; then
        mv "${MOCK_SSD_PATH}.disconnected" "$MOCK_SSD_PATH"
    fi
}

# Assert command succeeds
assert_success_silent() {
    run "$@"
    assert_success
}

# Assert command fails
assert_failure_silent() {
    run "$@"
    assert_failure
}

# Print debug info (useful during test development)
debug_state() {
    echo "# DEBUG: HOME=$HOME" >&3
    echo "# DEBUG: XDG_CONFIG_HOME=$XDG_CONFIG_HOME" >&3
    echo "# DEBUG: MOCK_SSD_PATH=$MOCK_SSD_PATH" >&3
    echo "# DEBUG: Manifest contents:" >&3
    cat "$XDG_CONFIG_HOME/shuttle/manifest.json" >&3 2>/dev/null || echo "# DEBUG: No manifest" >&3
}
