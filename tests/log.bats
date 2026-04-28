#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() { setup_zinstall_env; source "$ZINSTALL_ROOT/lib/log.sh"; }
teardown() { teardown_zinstall_env; }

@test "log::info prints to stdout with an INFO tag" {
  run log::info "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO"* ]]
  [[ "$output" == *"hello"* ]]
}

@test "log::warn prints to stderr with a WARN tag" {
  run --separate-stderr log::warn "careful"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"WARN"* ]]
  [[ "$stderr" == *"careful"* ]]
}

@test "log::error prints to stderr with an ERROR tag" {
  run --separate-stderr log::error "boom"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"ERROR"* ]]
}

@test "log::ok prints to stdout with an OK tag" {
  run log::ok "done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"done"* ]]
}

@test "log::section prints a banner line" {
  run log::section "phase 1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"phase 1"* ]]
}

@test "NO_COLOR disables ANSI escapes" {
  NO_COLOR=1 run log::info "plain"
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\e['* ]]
}
