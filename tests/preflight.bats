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
  mock_cmd sleep 0
  echo 'ID=fedora' >"$TEST_TMP/os-release"
  export ZINSTALL_OS_RELEASE="$TEST_TMP/os-release"
  # Don't fork a real keep-alive subshell during tests.
  export ZINSTALL_SKIP_KEEPALIVE=1
}
teardown() { teardown_zinstall_env; }

@test "run_preflight passes on a valid Fedora bootc host" {
  ZINSTALL_EUID=1000 run run_preflight
  [ "$status" -eq 0 ]
}

@test "run_preflight fails when bootc is missing" {
  rm "$STUB_BIN/bootc"
  # Restrict PATH to STUB_BIN only so the host's /usr/bin/bootc is hidden.
  # The function returns at the bootc check before needing other binaries.
  PATH="$STUB_BIN" ZINSTALL_EUID=1000 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"bootc"* ]]
}

@test "run_preflight fails when /etc/os-release is not Fedora-family" {
  echo 'ID=ubuntu' >"$ZINSTALL_OS_RELEASE"
  ZINSTALL_EUID=1000 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"Fedora"* ]]
}

@test "run_preflight accepts ID_LIKE=fedora" {
  echo 'ID=zirconium' >"$ZINSTALL_OS_RELEASE"
  echo 'ID_LIKE="fedora rhel"' >>"$ZINSTALL_OS_RELEASE"
  ZINSTALL_EUID=1000 run run_preflight
  [ "$status" -eq 0 ]
}

@test "run_preflight refuses to run as root" {
  ZINSTALL_EUID=0 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"root"* ]]
}

@test "run_preflight fails when network HEAD fails" {
  mock_cmd curl 7 ""  # connection refused
  ZINSTALL_EUID=1000 run run_preflight
  [ "$status" -ne 0 ]
  [[ "$output" == *"network"* || "$output" == *"github"* ]]
}
