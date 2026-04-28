#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/autostart.sh"
  mkdir -p "$TEST_TMP/packages"
  export ZINSTALL_AUTOSTART_LIST="$TEST_TMP/packages/autostart.list"
  mock_cmd systemctl 0 ""
}
teardown() { teardown_zinstall_env; }

@test "_autostart_slug derives slug from a bare command" {
  run _autostart_slug "flatpak run com.spotify.Client"
  [ "$status" -eq 0 ]
  [ "$output" = "flatpak" ]
}

@test "_autostart_slug uses explicit slug=cmd form" {
  run _autostart_slug "music=flatpak run com.spotify.Client"
  [ "$status" -eq 0 ]
  [ "$output" = "music" ]
}

@test "run_autostart writes a unit file per non-comment line" {
  cat >"$ZINSTALL_AUTOSTART_LIST" <<'EOF'
# comment
music=flatpak run com.spotify.Client
flatpak run com.github.tchx84.Flatseal
EOF
  run run_autostart
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/systemd/user/zinstall-music.service" ]
  [ -f "$HOME/.config/systemd/user/zinstall-flatpak.service" ]
  grep -q "ExecStart=flatpak run com.spotify.Client" \
    "$HOME/.config/systemd/user/zinstall-music.service"
}

@test "run_autostart skips rewrite when content unchanged (hash compare)" {
  echo "music=flatpak run com.spotify.Client" >"$ZINSTALL_AUTOSTART_LIST"
  run_autostart
  local first_mtime
  first_mtime=$(stat -c %Y "$HOME/.config/systemd/user/zinstall-music.service")
  sleep 1
  run_autostart
  local second_mtime
  second_mtime=$(stat -c %Y "$HOME/.config/systemd/user/zinstall-music.service")
  [ "$first_mtime" -eq "$second_mtime" ]
}

@test "run_autostart with --prune removes managed units no longer listed" {
  mkdir -p "$HOME/.config/systemd/user"
  : >"$HOME/.config/systemd/user/zinstall-stale.service"
  echo "music=flatpak run com.spotify.Client" >"$ZINSTALL_AUTOSTART_LIST"
  PRUNE=1 run run_autostart
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/systemd/user/zinstall-stale.service" ]
  [ -e "$HOME/.config/systemd/user/zinstall-music.service" ]
}

@test "run_autostart with --prune leaves user-authored units alone" {
  mkdir -p "$HOME/.config/systemd/user"
  : >"$HOME/.config/systemd/user/some-user.service"
  echo "" >"$ZINSTALL_AUTOSTART_LIST"
  PRUNE=1 run run_autostart
  [ -e "$HOME/.config/systemd/user/some-user.service" ]
}
