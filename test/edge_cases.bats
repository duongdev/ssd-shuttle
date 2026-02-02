#!/usr/bin/env bats
#
# Edge case tests for shuttle - special characters, paths, error handling
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# Special Characters in Paths
#---------------------------------------

@test "edge: handles directory with spaces" {
    local test_dir
    test_dir=$(create_dir_with_spaces "My Project Files")

    run shuttle offload "$test_dir"
    assert_success

    run shuttle restore "$test_dir"
    assert_success
}

@test "edge: handles directory with dashes and underscores" {
    local test_dir
    test_dir=$(create_dir_with_special_chars "my-project_v2.0")

    run shuttle offload "$test_dir"
    assert_success

    assert [ -L "$test_dir" ]
    assert_equal "$(cat "$test_dir/file.txt")" "special content"
}

@test "edge: handles directory with dots" {
    local test_dir="$HOME/.hidden_project"
    mkdir -p "$test_dir"
    echo "hidden content" > "$test_dir/file.txt"

    run shuttle offload "$test_dir"
    assert_success

    assert [ -L "$test_dir" ]
}

@test "edge: handles directory with parentheses" {
    local test_dir="$HOME/project (copy)"
    mkdir -p "$test_dir"
    echo "copy content" > "$test_dir/file.txt"

    run shuttle offload "$test_dir"
    assert_success

    assert [ -L "$test_dir" ]
    assert_equal "$(cat "$test_dir/file.txt")" "copy content"
}

@test "edge: handles directory with ampersand" {
    local test_dir="$HOME/Tom & Jerry"
    mkdir -p "$test_dir"
    echo "cartoon content" > "$test_dir/file.txt"

    run shuttle offload "$test_dir"
    assert_success

    assert [ -L "$test_dir" ]
}

@test "edge: handles directory with single quotes" {
    local test_dir="$HOME/John's Project"
    mkdir -p "$test_dir"
    echo "john content" > "$test_dir/file.txt"

    run shuttle offload "$test_dir"
    assert_success

    assert [ -L "$test_dir" ]
}

#---------------------------------------
# Deep Nested Paths
#---------------------------------------

@test "edge: handles very deep nesting" {
    local deep_path="$HOME/a/b/c/d/e/f/g/h/i/j"
    mkdir -p "$deep_path"
    echo "deep content" > "$deep_path/file.txt"

    run shuttle offload "$deep_path"
    assert_success

    assert [ -L "$deep_path" ]
    assert_equal "$(cat "$deep_path/file.txt")" "deep content"

    run shuttle restore "$deep_path"
    assert_success
}

@test "edge: handles nested paths with spaces" {
    local deep_path="$HOME/My Projects/Web Apps/React App/src"
    mkdir -p "$deep_path"
    echo "react content" > "$deep_path/index.js"

    run shuttle offload "$deep_path"
    assert_success

    assert [ -L "$deep_path" ]
}

#---------------------------------------
# Empty and Large Directories
#---------------------------------------

@test "edge: handles empty directory" {
    local test_dir="$HOME/empty_project"
    mkdir -p "$test_dir"

    run shuttle offload "$test_dir"
    assert_success

    assert [ -L "$test_dir" ]

    run shuttle restore "$test_dir"
    assert_success

    assert [ -d "$test_dir" ]
    assert [ ! -L "$test_dir" ]
}

@test "edge: handles directory with many files" {
    local test_dir="$HOME/many_files"
    mkdir -p "$test_dir"

    # Create 100 files
    for i in $(seq 1 100); do
        echo "file $i content" > "$test_dir/file_$i.txt"
    done

    run shuttle offload "$test_dir"
    assert_success

    # Verify a few random files
    assert_equal "$(cat "$test_dir/file_1.txt")" "file 1 content"
    assert_equal "$(cat "$test_dir/file_50.txt")" "file 50 content"
    assert_equal "$(cat "$test_dir/file_100.txt")" "file 100 content"
}

#---------------------------------------
# Path Resolution Edge Cases
#---------------------------------------

@test "edge: handles current directory reference (.)" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    cd "$test_dir"

    # Go up and offload using relative path
    cd "$HOME"
    run shuttle offload "./my_project"
    assert_success
}

