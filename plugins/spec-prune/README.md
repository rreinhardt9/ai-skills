# spec-prune

Prunes a Ruby test suite one user flow at a time, so the tests read as the
app's specification and still prove it.

Suites grow as tests are written to drive development. Some of those tests end
up specifying nothing: a page-loads check, a valid-factory test, a stub that
asserts its own return value. Others specify the same behavior at three levels,
or prove an edge case through a slow browser test that a unit test could prove
in milliseconds. Coverage numbers don't show any of this, because a line that
three tests run looks the same as a line one test runs.

The skill audits one flow, such as "return a book" or "sign up", across every
level of the test pyramid. It then proposes a plan, waits for your approval,
applies the changes in reviewable commits, and checks that nothing was lost.

- **Every behavior is asserted once, at the cheapest level that can prove it,
  under a name that reads as a requirement.** That's the goal of each pass.
- **Pruning isn't deleting.** Every removal is justified: either the test never
  specified behavior, or the behavior is still specified at a named
  `file:line`. Gaps are findings too, and get new tests.
- **You hold the gate.** The agent maps and audits, then stops with a plan. It
  changes nothing until you approve, works on a new branch, and never pushes.
- **Checked, not assumed.** Before-and-after runs, a coverage diff by line and
  branch, and the documentation output show what changed. Anything it couldn't
  check is reported as not verified.

```
pick a flow ──> map ──> baseline ──> signals ──> audit ──> plan
                                                              │
                                       [you review and approve]
                                                              │
                    report <── verify <── commits by kind of finding
```

## Skills

| Skill | When to use it | What it does |
|---|---|---|
| `spec-prune` | Cleaning up, trimming, or speeding up a flow's tests, or checking whether tests are worth keeping | Maps one flow by its routes and code, takes a baseline, builds a behavior × level matrix, and classifies every test (dead, vacuous, stub-only, redundant, misplaced, misnamed, gap, and more). After you approve the plan, it commits the changes by kind of finding, then reruns, diffs coverage, and reports. |

```bash
gh skill install rreinhardt9/ai-skills spec-prune --agent claude-code --scope user
```

See the [main README](../../README.md#installation) for the other install paths.

## Requirements

- A Ruby project tested with RSpec or Minitest, plus git and bundler.
- Optional, used when the project already has them: SimpleCov (for the
  coverage diff, ideally with branch coverage on), rubocop-rspec or
  rubocop-minitest, and test-prof. The skill asks before adding any gem.
- The Minitest inventory needs Prism, which ships with Ruby 3.3+. Older Rubies
  need the `prism` gem.

There's no setup or configuration.

## Usage

```
/spec-prune returning a book       # audit one flow; the agent stops with a plan
   ... review the plan, adjust it, approve ...
                                   # the agent commits on a branch, verifies, and reports
```

You can also just describe what you want ("these checkout specs are slow and
repetitive, can we trim them?"), and the agent picks the skill. Pick a flow a
user goes through rather than a file: duplication across levels and gaps only
show up across the whole flow. When installed as a Claude Code plugin, the
slash command is namespaced: `/spec-prune:spec-prune`.

## Layout

```
skills/
  spec-prune/
    SKILL.md                    the workflow, with the approval gate at step 6
    references/
      findings.md               each kind of finding, how to spot it, what to do
      tools.md                  rubocop --only, coverage, test-prof, mutation testing, CI history
      minitest.md               how each step changes for Minitest
    scripts/
      inventory.rb              flags pending, duplicate, generic, code-word, and stuttering test names
      minitest_inventory.rb     lists Minitest tests without running them, as RSpec dry-run JSON
      coverage_diff.rb          compares two SimpleCov resultsets by line and branch; exits 1 on loss
```

## Gotchas

- **Projects often disable the cops that find these tests.** `RSpec/SubjectStub`,
  `RSpec/MessageChain`, and `RSpec/AnyInstance` are commonly turned off. The
  skill runs them with `rubocop --only`, which overrides the config without
  changing it.
- **Timings are noisy.** The first browser test in a run pays for booting the
  server and browser, and random ordering moves that cost around. In Minitest,
  Rails only parallelizes above 50 tests, so a flow that crosses that line
  looks faster or slower for reasons unrelated to the tests. The skill takes
  two runs on each side, serial for Minitest, and reports speed gains plainly.
  They're usually modest; readability and signal are the main payoff.
- **Coverage shows which lines ran, not what was asserted.** A clean coverage
  diff can't prove a merged scenario still catches everything its parts did,
  or that JavaScript behavior is still covered. For merges that matter, the
  skill breaks the protected code on purpose and checks that the test fails.
