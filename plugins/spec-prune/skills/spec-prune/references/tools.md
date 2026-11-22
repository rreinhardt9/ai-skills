# Tools

Commands for gathering signals and checking safety. For Minitest
projects, [minitest.md](minitest.md) has the equivalents. Use what the project
already has. Don't add gems to the project just for an audit without asking
the user.

## rubocop-rspec, forced on

Teams often disable the cops that find stub-only and dead specs. `--only` runs
the named cops even when the config disables them, and doesn't change the
config:

```bash
bundle exec rubocop --only RSpec/SubjectStub,RSpec/MessageChain,RSpec/AnyInstance,RSpec/PendingWithoutReason,RSpec/RepeatedExample,RSpec/RepeatedDescription <paths...>
```

| Cop | Finds |
|---|---|
| `RSpec/SubjectStub` | stubbing the object under test |
| `RSpec/MessageChain` | `receive_message_chain`, which usually means a stub-only test |
| `RSpec/AnyInstance` | `allow_any_instance_of` |
| `RSpec/PendingWithoutReason` | skipped specs with no explanation |
| `RSpec/RepeatedExample`, `RSpec/RepeatedDescription` | copy-pasted examples and names |

`RSpec/ContextWording` and `RSpec/ExampleWording` help with naming, but they
are noisy. Treat their hits as prompts to look, not as findings.

`bundle exec rubocop --show-cops <Cop>` shows whether the project disables a
cop. That's worth mentioning in the report, since re-enabling a cop stops these
tests from coming back.

## Example inventory

```bash
bundle exec rspec --dry-run --format json --out inventory.json <paths...>
ruby scripts/inventory.rb inventory.json
```

A dry run loads the spec files without running examples, so it takes seconds.
The script lists examples per file and flags:

- pending (skipped) examples;
- duplicate full descriptions;
- generic names ("works", "is valid", "correct attributes", "renders
  successfully", "should");
- code words in names (`snake_case`, `CamelCase`, `#method`);
- stutter, where an example's own words repeat its parents' words.

For readable documentation output in flow order, use
`--format documentation --order defined` with `--dry-run`.

## Coverage diff

If the project uses SimpleCov, it writes `.resultset.json` into its coverage
directory after each run. Check `spec/rails_helper.rb`, `test/test_helper.rb`, or `.simplecov` for
the directory. Copy the file after the baseline run and again after the pruned run,
then compare them:

```bash
ruby scripts/coverage_diff.rb before.json after.json
```

The script prints files under `app/` and `lib/` with lines or branches covered
before and not after (lost), and the reverse (gained). It exits 1 when anything
was lost. Pass `--include app/,lib/,engines/` to change which paths count.

Notes:

- Run the same spec set both times. Coverage from other specs isn't part of
  this flow's audit.
- Branch coverage needs `enable_coverage :branch` in the SimpleCov config.
  Without it, the script compares lines only.
- Browser specs that run the server in the same process (Capybara with Puma,
  the default) count server-side lines. JavaScript isn't measured at all.
- If SimpleCov isn't installed, say the coverage check wasn't done. Don't
  install it without asking.

## test-prof

If `test-prof` is in the Gemfile:

| Env var | Shows |
|---|---|
| `FPROF=1` | factory calls and time; compare top-level counts before and after |
| `RD_PROF=1` | time spent in `let`, `let!`, and `before`, which is usually where browser specs' setup goes |
| `EVENT_PROF=sql.active_record` | examples and groups with the most database time |
| `TAG_PROF=type` | total time by spec type, a measure of the pyramid's shape across the suite |

`let_it_be` and `before_all` cut setup cost without deleting tests. Suggest
them in the report; they aren't part of a pruning pass.

## Mutation testing (optional)

Coverage shows which lines ran. Mutation testing shows whether any test fails
when the code is wrong, which is the only automated check of assertion
strength. `mutant` is free for open source projects and needs a license for
commercial ones. Ask before using it. It mutates Ruby only (not ERB or
JavaScript), and is too slow to run alongside browser specs, so scope it to
models, other plain Ruby objects, and request specs.

The manual version works anywhere. Break the line a merged or rewritten test
is meant to protect, run the test, see it fail, and restore the line. Check
`git status` afterwards to confirm the restore.

## Production usage

If the project runs Coverband in production, its report shows which code real
users exercise. That helps decide which flows matter, and finds orphaned code
behind dead specs. `traceroute` lists routes nothing calls. Both inform the
"Flagged, not changing" section, not deletions in the spec pass.

## CI history

If CI stores per-test results (for example from `rspec_junit_formatter`), a
test's failure history separates flaky tests from stable ones. Git history
finds change-detectors: spec files that change in almost every commit touching
their app code.
