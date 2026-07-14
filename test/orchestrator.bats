setup() {
  load 'helpers/mock-gh.bash'
  mock_gh_setup
}

teardown() {
  mock_gh_teardown
}

@test "orchestrator exits 0 when CI passes and PR approved" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-pass.json"
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-approved.json"

  run ./scripts/orchestrator.sh 42

  [ "$status" -eq 0 ]
  [[ "$output" == *"[ci:pass]"* ]]
  [[ "$output" == *"[review:approved]"* ]]
}

@test "orchestrator exits 1 when CI fails" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-fail.json"
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-approved.json"

  run ./scripts/orchestrator.sh 42

  [ "$status" -eq 1 ]
  [[ "$output" == *"[ci:fail]"* ]]
}

@test "orchestrator exits 2 when changes requested" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-pass.json"
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-changes-requested.json"

  run ./scripts/orchestrator.sh 42

  [ "$status" -eq 2 ]
  [[ "$output" == *"[review:changes_requested]"* ]]
}

@test "orchestrator exits 3 when CI pending" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 8 ""
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-pending.json"

  run ./scripts/orchestrator.sh 42

  [ "$status" -eq 3 ]
  [[ "$output" == *"[waiting]"* ]]
}

@test "orchestrator tracks round count with --round flag" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-fail.json"
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-approved.json"

  run ./scripts/orchestrator.sh 42 --round 2

  [[ "$output" == *"round=2"* ]]
}

@test "orchestrator exits 4 when max rounds exhausted" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-fail.json"
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-approved.json"

  run ./scripts/orchestrator.sh 42 --round 4 --max-rounds 3

  [ "$status" -eq 4 ]
  [[ "$output" == *"[escalate]"* ]]
}

@test "orchestrator passes --repo to sub-scripts" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link -R owner/repo" 0 "test/fixtures/checks-pass.json"
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews -R owner/repo" 0 "test/fixtures/review-approved.json"

  run ./scripts/orchestrator.sh 42 --repo owner/repo

  [ "$status" -eq 0 ]
}

@test "orchestrator exits 0 with [terminal] when PR merged" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-pass.json"
  mock_gh_set "pr view 42 --json state" 0 "test/fixtures/pr-merged.json"

  run ./scripts/orchestrator.sh 42

  [ "$status" -eq 0 ]
  [[ "$output" == *"[terminal]"* ]]
}

@test "orchestrator skips review check when PR not open" {
  mock_gh_set "pr checks 42 --json name,state,bucket,link" 0 "test/fixtures/checks-pass.json"
  mock_gh_set "pr view 42 --json state" 0 "test/fixtures/pr-merged.json"

  run ./scripts/orchestrator.sh 42

  # Should not call review poller — PR is merged
  [[ "$output" != *"[review:"* ]]
  [[ "$output" == *"[terminal]"* ]]
}
