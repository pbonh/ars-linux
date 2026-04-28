#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() { setup_zinstall_env; }
teardown() { teardown_zinstall_env; }

@test "install.sh --dry-run --only=brew runs only the brew install phase" {
  run bash "$ZINSTALL_ROOT/install.sh" --dry-run --only=brew --no-reboot-prompt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Phase 1 — Homebrew"* ]]
  [[ "$output" != *"Phase 2 — chezmoi"* ]]
  [[ "$output" != *"Phase 3 — Brewfile"* ]]
}

@test "install.sh --skip with all phases skips them all" {
  run bash "$ZINSTALL_ROOT/install.sh" --dry-run \
    --skip=system,layered,postinstall,distrobox,autostart,brewfile,chezmoi,brew \
    --no-reboot-prompt
  [ "$status" -eq 0 ]
  [[ "$output" != *"Phase 1 — Homebrew"* ]]
  [[ "$output" != *"Phase 6 — layered"* ]]
}

@test "install.sh errors on unknown phase name in --only" {
  run bash "$ZINSTALL_ROOT/install.sh" --dry-run --only=nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown phase"* ]]
}

@test "install.sh prints a summary section" {
  run bash "$ZINSTALL_ROOT/install.sh" --dry-run --only=brew --no-reboot-prompt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Summary"* ]]
}
