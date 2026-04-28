# shellcheck shell=bash
# Stub external commands by writing scripts into $STUB_BIN. Each invocation
# appends its argv to $TEST_TMP/calls/<cmd>.log so tests can assert on it.

mock_cmd() {
  local name="$1"
  local exit_code="${2:-0}"
  local stdout="${3:-}"
  mkdir -p "$TEST_TMP/calls"
  cat >"$STUB_BIN/$name" <<EOF
#!/usr/bin/env bash
echo "\$@" >>"$TEST_TMP/calls/$name.log"
[[ -n "$stdout" ]] && printf '%s\n' "$stdout"
exit $exit_code
EOF
  chmod +x "$STUB_BIN/$name"
}

assert_called() {
  local name="$1"
  [[ -f "$TEST_TMP/calls/$name.log" ]] || {
    echo "expected $name to be called but it was not"
    return 1
  }
}

assert_not_called() {
  local name="$1"
  if [[ -f "$TEST_TMP/calls/$name.log" ]]; then
    echo "expected $name NOT to be called but it was: $(cat "$TEST_TMP/calls/$name.log")"
    return 1
  fi
}

assert_called_with() {
  local name="$1" expected="$2"
  grep -Fxq "$expected" "$TEST_TMP/calls/$name.log" || {
    echo "expected $name called with: $expected"
    echo "actual calls:"
    cat "$TEST_TMP/calls/$name.log"
    return 1
  }
}
