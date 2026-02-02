#!/usr/bin/env bats
#
# Tests for shuttle offload command
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# Basic Offload Tests
#---------------------------------------

@test "offload: moves directory to SSD" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    run shuttle offload "$test_dir"
    assert_success

    # Original path should be a symlink
    assert [ -L "$test_dir" ]

    # Symlink should point to SSD storage
    local target
    target=$(readlink "$test_dir")
    assert [ "$target" = "$MOCK_SSD_PATH/Shuttle/my_project" ]
}

@test "offload: creates symlink that works" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    # Should be able to read file through symlink
    assert [ -f "$test_dir/file.txt" ]
    local content
    content=$(cat "$test_dir/file.txt")
    assert_equal "$content" "test content"
}

@test "offload: preserves directory structure on SSD" {
    local test_dir
    test_dir=$(create_test_dir "projects/web/app")

    shuttle offload "$test_dir"

    # Check that nested path was created on SSD
    assert [ -d "$MOCK_SSD_PATH/Shuttle/projects/web/app" ]
    assert [ -f "$MOCK_SSD_PATH/Shuttle/projects/web/app/file.txt" ]
}

@test "offload: adds entry to manifest" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    # Should have 1 item in manifest
    local count
    count=$(get_manifest_count)
    assert_equal "$count" "1"

    # Should be in manifest
    assert is_in_manifest "$test_dir"
}

@test "offload: shows success message" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    run shuttle offload "$test_dir"
    assert_success
    assert_output --partial "Offloaded successfully"
}

#---------------------------------------
# Input Validation Tests
#---------------------------------------

@test "offload: fails for non-existent path" {
    run shuttle offload "$HOME/does_not_exist"
    assert_failure
    assert_output --partial "does not exist"
}

@test "offload: fails for already-symlinked path" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # First offload
    shuttle offload "$test_dir"

    # Second offload should fail
    run shuttle offload "$test_dir"
    assert_failure
    assert_output --partial "already a symlink"
}

@test "offload: fails when no path provided" {
    run shuttle offload
    assert_failure
    assert_output --partial "Usage"
}

@test "offload: fails when SSD not connected" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    disconnect_ssd

    run shuttle offload "$test_dir"
    assert_failure
    assert_output --partial "not mounted"
}

#---------------------------------------
# Path Handling Tests
#---------------------------------------

@test "offload: handles paths with spaces" {
    local test_dir
    test_dir=$(create_dir_with_spaces "My Cool Project")

    run shuttle offload "$test_dir"
    assert_success

    assert [ -L "$test_dir" ]
    assert [ -f "$test_dir/file.txt" ]
}

@test "offload: handles relative paths" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Change to home and use relative path
    cd "$HOME"
    run shuttle offload "my_project"
    assert_success

    assert [ -L "$HOME/my_project" ]
}

@test "offload: handles paths with trailing slash" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    run shuttle offload "$test_dir/"
    assert_success

    assert [ -L "$test_dir" ]
}

@test "offload: handles nested directories" {
    local test_dir
    test_dir=$(create_nested_dir "deep_project")

    run shuttle offload "$test_dir"
    assert_success

    # Should be able to access deep file
    assert [ -f "$test_dir/level1/level2/level3/deep_file.txt" ]
}

#---------------------------------------
# Command Aliases Tests
#---------------------------------------

@test "offload: 'off' alias works" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    run shuttle off "$test_dir"
    assert_success
    assert [ -L "$test_dir" ]
}

@test "offload: 'o' alias works" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    run shuttle o "$test_dir"
    assert_success
    assert [ -L "$test_dir" ]
}
