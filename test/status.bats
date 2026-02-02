#!/usr/bin/env bats
#
# Tests for shuttle status command
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# General Status Tests
#---------------------------------------

@test "status: shows SSD info when no path given" {
    run shuttle status
    assert_success
    assert_output --partial "SSD Path"
    assert_output --partial "Storage Dir"
}

@test "status: shows offloaded items count" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle status
    assert_success
    assert_output --partial "1 items"
}

@test "status: shows SSD space information" {
    run shuttle status
    assert_success
    assert_output --partial "SSD Used"
    assert_output --partial "SSD Free"
}

#---------------------------------------
# Path-Specific Status Tests
#---------------------------------------

@test "status: shows 'Local' for regular directory" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    run shuttle status "$test_dir"
    assert_success
    assert_output --partial "Local"
    assert_output --partial "internal drive"
}

@test "status: shows 'Offloaded' for symlinked directory" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle status "$test_dir"
    assert_success
    assert_output --partial "Offloaded"
    assert_output --partial "Symlink"
}

@test "status: shows SSD connection status for offloaded item" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle status "$test_dir"
    assert_success
    assert_output --partial "SSD connected"
    assert_output --partial "data accessible"
}

@test "status: shows warning when SSD disconnected for offloaded item" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"
    disconnect_ssd

    run shuttle status "$test_dir"
    # Should still work but show warning
    assert_output --partial "not connected" || assert_output --partial "inaccessible"
}

@test "status: shows 'Not found' for non-existent path" {
    run shuttle status "$HOME/does_not_exist"
    assert_success
    assert_output --partial "Not found"
}

@test "status: identifies non-shuttle symlinks" {
    # Create a symlink pointing elsewhere
    mkdir -p "$HOME/other_location"
    ln -s "$HOME/other_location" "$HOME/my_link"

    run shuttle status "$HOME/my_link"
    assert_success
    assert_output --partial "Symlink"
    assert_output --partial "not managed by shuttle"
}

#---------------------------------------
# Command Aliases Tests
#---------------------------------------

@test "status: 'stat' alias works" {
    run shuttle stat
    assert_success
    assert_output --partial "SSD Path"
}

@test "status: 's' alias works" {
    run shuttle s
    assert_success
    assert_output --partial "SSD Path"
}
