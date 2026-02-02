#!/usr/bin/env bats
#
# Tests for shuttle health command
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# Basic Health Check Tests
#---------------------------------------

@test "health: passes with no offloaded items" {
    run shuttle health
    assert_success
    assert_output --partial "No offloaded items"
}

@test "health: passes with healthy offloaded items" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle health
    assert_success
    assert_output --partial "healthy"
}

@test "health: reports SSD disconnected" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"
    disconnect_ssd

    run shuttle health
    assert_failure
    assert_output --partial "not connected" || assert_output --partial "not mounted"
}

@test "health: reports missing symlinks" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    # Manually remove the symlink (simulating user deletion)
    rm "$test_dir"

    run shuttle health
    assert_failure
    assert_output --partial "Symlinks missing" || assert_output --partial "issue"
}

@test "health: reports missing targets on SSD" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    # Remove data from SSD but keep symlink
    rm -rf "$MOCK_SSD_PATH/Shuttle/my_project"

    run shuttle health
    assert_failure
    assert_output --partial "missing" || assert_output --partial "issue"
}

#---------------------------------------
# Quiet Mode Tests
#---------------------------------------

@test "health: quiet mode returns 0 when healthy" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle health --quiet
    assert_success
    # Should have minimal or no output
}

@test "health: quiet mode returns 1 with issues" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"
    disconnect_ssd

    run shuttle health --quiet
    assert_failure
    # Should show brief warning
    assert_output --partial "SSD disconnected" || assert_output --partial "unavailable"
}

#---------------------------------------
# Multiple Items Tests
#---------------------------------------

@test "health: checks all offloaded items" {
    local dir1 dir2 dir3
    dir1=$(create_test_dir "project1")
    dir2=$(create_test_dir "project2")
    dir3=$(create_test_dir "project3")

    shuttle offload "$dir1"
    shuttle offload "$dir2"
    shuttle offload "$dir3"

    run shuttle health
    assert_success
    assert_output --partial "3 offloaded"
}

#---------------------------------------
# Command Aliases Tests
#---------------------------------------

@test "health: 'h' alias works" {
    run shuttle h
    assert_success
}
