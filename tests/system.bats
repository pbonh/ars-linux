#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/system.sh"
  mock_cmd sudo 0 ""
}
teardown() { teardown_zinstall_env; }

@test "run_system_upgrade is a no-op without --upgrade" {
  UPGRADE=0 REBOOT_NEEDED=0 run run_system_upgrade
  [ "$status" -eq 0 ]
  assert_not_called sudo
}

@test "run_system_upgrade calls 'sudo bootc upgrade' under --upgrade" {
  UPGRADE=1 REBOOT_NEEDED=0 run_system_upgrade
  assert_called_with sudo "bootc upgrade"
}

@test "run_system_upgrade sets REBOOT_NEEDED when bootc reports a staged deployment" {
  cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/sudo.log"
echo "Staged update deployment"
exit 0
EOF
  chmod +x "$STUB_BIN/sudo"
  mkdir -p "$TEST_TMP/calls"
  REBOOT_NEEDED=0 UPGRADE=1
  run_system_upgrade
  [ "$REBOOT_NEEDED" -eq 1 ]
}
