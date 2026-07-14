setup() {
  load 'helpers/mock-gh.bash'
  mock_gh_setup
}

teardown() {
  mock_gh_teardown
}

@test "mock_gh returns fixture content for exact command match" {
  echo '{"state":"success"}' > /tmp/fake-output.json
  mock_gh_set "pr view 42 --json state" 0 "/tmp/fake-output.json"

  run gh pr view 42 --json state

  [ "$status" -eq 0 ]
  [ "$output" = '{"state":"success"}' ]
}

@test "mock_gh returns non-zero exit code" {
  mock_gh_set "pr checks 42 --watch" 1 "/dev/null" "/dev/null"

  run gh pr checks 42 --watch

  [ "$status" -eq 1 ]
}

@test "mock_gh errors on unregistered command" {
  run gh pr checks 99 --watch

  [ "$status" -eq 1 ]
  [[ "$output" == *"MOCK_ERROR"* ]]
}

@test "mock_gh_teardown removes mock from PATH" {
  run which gh

  [[ "$output" == "$MOCK_GH_DIR/gh" ]]
}
