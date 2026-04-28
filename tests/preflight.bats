#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/preflight.sh"
  # Default to a "happy path" environment.
  mock_cmd bootc 0 "fine"
  mock_cmd sudo 0 ""
  mock_cmd curl 0 ""
  echo 'ID=fedora' >"$TEST_TMP/os-release"
  export ZINSTALL_OS_RELEASE="$TEST_TMP/os-release"
}
teardown() { teardown_zinstall_env; }

@test "run_preflight passes on a valid Fedora bootc host" {
  EUID=1000 run run_preflight
  [ "$status" -eq 0 ]
}

@test "run_preflight fails when bootc is missing" {
  rm "$STUB_BIN/bootc"
  EUID=1000 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"bootc"* ]]
}

@test "run_preflight fails when /etc/os-release is not Fedora-family" {
  echo 'ID=ubuntu' >"$ZINSTALL_OS_RELEASE"
  EUID=1000 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"Fedora"* ]]
}

@test "run_preflight accepts ID_LIKE=fedora" {
  echo 'ID=zirconium' >"$ZINSTALL_OS_RELEASE"
  echo 'ID_LIKE="fedora rhel"' >>"$ZINSTALL_OS_RELEASE"
  EUID=1000 run run_preflight
  [ "$status" -eq 0 ]
}

@test "run_preflight refuses to run as root" {
  EUID=0 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"root"* ]]
}

@test "run_preflight fails when network HEAD fails" {
  mock_cmd curl 7 ""  # connection refused
  EUID=1000 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"network"* || "$output" == *"github"* ]]
}
