#!/usr/bin/env bats
#
# Tests for shuttle restore command
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# Basic Restore Tests
#---------------------------------------

@test "restore: moves directory back from SSD" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # First offload
    shuttle offload "$test_dir"
    assert [ -L "$test_dir" ]

    # Then restore
    run shuttle restore "$test_dir"
    assert_success

    # Should be a regular directory again
    assert [ -d "$test_dir" ]
    assert [ ! -L "$test_dir" ]
}

@test "restore: preserves file contents" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Add unique content
    echo "unique content 12345" > "$test_dir/unique.txt"

    shuttle offload "$test_dir"
    shuttle restore "$test_dir"

    # Content should be preserved
    local content
    content=$(cat "$test_dir/unique.txt")
    assert_equal "$content" "unique content 12345"
}

@test "restore: removes entry from manifest" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    # Should have 1 item
    assert_equal "$(get_manifest_count)" "1"

    shuttle restore "$test_dir"

    # Should have 0 items
    assert_equal "$(get_manifest_count)" "0"
}

@test "restore: cleans up empty parent directories on SSD" {
    local test_dir
    test_dir=$(create_test_dir "projects/web/app")

    shuttle offload "$test_dir"

    # Verify nested structure exists on SSD
    assert [ -d "$MOCK_SSD_PATH/Shuttle/projects/web/app" ]

    shuttle restore "$test_dir"

    # Empty parents should be cleaned up
    assert [ ! -d "$MOCK_SSD_PATH/Shuttle/projects/web/app" ]
    assert [ ! -d "$MOCK_SSD_PATH/Shuttle/projects/web" ]
    assert [ ! -d "$MOCK_SSD_PATH/Shuttle/projects" ]
}

@test "restore: shows success message" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle restore "$test_dir"
    assert_success
    assert_output --partial "Restored successfully"
}

#---------------------------------------
# Input Validation Tests
#---------------------------------------

@test "restore: fails for non-symlink path" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    run shuttle restore "$test_dir"
    assert_failure
    assert_output --partial "not a symlink"
}

@test "restore: fails for symlink not pointing to shuttle storage" {
    # Create a symlink pointing elsewhere
    mkdir -p "$HOME/other_location"
    ln -s "$HOME/other_location" "$HOME/my_link"

    run shuttle restore "$HOME/my_link"
    assert_failure
    assert_output --partial "does not point to shuttle storage"
}

@test "restore: fails when no path provided" {
    run shuttle restore
    assert_failure
    assert_output --partial "Usage"
}

@test "restore: fails when SSD not connected" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"
    disconnect_ssd

    run shuttle restore "$test_dir"
    assert_failure
    assert_output --partial "not mounted"
}

@test "restore: fails when offloaded data missing" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    # Remove data from SSD but keep SSD connected
    rm -rf "$MOCK_SSD_PATH/Shuttle/my_project"

    run shuttle restore "$test_dir"
    assert_failure
    assert_output --partial "not found"
}

#---------------------------------------
# Path Handling Tests
#---------------------------------------

@test "restore: handles paths with spaces" {
    local test_dir
    test_dir=$(create_dir_with_spaces "My Cool Project")

    shuttle offload "$test_dir"

    run shuttle restore "$test_dir"
    assert_success

    assert [ -d "$test_dir" ]
    assert [ ! -L "$test_dir" ]
}

@test "restore: handles relative paths" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    # Change to home and use relative path
    cd "$HOME"
    run shuttle restore "my_project"
    assert_success

    assert [ -d "$HOME/my_project" ]
    assert [ ! -L "$HOME/my_project" ]
}

@test "restore: handles paths with trailing slash" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle restore "$test_dir/"
    assert_success

    assert [ -d "$test_dir" ]
}

#---------------------------------------
# Command Aliases Tests
#---------------------------------------

@test "restore: 'res' alias works" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle res "$test_dir"
    assert_success
    assert [ -d "$test_dir" ]
    assert [ ! -L "$test_dir" ]
}

@test "restore: 'r' alias works" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle r "$test_dir"
    assert_success
    assert [ -d "$test_dir" ]
    assert [ ! -L "$test_dir" ]
}
