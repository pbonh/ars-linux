#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/brew.sh"
  mkdir -p "$TEST_TMP/packages"
  echo 'brew "git"' >"$TEST_TMP/packages/Brewfile"
  export ZINSTALL_BREWFILE="$TEST_TMP/packages/Brewfile"
  # Make brew --help report the flatpak directive.
  mock_cmd brew 0 "Usage: brew bundle ... flatpak ..."
}
teardown() { teardown_zinstall_env; }

@test "run_brewfile fails when brew bundle lacks the flatpak directive" {
  mock_cmd brew 0 "no such directive here"
  run run_brewfile
  [ "$status" -ne 0 ]
  [[ "$output" == *"flatpak"* ]]
}

@test "run_brewfile runs 'brew bundle install' against the Brewfile" {
  run run_brewfile
  [ "$status" -eq 0 ]
  assert_called_with brew "bundle install --file=$ZINSTALL_BREWFILE"
}

@test "run_brewfile sets HOMEBREW_BUNDLE_NO_UPGRADE=1 without --upgrade" {
  cat >"$STUB_BIN/brew" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/brew.log"
echo "HOMEBREW_BUNDLE_NO_UPGRADE=${HOMEBREW_BUNDLE_NO_UPGRADE:-unset}" \
  >>"$TEST_TMP/calls/brew-env.log"
[[ "$1 $2" == "bundle --help" ]] && echo "flatpak directive present"
exit 0
EOF
  chmod +x "$STUB_BIN/brew"
  mkdir -p "$TEST_TMP/calls"
  run run_brewfile
  [ "$status" -eq 0 ]
  grep -q "HOMEBREW_BUNDLE_NO_UPGRADE=1" "$TEST_TMP/calls/brew-env.log"
}

@test "run_brewfile under --upgrade does NOT set HOMEBREW_BUNDLE_NO_UPGRADE" {
  cat >"$STUB_BIN/brew" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/brew.log"
echo "HOMEBREW_BUNDLE_NO_UPGRADE=${HOMEBREW_BUNDLE_NO_UPGRADE:-unset}" \
  >>"$TEST_TMP/calls/brew-env.log"
[[ "$1 $2" == "bundle --help" ]] && echo "flatpak directive present"
exit 0
EOF
  chmod +x "$STUB_BIN/brew"
  mkdir -p "$TEST_TMP/calls"
  UPGRADE=1 run run_brewfile
  [ "$status" -eq 0 ]
  grep -q "HOMEBREW_BUNDLE_NO_UPGRADE=unset" "$TEST_TMP/calls/brew-env.log"
}

@test "run_brewfile under --prune runs 'brew bundle cleanup --force'" {
  PRUNE=1 run run_brewfile
  [ "$status" -eq 0 ]
  assert_called_with brew "bundle cleanup --file=$ZINSTALL_BREWFILE --force"
}