@test "edge: handles parent directory reference (..)" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    mkdir -p "$HOME/other"
    cd "$HOME/other"

    run shuttle offload "../my_project"
    assert_success
}

@test "edge: handles tilde expansion" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Note: tilde expansion happens in shell before shuttle sees it
    # This tests that the expanded path works correctly
    run shuttle offload ~/my_project
    assert_success
}

#---------------------------------------
# Error Handling Edge Cases
#---------------------------------------

@test "edge: handles permission denied gracefully" {
    # Skip if running as root
    if [[ $(id -u) -eq 0 ]]; then
        skip "Cannot test permission denied as root"
    fi

    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Make SSD read-only
    chmod 555 "$MOCK_SSD_PATH"

    run shuttle offload "$test_dir"
    assert_failure

    # Restore permissions for cleanup
    chmod 755 "$MOCK_SSD_PATH"
}

@test "edge: handles unknown command" {
    run shuttle unknown_command
    assert_failure
    assert_output --partial "Unknown command"
}

@test "edge: handles help flag" {
    run shuttle --help
    assert_success
    assert_output --partial "shuttle"
    assert_output --partial "offload"
    assert_output --partial "restore"
}

@test "edge: handles -h flag" {
    run shuttle -h
    assert_success
    assert_output --partial "shuttle"
}

#---------------------------------------
# Symlink Edge Cases
#---------------------------------------

@test "edge: handles symlink inside offloaded directory" {
    local test_dir="$HOME/my_project"
    mkdir -p "$test_dir"
    mkdir -p "$HOME/shared_libs"
    echo "shared content" > "$HOME/shared_libs/lib.txt"

    # Create symlink inside project
    ln -s "$HOME/shared_libs" "$test_dir/libs"
    echo "project content" > "$test_dir/main.txt"

    run shuttle offload "$test_dir"
    assert_success

    # Internal symlink should still work
    assert [ -L "$test_dir/libs" ]
}

@test "edge: rejects offloading a symlink target" {
    local real_dir="$HOME/real_project"
    local link_dir="$HOME/link_project"

    mkdir -p "$real_dir"
    echo "content" > "$real_dir/file.txt"
    ln -s "$real_dir" "$link_dir"

    # Trying to offload the symlink should fail
    run shuttle offload "$link_dir"
    assert_failure
    assert_output --partial "already a symlink"
}

#---------------------------------------
# CONFIRM Override Tests
#---------------------------------------

@test "edge: CONFIRM=false environment variable works" {
    # Create config with CONFIRM=true
    cat > "$XDG_CONFIG_HOME/shuttle/config" << EOF
SSD_PATH="$MOCK_SSD_PATH"
STORAGE_DIR="Shuttle"
CONFIRM=true
EOF

    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Should work without prompting due to env override
    # Use env to pass the variable through run
    run env CONFIRM=false "$SHUTTLE_CMD" offload "$test_dir"
    assert_success
}

@test "edge: CONFIRM override preserved through config sourcing" {
    # This tests the fix for the bug where CONFIRM was overwritten
    cat > "$XDG_CONFIG_HOME/shuttle/config" << EOF
SSD_PATH="$MOCK_SSD_PATH"
STORAGE_DIR="Shuttle"
CONFIRM=true
EOF

    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Offload with CONFIRM=false override
    CONFIRM=false shuttle offload "$test_dir"

    # Verify it was offloaded
    assert [ -L "$test_dir" ]

    # Now try to restore with override - must use env to pass the variable through run
    run env CONFIRM=false "$SHUTTLE_CMD" restore "$test_dir"
    assert_success
}

#---------------------------------------
# Manifest Edge Cases
#---------------------------------------

@test "edge: handles corrupted manifest gracefully" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Corrupt the manifest
    echo "not valid json" > "$XDG_CONFIG_HOME/shuttle/manifest.json"

    # Operations should still work (jq will fail gracefully)
    run shuttle list
    # May warn but shouldn't crash
}

@test "edge: handles missing manifest" {
    rm -f "$XDG_CONFIG_HOME/shuttle/manifest.json"

    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Should recreate manifest
    run shuttle offload "$test_dir"
    assert_success

    assert [ -f "$XDG_CONFIG_HOME/shuttle/manifest.json" ]
}
