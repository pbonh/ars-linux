#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/brew.sh"
  export ZINSTALL_LINUXBREW_PREFIX="$TEST_TMP/no-brew"
}
teardown() { teardown_zinstall_env; }

@test "run_brew_install is a no-op when brew is already on PATH" {
  mock_cmd brew 0 "/home/linuxbrew/.linuxbrew/bin\nHOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew\nexport HOMEBREW_PREFIX"
  run run_brew_install
  [ "$status" -eq 0 ]
  # The official installer (curl) must not have been invoked.
  assert_not_called curl
}

@test "run_brew_install runs the official installer when brew is missing" {
  # Simulate the installer by stubbing curl to return a simple echo.
  mock_cmd curl 0 'echo installer'
  ZINSTALL_BREW_MISSING=1 ZINSTALL_BREW_INSTALL_URL="https://example.invalid/install.sh" \
    run run_brew_install
  [ "$status" -eq 0 ]
  assert_called curl
  # bash is the system bash since we're not mocking it.
}

@test "run_brew_install honors DRY_RUN" {
  DRY_RUN=1 ZINSTALL_BREW_MISSING=1 run run_brew_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
}
