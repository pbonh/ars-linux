#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/postinstall.sh"
  mkdir -p "$TEST_TMP/packages/post-install.d"
  export ZINSTALL_POSTINSTALL_DIR="$TEST_TMP/packages/post-install.d"
}
teardown() { teardown_zinstall_env; }

@test "run_postinstall executes scripts in lexicographic order" {
  cat >"$ZINSTALL_POSTINSTALL_DIR/20-second.sh" <<EOF
#!/usr/bin/env bash
echo SECOND >>"$TEST_TMP/order"
EOF
  cat >"$ZINSTALL_POSTINSTALL_DIR/10-first.sh" <<EOF
#!/usr/bin/env bash
echo FIRST >>"$TEST_TMP/order"
EOF
  chmod +x "$ZINSTALL_POSTINSTALL_DIR"/*.sh
  run run_postinstall
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_TMP/order")" = $'FIRST\nSECOND' ]
}

@test "run_postinstall returns non-zero when a script fails but continues to others" {
  cat >"$ZINSTALL_POSTINSTALL_DIR/10-fail.sh" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
  cat >"$ZINSTALL_POSTINSTALL_DIR/20-ok.sh" <<EOF
#!/usr/bin/env bash
touch "$TEST_TMP/ok"
EOF
  chmod +x "$ZINSTALL_POSTINSTALL_DIR"/*.sh
  run run_postinstall
  [ "$status" -ne 0 ]
  [ -e "$TEST_TMP/ok" ]
}

@test "run_postinstall is a no-op when the dir is empty or missing" {
  run run_postinstall
  [ "$status" -eq 0 ]
}

@test "run_postinstall honors DRY_RUN by skipping execution" {
  cat >"$ZINSTALL_POSTINSTALL_DIR/10-touch.sh" <<EOF
#!/usr/bin/env bash
touch "$TEST_TMP/should-not-exist"
EOF
  chmod +x "$ZINSTALL_POSTINSTALL_DIR/10-touch.sh"
  DRY_RUN=1 run run_postinstall
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_TMP/should-not-exist" ]
}
