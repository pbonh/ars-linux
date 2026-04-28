# shellcheck shell=bash
# Common bats setup: per-test temp HOME, PATH stubbing dir, and project root.

setup_zinstall_env() {
  ZINSTALL_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export ZINSTALL_ROOT
  TEST_TMP="$(mktemp -d "/tmp/zinstall-test-XXXXXX")"
  export TEST_TMP
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"
  STUB_BIN="$TEST_TMP/bin"
  mkdir -p "$STUB_BIN"
  export PATH="$STUB_BIN:$PATH"
  unset NO_COLOR
}

teardown_zinstall_env() {
  if [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP"
  fi
}
