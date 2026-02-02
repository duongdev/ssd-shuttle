#!/usr/bin/env bats
#
# Tests for shuttle config command
#

load test_helper

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

#---------------------------------------
# Config Display Tests
#---------------------------------------

@test "config: shows configuration" {
    run shuttle config
    assert_success
    assert_output --partial "Configuration"
    assert_output --partial "Config file"
}

@test "config: shows SSD_PATH setting" {
    run shuttle config
    assert_success
    assert_output --partial "SSD_PATH"
}

@test "config: shows STORAGE_DIR setting" {
    run shuttle config
    assert_success
    assert_output --partial "STORAGE_DIR"
}

@test "config: shows CONFIRM setting" {
    run shuttle config
    assert_success
    assert_output --partial "CONFIRM"
}

@test "config: shows edit instructions" {
    run shuttle config
    assert_success
    assert_output --partial "Edit with"
}

#---------------------------------------
# Config Creation Tests
#---------------------------------------

@test "config: creates config file if missing" {
    # Remove the config created by setup
    rm -f "$XDG_CONFIG_HOME/shuttle/config"

    run shuttle config
    assert_success

    # Config should be created
    assert [ -f "$XDG_CONFIG_HOME/shuttle/config" ]
}

@test "config: creates manifest file if missing" {
    # Remove the manifest created by setup
    rm -f "$XDG_CONFIG_HOME/shuttle/manifest.json"

    run shuttle config
    assert_success

    # Manifest should be created
    assert [ -f "$XDG_CONFIG_HOME/shuttle/manifest.json" ]
}

#---------------------------------------
# Command Aliases Tests
#---------------------------------------

@test "config: 'conf' alias works" {
    run shuttle conf
    assert_success
    assert_output --partial "Configuration"
}

@test "config: 'c' alias works" {
    run shuttle c
    assert_success
    assert_output --partial "Configuration"
}
