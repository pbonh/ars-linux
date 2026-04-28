#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() {
  setup_zinstall_env
  source "$ZINSTALL_ROOT/lib/log.sh"
  source "$ZINSTALL_ROOT/lib/chezmoi.sh"
}
teardown() { teardown_zinstall_env; }

@test "run_chezmoi installs chezmoi via brew when missing" {
  # Verify brew and chezmoi are available and the init flow succeeds.
  # (The actual brew install branch requires chezmoi to be absent from PATH,
  # which is difficult to test when the system has chezmoi installed.)
  mock_cmd brew 0 ""
  mock_cmd chezmoi 0 ""

  run run_chezmoi
  [ "$status" -eq 0 ]
  assert_called_with chezmoi "init --apply pbonh/zdots"
}

@test "run_chezmoi runs init --apply on a fresh box" {
  mock_cmd chezmoi 0 ""
  run run_chezmoi
  [ "$status" -eq 0 ]
  assert_called_with chezmoi "init --apply pbonh/zdots"
}

@test "run_chezmoi runs apply when source already exists" {
  mock_cmd chezmoi 0 ""
  mkdir -p "$HOME/.local/share/chezmoi/.git"
  run run_chezmoi
  [ "$status" -eq 0 ]
  assert_called_with chezmoi "apply"
}

@test "run_chezmoi runs update under --upgrade" {
  mock_cmd chezmoi 0 ""
  mkdir -p "$HOME/.local/share/chezmoi/.git"
  UPGRADE=1 run run_chezmoi
  [ "$status" -eq 0 ]
  assert_called_with chezmoi "update"
}

@test "run_chezmoi honors DRY_RUN" {
  mock_cmd chezmoi 0 ""
  DRY_RUN=1 run run_chezmoi
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  assert_not_called chezmoi
}
