setup() {
  load 'helpers/mock-gh.bash'
  mock_gh_setup
}

teardown() {
  mock_gh_teardown
}

@test "review-poller emits [review:approved] when PR is approved" {
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-approved.json"

  run ./scripts/review-poller.sh 42

  [ "$status" -eq 0 ]
  [[ "$output" == *"[review:approved]"* ]]
}

@test "review-poller emits [review:changes_requested] with reviewer and body" {
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-changes-requested.json"

  run ./scripts/review-poller.sh 42

  [ "$status" -eq 1 ]
  [[ "$output" == *"[review:changes_requested]"* ]]
  [[ "$output" == *"author=reviewer1"* ]]
  [[ "$output" == *"body=Please rename the variable"* ]]
}

@test "review-poller emits [review:pending] when review required" {
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-pending.json"

  run ./scripts/review-poller.sh 42

  [ "$status" -eq 2 ]
  [[ "$output" == *"[review:pending]"* ]]
}

@test "review-poller emits [review:commented] on comment-only review" {
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews" 0 "test/fixtures/review-commented.json"

  run ./scripts/review-poller.sh 42

  [ "$status" -eq 2 ]
  [[ "$output" == *"[review:commented]"* ]]
}

@test "review-poller accepts --repo flag" {
  mock_gh_set "pr view 42 --json reviewDecision,latestReviews -R owner/repo" 0 "test/fixtures/review-pending.json"

  run ./scripts/review-poller.sh 42 --repo owner/repo

  [ "$status" -eq 2 ]
}
