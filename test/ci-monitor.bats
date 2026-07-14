setup() {
  load 'helpers/mock-gh.bash'
  mock_gh_setup
}

teardown() {
  mock_gh_teardown
}

@test "ci-monitor exits 0 with [ci:pass] when all checks pass" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-pass.json"

  run ./scripts/ci-monitor.sh 42

  [ "$status" -eq 99 ]
  [[ "$output" == *"[ci:pass]"* ]]
}

@test "ci-monitor exits 1 with [ci:fail] when any check fails" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-fail.json"

  run ./scripts/ci-monitor.sh 42

  [ "$status" -eq 1 ]
  [[ "$output" == *"[ci:fail]"* ]]
  [[ "$output" == *"name=test"* ]]
}

@test "ci-monitor exits 2 with [ci:pending] when checks still running" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 8 ""

  run ./scripts/ci-monitor.sh 42

  [ "$status" -eq 2 ]
  [[ "$output" == *"[ci:pending]"* ]]
}

@test "ci-monitor accepts --repo flag" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link -R owner/repo" 0 "test/fixtures/checks-pass.json"

  run ./scripts/ci-monitor.sh 42 --repo owner/repo

  [ "$status" -eq 0 ]
}

@test "ci-monitor lists failing checks" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-fail.json"

  run ./scripts/ci-monitor.sh 42

  [[ "$output" == *"name=test"* ]]
  [[ "$output" == *"state=fail"* ]]
}
