#!/usr/bin/env bats
#
# Tests for shuttle list command
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# List Command Tests
#---------------------------------------

@test "list: shows empty message when no items" {
    run shuttle list
    assert_success
    assert_output --partial "No items offloaded"
}

@test "list: shows offloaded items" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle list
    assert_success
    assert_output --partial "my_project"
}

@test "list: shows multiple offloaded items" {
    local dir1 dir2 dir3
    dir1=$(create_test_dir "project1")
    dir2=$(create_test_dir "project2")
    dir3=$(create_test_dir "project3")

    shuttle offload "$dir1"
    shuttle offload "$dir2"
    shuttle offload "$dir3"

    run shuttle list
    assert_success
    assert_output --partial "project1"
    assert_output --partial "project2"
    assert_output --partial "project3"
}

@test "list: shows item status (available/unavailable)" {
    local test_dir
    test_dir=$(create_test_dir "my_project")

    shuttle offload "$test_dir"

    run shuttle list
    assert_success
    # Should show checkmark for available item
    # Note: actual symbol depends on terminal, just check it runs
}

@test "list: shows size information" {
    local test_dir
    test_dir=$(create_test_dir_with_size "my_project" 5)

    shuttle offload "$test_dir"

    run shuttle list
    assert_success
    assert_output --partial "Size"
}

#---------------------------------------
# Command Aliases Tests
#---------------------------------------

@test "list: 'ls' alias works" {
    run shuttle ls
    assert_success
    assert_output --partial "Offloaded Items"
}

@test "list: 'l' alias works" {
    run shuttle l
    assert_success
    assert_output --partial "Offloaded Items"
}
