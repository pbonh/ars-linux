#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/distrobox.sh"
  mkdir -p "$TEST_TMP/packages"
  cat >"$TEST_TMP/packages/distroboxes.ini" <<'EOF'
[dev]
image=registry.fedoraproject.org/fedora-toolbox:41
init=true
start_now=true
exported_bins="/usr/bin/podman"
exported_apps="code"

[ubuntu]
image=quay.io/toolbx/ubuntu-toolbox:24.04
init=true
EOF
  export ZINSTALL_DISTROBOX_INI="$TEST_TMP/packages/distroboxes.ini"
}
teardown() { teardown_zinstall_env; }

@test "run_distrobox fails clearly when distrobox binary is missing" {
  # Override PATH to exclude system directories where distrobox is installed
  # Use only directories that won't have distrobox
  PATH="/usr/local/bin:/home/linuxbrew/.linuxbrew/bin" run run_distrobox
  [ "$status" -ne 0 ]
  [[ "$output" == *"distrobox"* ]]
}

@test "run_distrobox creates missing containers via distrobox-assemble" {
  mock_cmd distrobox-assemble 0 ""
  mock_cmd distrobox-export 0 ""
  # 'distrobox list' returns empty (none exist)
  cat >"$STUB_BIN/distrobox" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/distrobox.log"
[[ "$1" == "list" ]] && exit 0
exit 0
EOF
  chmod +x "$STUB_BIN/distrobox"
  mkdir -p "$TEST_TMP/calls"
  run run_distrobox
  [ "$status" -eq 0 ]
  assert_called_with distrobox-assemble \
    "create --file $ZINSTALL_DISTROBOX_INI --name dev"
  assert_called_with distrobox-assemble \
    "create --file $ZINSTALL_DISTROBOX_INI --name ubuntu"
}

@test "run_distrobox re-exports binaries for existing containers without recreating" {
  mock_cmd distrobox-assemble 0 ""
  mock_cmd distrobox-export 0 ""
  # distrobox list reports both containers as already present.
  cat >"$STUB_BIN/distrobox" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/distrobox.log"
if [[ "$1" == "list" ]]; then
  printf 'ID  | NAME   | STATUS\n--- | dev    | up\n--- | ubuntu | up\n'
  exit 0
fi
exit 0
EOF
  chmod +x "$STUB_BIN/distrobox"
  mkdir -p "$TEST_TMP/calls"
  run run_distrobox
  [ "$status" -eq 0 ]
  assert_not_called distrobox-assemble
  # Bin/app exports should still re-run for the [dev] section.
  assert_called distrobox-export
}
