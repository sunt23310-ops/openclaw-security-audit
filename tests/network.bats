#!/usr/bin/env bats
# Network check tests

setup() {
    PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$PROJECT_DIR/lib/common.sh"
}

@test "network.sh has valid bash syntax" {
    bash -n "$PROJECT_DIR/checks/network.sh"
}

@test "OPENCLAW_CDP_PORT_MIN is 18800" {
    [ "$OPENCLAW_CDP_PORT_MIN" = "18800" ]
}

@test "OPENCLAW_CDP_PORT_MAX is 18899" {
    [ "$OPENCLAW_CDP_PORT_MAX" = "18899" ]
}

@test "OPENCLAW_OAUTH_PORT is 1455" {
    [ "$OPENCLAW_OAUTH_PORT" = "1455" ]
}

@test "counter functions work correctly" {
    reset_counters
    print_pass "test" > /dev/null
    print_pass "test" > /dev/null
    print_fail "test" > /dev/null
    [ "$PASS_COUNT" -eq 2 ]
    [ "$FAIL_COUNT" -eq 1 ]
}

@test "reset_counters zeroes all counters" {
    PASS_COUNT=5
    WARN_COUNT=3
    FAIL_COUNT=2
    SKIP_COUNT=1
    reset_counters
    [ "$PASS_COUNT" -eq 0 ]
    [ "$WARN_COUNT" -eq 0 ]
    [ "$FAIL_COUNT" -eq 0 ]
    [ "$SKIP_COUNT" -eq 0 ]
}
