# Minitest

How each step changes when the project tests with Minitest: there's a `test/`
directory, no `spec/`, and no rspec in the Gemfile. The method is the same;
the commands and a few traps are different. Read this alongside the step it
applies to.

## Contents

- [Test levels](#test-levels)
- [Running tests](#running-tests)
- [Timings and parallel tests](#timings-and-parallel-tests)
- [Inventory and documentation output](#inventory-and-documentation-output)
- [Coverage with parallel workers](#coverage-with-parallel-workers)
- [rubocop-minitest, forced on](#rubocop-minitest-forced-on)
- [Stubs and mocks](#stubs-and-mocks)
- [Names](#names)
- [Fixtures](#fixtures)

## Test levels

For the behavior × level matrix in a Rails app:

| Folder | Level |
|---|---|
| `test/system` | Browser (`ActionDispatch::SystemTestCase`) |
| `test/controllers`, `test/integration` | Request: both are `ActionDispatch::IntegrationTest`, not isolated controller tests |
| `test/models`, `test/lib`, `test/mailers`, `test/jobs`, and the like | Unit |

Search `test/` instead of `spec/` when mapping the flow.

## Running tests

```bash
bin/rails test test/models/loan_test.rb test/system/returns_test.rb   # these files, system tests included
bin/rails test test/system/returns_test.rb:42                          # one test, by line
```

`bin/rails test` with no paths skips system tests, but it runs any path you
give it. `bin/rails test:system` ignores path arguments and always runs every
system test, so don't use it for a flow's files.

`-v` prints each test's name, result, and time. There's no `--profile`; sort
the `-v` output by time instead. Outside Rails, run a file with
`ruby -Itest <file> -v`.

## Timings and parallel tests

Rails apps usually call `parallelize(workers: :number_of_processors)` in
`test/test_helper.rb`. Rails only parallelizes when a run has more than 50
tests (`config.active_support.test_parallelization_threshold`). Below that,
the run is serial.

This skews before/after timings for a flow. Pruning can take the flow's test
count across the threshold, which changes how many processes start and, for
system tests, how many browsers boot. A flow that went from 56 to 46 tests
looked about twice as fast, mostly because 8 workers booting 8 browsers
became one process and one browser.

For comparable timings, run both the baseline and the verify step with
`PARALLEL_WORKERS=1`, which overrides the `workers:` argument:

```bash
PARALLEL_WORKERS=1 bin/rails test -v <paths...> > baseline-1.txt 2>&1
```

If you also time a normal (parallel) run, say whether the count crossed the
threshold. Per-test times from a parallel run include each worker's boot, so
don't read them as findings.

## Inventory and documentation output

Minitest has no dry run. This skill's `scripts/minitest_inventory.rb` stands
in for `rspec --dry-run`. It loads the test files without running them and
asks Minitest which tests it would run, through the same public API its
runner uses (`Minitest::Runnable.runnables` and `runnable_methods`).

```bash
bundle exec ruby -Itest <skill-dir>/scripts/minitest_inventory.rb \
  --out inventory-before.json --docs docs-before.txt <paths...>
ruby <skill-dir>/scripts/inventory.rb inventory-before.json
```

- `--out` writes JSON in the shape of RSpec's dry run, so `inventory.rb`
  works unchanged.
- `--docs` writes every test in file order with its line, which replaces
  `rspec --dry-run --format documentation --order defined`.
- It boots the app, as an RSpec dry run does. It needs Prism, which ships
  with Ruby 3.3+; older Rubies need the `prism` gem.

It also parses the files with Prism, independently of Minitest, so it can:

- report each name as written: `test "summary_kind is a quote"` rather than
  the method name, where spaces and underscores look alike;
- mark tests that call `skip` as pending without running them;
- warn when a `def test_` method is defined twice in one class. Ruby keeps
  only the last one, and the earlier test silently never runs. (Rails'
  `test "..."` raises on a duplicate name, but `def` doesn't.)

When the loaded list and the parsed list disagree, it warns, naming each
`file:line`. Tests from loops or shared modules show up as "defines tests the
source can't show", which is expected. A test written in the source that
Minitest won't run is worth a look.

If loading fails (a test file that does real work when required, or a future
Minitest that changes this API), use `--source-only`. It skips loading and
lists what the parse finds. It can't see tests generated in loops, inherited
from a parent class, or included from a module, so say so in the report.

If the project already uses `minitest-reporters`, its `SpecReporter` makes
the timed runs easier to read, and its JUnit output works for the CI history
in [tools.md](tools.md). Don't add it just for an audit.

## Coverage with parallel workers

SimpleCov must start before the app loads, at the top of
`test/test_helper.rb`. With parallel processes, each worker needs its own
command name, and must write its result when it finishes, or workers
overwrite each other and coverage comes out short:

```ruby
# Top of test/test_helper.rb: `COVERAGE=1 bin/rails test`
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
  end
end

# Inside ActiveSupport::TestCase, after `parallelize`
if ENV["COVERAGE"]
  parallelize_setup { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
  parallelize_teardown { |_worker| SimpleCov.result }
end
```

`coverage_diff.rb` merges every command name in `.resultset.json`, so the
per-worker results compare correctly. Keeping it opt-in with an environment
variable leaves the user's normal runs unchanged. As with any gem, ask before
adding it.

## rubocop-minitest, forced on

The cops that find dead and vacuous tests:

```bash
bundle exec rubocop --only Minitest/NonExecutableTestMethod,Minitest/NoAssertions,Minitest/UselessAssertion,Minitest/AssertWithExpectedArgument,Minitest/SkipWithoutReason,Minitest/UnreachableAssertion,Minitest/ReturnInTestMethod <paths...>
```

| Cop | Finds |
|---|---|
| `Minitest/NonExecutableTestMethod` | test methods that never run (dead) |
| `Minitest/NoAssertions` | tests with no assertion at all |
| `Minitest/UselessAssertion` | assertions that can't fail, such as `assert true` |
| `Minitest/AssertWithExpectedArgument` | `assert(actual, expected)` written where `assert_equal` was meant; the second argument is only a message, so it passes for any truthy value |
| `Minitest/SkipWithoutReason` | skipped tests with no explanation |
| `Minitest/UnreachableAssertion`, `Minitest/ReturnInTestMethod` | assertions that never run |

`Minitest/MultipleAssertions` matters for the plan rather than the audit; see
[Convention questions](findings.md#convention-questions).

## Stubs and mocks

There are no cops for stub-only tests, so search for them:

```bash
grep -rnE '\.stub\(|any_instance|\.stubs\(|\.expects\(|Minitest::Mock' <paths...>
```

`Object#stub` and `Minitest::Mock` are Minitest's own; `stubs`, `expects`, and
`any_instance` come from Mocha. A stub of the object under test, or a stub
whose value the test then asserts, is the stub-only finding.

## Names

Minitest doesn't nest names. A failure reads `LoansControllerTest#test_create_refuses_a_loan_from_another_member`,
so the flattened form is the class plus the test name. Rails convention leads
request test names with the action ("create refuses…", "index leaves out…"),
which does the job of RSpec's `describe`. Minitest::Spec's `describe` blocks
become class names joined with `::`.

Rails' generators write names like "should get new" and "should create
loan". The inventory flags them as generic; they usually state no rule.

## Fixtures

Minitest apps usually use fixtures instead of factories, so factory counts
(`FPROF`) don't apply. Tests that change a fixture record (`update!`) are fine,
since each test runs in a rolled-back transaction. Authorization gaps
("another member's loan is refused") need a second user and their records in
the fixtures. Check they exist before planning those tests, and add them if
not.
