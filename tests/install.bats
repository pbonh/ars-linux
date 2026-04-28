#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() { setup_zinstall_env; }
teardown() { teardown_zinstall_env; }

@test "install.sh -h prints usage and exits 0" {
  run bash "$ZINSTALL_ROOT/install.sh" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"install.sh [flags]"* ]]
  [[ "$output" == *"--upgrade"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--prune"* ]]
  [[ "$output" == *"--only="* ]]
  [[ "$output" == *"--skip="* ]]
  [[ "$output" == *"--no-reboot-prompt"* ]]
  [[ "$output" == *"--verbose"* ]]
}

@test "install.sh --help also prints usage" {
  run bash "$ZINSTALL_ROOT/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"install.sh [flags]"* ]]
}

@test "install.sh refuses to run as root" {
  skip "covered by preflight tests"
}

@test "install.sh errors on unknown flag" {
  run bash "$ZINSTALL_ROOT/install.sh" --no-such-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* || "$output" == *"unrecognized"* ]]
}

@test "install.sh rejects --only and --skip together" {
  run bash "$ZINSTALL_ROOT/install.sh" --only=brew --skip=chezmoi
  [ "$status" -eq 2 ]
  [[ "$output" == *"mutually exclusive"* ]]
}
