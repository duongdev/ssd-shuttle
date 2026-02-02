#!/usr/bin/env bats
#
# Integration tests for shuttle - end-to-end workflows
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# Full Workflow Tests
#---------------------------------------

@test "integration: complete offload-restore cycle" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Create some test content
    echo "important data" > "$test_dir/data.txt"
    mkdir -p "$test_dir/subdir"
    echo "nested data" > "$test_dir/subdir/nested.txt"

    # Verify initial state
    assert is_regular_dir "$test_dir"

    # Offload
    run shuttle offload "$test_dir"
    assert_success
    assert [ -L "$test_dir" ]
    assert_equal "$(get_manifest_count)" "1"

    # Verify files are still accessible via symlink
    assert_equal "$(cat "$test_dir/data.txt")" "important data"
    assert_equal "$(cat "$test_dir/subdir/nested.txt")" "nested data"

    # Restore
    run shuttle restore "$test_dir"
    assert_success
    assert is_regular_dir "$test_dir"
    assert_equal "$(get_manifest_count)" "0"

    # Verify files still exist after restore
    assert_equal "$(cat "$test_dir/data.txt")" "important data"
    assert_equal "$(cat "$test_dir/subdir/nested.txt")" "nested data"
}

@test "integration: offload multiple directories" {
    local dir1 dir2 dir3
    dir1=$(create_test_dir "project1")
    dir2=$(create_test_dir "project2")
    dir3=$(create_test_dir "project3")

    # Offload all
    shuttle offload "$dir1"
    shuttle offload "$dir2"
    shuttle offload "$dir3"

    # Verify all are symlinks
    assert [ -L "$dir1" ]
    assert [ -L "$dir2" ]
    assert [ -L "$dir3" ]

    # Manifest should have 3 items
    assert_equal "$(get_manifest_count)" "3"

    # List should show all
    run shuttle list
    assert_success
    assert_output --partial "project1"
    assert_output --partial "project2"
    assert_output --partial "project3"
}

@test "integration: partial restore workflow" {
    local dir1 dir2 dir3
    dir1=$(create_test_dir "project1")
    dir2=$(create_test_dir "project2")
    dir3=$(create_test_dir "project3")

    # Offload all
    shuttle offload "$dir1"
    shuttle offload "$dir2"
    shuttle offload "$dir3"

    # Restore only one
    shuttle restore "$dir2"

    # Check states
    assert [ -L "$dir1" ]
    assert is_regular_dir "$dir2"
    assert [ -L "$dir3" ]

    # Manifest should have 2 items
    assert_equal "$(get_manifest_count)" "2"
}

@test "integration: re-offload after restore" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # First cycle
    shuttle offload "$test_dir"
    shuttle restore "$test_dir"

    # Add new content
    echo "new content after restore" > "$test_dir/new_file.txt"

    # Second offload
    run shuttle offload "$test_dir"
    assert_success

    # Verify new content is accessible
    assert_equal "$(cat "$test_dir/new_file.txt")" "new content after restore"
}

@test "integration: health check in workflow" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Initially healthy (no items)
    run shuttle health
    assert_success

    # Offload and check health
    shuttle offload "$test_dir"
    run shuttle health
    assert_success

    # Disconnect SSD and check health
    disconnect_ssd
    run shuttle health
    assert_failure

    # Reconnect and verify recovery
    reconnect_ssd
    run shuttle health
    assert_success
}

@test "integration: status tracking throughout workflow" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Check initial status
    run shuttle status "$test_dir"
    assert_success
    assert_output --partial "Local"

    # After offload
    shuttle offload "$test_dir"
    run shuttle status "$test_dir"
    assert_success
    assert_output --partial "Offloaded"

    # After restore
    shuttle restore "$test_dir"
    run shuttle status "$test_dir"
    assert_success
    assert_output --partial "Local"
}

#---------------------------------------
# Error Recovery Tests
#---------------------------------------

@test "integration: recover from interrupted offload" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Simulate partial offload (data moved but symlink not created)
    mkdir -p "$MOCK_SSD_PATH/Shuttle"
    mv "$test_dir" "$MOCK_SSD_PATH/Shuttle/my_project"

    # User manually creates symlink
    ln -s "$MOCK_SSD_PATH/Shuttle/my_project" "$test_dir"

    # Add to manifest manually (simulating recovery)
    echo '{"items":[{"original":"'"$test_dir"'","offloaded":"'"$MOCK_SSD_PATH/Shuttle/my_project"'","timestamp":"2024-01-01T00:00:00Z"}]}' > "$XDG_CONFIG_HOME/shuttle/manifest.json"

    # Should be able to restore normally
    run shuttle restore "$test_dir"
    assert_success
}

@test "integration: offload with existing storage directory" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    # Pre-create storage directory
    mkdir -p "$MOCK_SSD_PATH/Shuttle"

    run shuttle offload "$test_dir"
    assert_success
}

#---------------------------------------
# Concurrent Operations Tests
#---------------------------------------

@test "integration: offload directories with shared parent" {
    mkdir -p "$HOME/projects"

    local dir1="$HOME/projects/app1"
    local dir2="$HOME/projects/app2"

    mkdir -p "$dir1" "$dir2"
    echo "app1" > "$dir1/file.txt"
    echo "app2" > "$dir2/file.txt"

    # Offload both
    shuttle offload "$dir1"
    shuttle offload "$dir2"

    # Both should work
    assert [ -L "$dir1" ]
    assert [ -L "$dir2" ]

    # Content should be accessible
    assert_equal "$(cat "$dir1/file.txt")" "app1"
    assert_equal "$(cat "$dir2/file.txt")" "app2"

    # Restore one
    shuttle restore "$dir1"

    # Other should still work
    assert_equal "$(cat "$dir2/file.txt")" "app2"
}
