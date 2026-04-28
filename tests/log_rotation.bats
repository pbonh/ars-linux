#!/usr/bin/env bats

load helpers/setup
load helpers/mocks

setup() { setup_zinstall_env; source "$ZINSTALL_ROOT/lib/log.sh"; }
teardown() { teardown_zinstall_env; }

@test "log::start_run creates a timestamped run log under \$HOME/.cache/zinstall" {
  log::start_run
  [ -d "$HOME/.cache/zinstall" ]
  shopt -s nullglob
  local logs=("$HOME"/.cache/zinstall/run-*.log)
  [ "${#logs[@]}" -eq 1 ]
}

@test "log::start_run prunes log files older than 30 days" {
  mkdir -p "$HOME/.cache/zinstall"
  local old="$HOME/.cache/zinstall/run-old.log"
  : >"$old"
  touch -d '40 days ago' "$old"
  log::start_run
  [ ! -e "$old" ]
}

@test "log::start_run keeps log files newer than 30 days" {
  mkdir -p "$HOME/.cache/zinstall"
  local recent="$HOME/.cache/zinstall/run-recent.log"
  : >"$recent"
  touch -d '5 days ago' "$recent"
  log::start_run
  [ -e "$recent" ]
}

@test "_retry succeeds on first try without sleeping" {
  start=$(date +%s)
  run _retry true
  end=$(date +%s)
  [ "$status" -eq 0 ]
  [ $((end - start)) -lt 1 ]
}

@test "_retry retries exactly three times before giving up" {
  mock_cmd flaky 1
  # Stub sleep to avoid actually waiting during the test.
  mock_cmd sleep 0
  run _retry flaky
  [ "$status" -ne 0 ]
  local count
  count=$(wc -l <"$TEST_TMP/calls/flaky.log")
  [ "$count" -eq 3 ]
}

@test "_retry honors DRY_RUN" {
  DRY_RUN=1 run _retry false
  [ "$status" -eq 0 ]
}
