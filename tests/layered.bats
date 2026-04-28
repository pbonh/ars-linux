#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/layered.sh"
  mkdir -p "$TEST_TMP/packages/repos" "$TEST_TMP/yum.repos.d"
  cat >"$TEST_TMP/packages/layered.txt" <<'EOF'
# comment
zsh
docker-ce
EOF
  cat >"$TEST_TMP/packages/repos/docker-ce.repo" <<'EOF'
[docker-ce-stable]
name=Docker CE Stable
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
EOF
  export ZINSTALL_LAYERED_LIST="$TEST_TMP/packages/layered.txt"
  export ZINSTALL_REPOS_DIR="$TEST_TMP/packages/repos"
  export ZINSTALL_YUM_REPOS_D="$TEST_TMP/yum.repos.d"
  # Default: layering allowed (point at a non-existent conf so _layering_locked is false).
  export ZINSTALL_RPM_OSTREED_CONF="$TEST_TMP/no-rpm-ostreed.conf"
  mock_cmd sudo 0 ""
  mock_cmd jq 0 "[]"
}
teardown() { teardown_zinstall_env; }

@test "run_layered drops missing .repo files into yum.repos.d via sudo install" {
  cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/sudo.log"
if [[ "$1" == "install" ]]; then
  # Actually execute install for file drops
  shift
  install "$@"
fi
exit 0
EOF
  chmod +x "$STUB_BIN/sudo"
  cat >"$STUB_BIN/rpm-ostree" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/rpm-ostree.log"
if [[ "$1 $2" == "status --json" ]]; then echo '{"deployments":[{"requested-packages":[]}]}'; fi
exit 0
EOF
  chmod +x "$STUB_BIN/rpm-ostree"
  cat >"$STUB_BIN/jq" <<'EOF'
#!/usr/bin/env bash
echo ""    # zero requested packages
exit 0
EOF
  chmod +x "$STUB_BIN/jq"
  mkdir -p "$TEST_TMP/calls"
  run run_layered
  [ "$status" -eq 0 ]
  [ -f "$ZINSTALL_YUM_REPOS_D/docker-ce.repo" ]
  assert_called_with sudo \
    "install -m 0644 $ZINSTALL_REPOS_DIR/docker-ce.repo $ZINSTALL_YUM_REPOS_D/docker-ce.repo"
}

@test "run_layered does not re-copy repo when contents match" {
  cp "$ZINSTALL_REPOS_DIR/docker-ce.repo" "$ZINSTALL_YUM_REPOS_D/docker-ce.repo"
  cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/sudo.log"
if [[ "$1" == "install" ]]; then
  shift
  install "$@"
fi
exit 0
EOF
  chmod +x "$STUB_BIN/sudo"
  cat >"$STUB_BIN/rpm-ostree" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/rpm-ostree.log"
[[ "$1 $2" == "status --json" ]] && echo '{"deployments":[{"requested-packages":[]}]}'
exit 0
EOF
  chmod +x "$STUB_BIN/rpm-ostree"
  cat >"$STUB_BIN/jq" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_BIN/jq"
  mkdir -p "$TEST_TMP/calls"
  run run_layered
  [ "$status" -eq 0 ]
  if [[ -f "$TEST_TMP/calls/sudo.log" ]]; then
    ! grep -q "install -m 0644" "$TEST_TMP/calls/sudo.log"
  fi
}

@test "run_layered installs only the missing packages and sets REBOOT_NEEDED" {
  cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/sudo.log"
exit 0
EOF
  chmod +x "$STUB_BIN/sudo"
  cat >"$STUB_BIN/rpm-ostree" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/rpm-ostree.log"
[[ "$1 $2" == "status --json" ]] && echo '{}'
exit 0
EOF
  chmod +x "$STUB_BIN/rpm-ostree"
  cat >"$STUB_BIN/jq" <<'EOF'
#!/usr/bin/env bash
# pretend zsh is already layered; docker-ce missing
echo "zsh"
exit 0
EOF
  chmod +x "$STUB_BIN/jq"
  mkdir -p "$TEST_TMP/calls"
  REBOOT_NEEDED=0
  run_layered
  assert_called_with sudo \
    "rpm-ostree install --idempotent --allow-inactive docker-ce"
  [ "$REBOOT_NEEDED" -eq 1 ]
}

@test "run_layered with --prune uninstalls extras" {
  cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/sudo.log"
exit 0
EOF
  chmod +x "$STUB_BIN/sudo"
  cat >"$STUB_BIN/rpm-ostree" <<'EOF'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/rpm-ostree.log"
[[ "$1 $2" == "status --json" ]] && echo '{}'
exit 0
EOF
  chmod +x "$STUB_BIN/rpm-ostree"
  cat >"$STUB_BIN/jq" <<'EOF'
#!/usr/bin/env bash
echo "zsh"; echo "docker-ce"; echo "extra-pkg"
exit 0
EOF
  chmod +x "$STUB_BIN/jq"
  mkdir -p "$TEST_TMP/calls"
  PRUNE=1 run run_layered
  assert_called_with sudo "rpm-ostree uninstall extra-pkg"
}

@test "run_layered errors out when LockLayering=true (points at README)" {
  echo -e "[Daemon]\nLockLayering=true" >"$TEST_TMP/rpm-ostreed.conf"
  export ZINSTALL_RPM_OSTREED_CONF="$TEST_TMP/rpm-ostreed.conf"
  cat >"$STUB_BIN/rpm-ostree" <<'INNER'
#!/usr/bin/env bash
echo "$@" >>"$TEST_TMP/calls/rpm-ostree.log"
exit 0
INNER
  chmod +x "$STUB_BIN/rpm-ostree"
  mkdir -p "$TEST_TMP/calls"
  run run_layered
  [ "$status" -ne 0 ]
  [[ "$output" == *"LockLayering=true"* ]]
  [[ "$output" == *"README"* ]]
  if [[ -f "$TEST_TMP/calls/sudo.log" ]]; then
    ! grep -qE "rpm-ostree (install|uninstall)" "$TEST_TMP/calls/sudo.log"
  fi
}
