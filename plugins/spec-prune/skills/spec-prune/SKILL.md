---
name: spec-prune
description: Audit and prune an RSpec or Minitest test suite one user flow at a time, so the specs read as the app's specification and still prove it. Finds dead, vacuous, stub-only, redundant, and misplaced tests, pushes edge cases down the test pyramid, renames examples in domain language, and fills gaps, then checks nothing was lost with profiling and a coverage diff. Use when the user says "spec prune", or wants to clean up, trim, slim down, speed up, or de-duplicate specs, tests, or feature and system tests, asks whether tests are redundant or worth keeping, or wants the test suite to read like documentation.
compatibility: Requires a Ruby project tested with RSpec or Minitest, plus git and bundler. Uses SimpleCov, rubocop-rspec or rubocop-minitest, and test-prof when the project has them. The Minitest inventory needs Prism (Ruby 3.3+, or the prism gem).
license: MIT
---

# Spec prune

The test suite is the app's living specification: documentation of what the
app does that can also be run to prove it. Over time it collects tests that
don't specify anything, tests that specify the same thing three times, and slow
browser tests for edge cases a unit test could prove. Pruning keeps it accurate
and readable.

The goal: **every behavior in the flow is asserted once, at the cheapest level
that can prove it, under a name that reads as a requirement.**

Pruning is not deleting. Every removal needs one of two justifications:

1. **This was never behavior.** It tests structure, the framework, its own
   stubs, or implementation details.
2. **This behavior is still specified at `file:line`.** It's a duplicate, and
   that's the test that survives.

A test that fits neither stays. Looking for gaps is part of the job too: a user
flow with no end-to-end test is as much a finding as a redundant test.

Work one flow at a time, never file by file. Reading one file in isolation
makes every spec look reasonable. Duplication across levels, gaps, and dead
specs only show up when you lay out the whole flow.

**Minitest projects** (a `test/` directory and no rspec) follow the same steps
with different commands. Read [references/minitest.md](references/minitest.md)
at step 1; the steps below point to the parts that change. "Spec" and
"example" here mean any test.

## 1. Pick the flow and prepare

1. **Agree on one flow** with the user, phrased as something a user does:
   "close a job", "return a book", "sign up". If they haven't named one,
   suggest a few. The largest or slowest feature specs are good candidates
   (`find spec/features spec/system test/system -name '*_spec.rb' -o -name '*_test.rb' | xargs wc -l | sort -n | tail`).
2. **Check the working tree.** Tracked changes must be committed or stashed
   first. Untracked files are fine, but remember they exist: you'll stage only
   paths you changed, never `git add -A` or `git add spec`.
3. **Create a branch from the code being audited.** That's usually the current
   branch. If the current branch has unmerged work on this flow, base on it
   (the specs you audit only exist there) and say so. Never push.
4. **Learn how the project runs tests.** Read `CLAUDE.md`, `AGENTS.md`,
   `.rspec`, and `spec/rails_helper.rb` (for Minitest, `test/test_helper.rb`
   and `test/application_system_test_case.rb`, and note whether it calls
   `parallelize`). Note whether SimpleCov is set up
   (and where it writes `.resultset.json`), whether test-prof is installed,
   and whether there's a JavaScript test runner (`package.json` scripts and
   devDependencies such as jest or vitest). That last one decides where
   browser-only behavior can move to.

## 2. Map the flow

Find every spec that touches the flow **by its routes and code, not by file
names**. A file-name search misses specs for shared endpoints, such as a
generic "resources" controller that renders the flow's drawer.

1. List the flow's routes (`bin/rails routes -g <keyword>`) and the
   controllers, models, and other objects behind them.
2. Search `spec/` (or `test/`) for each route's path helper, each controller and model class,
   and the flow's key UI text. Include specs for shared endpoints the flow
   calls into.
3. Read every file you found, in full.
4. Write the **flow map**: the steps a user goes through, in order, with each
   branch they can take. This becomes the table of contents the specs should
   follow.

## 3. Take a baseline

Capture everything you'll compare against in step 8 now, while the original
specs are still in place. Save the files outside the repo, such as in a temp
directory, so they never end up in a commit.

Pass spec paths as separate arguments. In zsh, an unquoted `$FILES` variable
stays one word, so use a small script or write the paths out.

For Minitest, the run, documentation, and inventory commands are in
[references/minitest.md](references/minitest.md). Time both runs with
`PARALLEL_WORKERS=1`: Rails only parallelizes above 50 tests, and a flow
whose count crosses that line during pruning looks faster or slower for
reasons that have nothing to do with the tests.

1. **Run the flow's whole spec set twice:**
   ```bash
   bundle exec rspec --format documentation --profile 25 <paths...> > baseline-1.txt 2>&1
   ```
   Add `FPROF=1` if test-prof is installed, for factory counts. Record
   examples, pending, failures, wall time, and per-group times.
2. **Copy SimpleCov's `.resultset.json`** after a run, if the project has one.
   That's the "before" for the coverage diff.
3. **Save the documentation output in file order**, which is much easier to
   read than the randomized run output:
   ```bash
   bundle exec rspec --dry-run --format documentation --order defined --out docs-before.txt <paths...>
   ```
4. **Save the example inventory:**
   ```bash
   bundle exec rspec --dry-run --format json --out inventory-before.json <paths...>
   ```

Timings are noisy. The first browser test in a run pays for booting the
server, the browser, and assets, often 15–40 seconds, and random ordering
moves that cost to a different example each time. Don't read the top of the
slowest-examples list as a finding until you've seen it in both runs.

## 4. Gather signals

These make the audit faster and catch things reading misses. Details and
commands are in [references/tools.md](references/tools.md).

- **rubocop-rspec with `--only`.** Projects often disable `RSpec/SubjectStub`,
  `RSpec/MessageChain`, `RSpec/AnyInstance`, and `RSpec/PendingWithoutReason`.
  `--only` runs them anyway, without touching the config, and they find most
  stub-only and dead specs mechanically.
- **rubocop-minitest with `--only`**, for Minitest projects. The cops and a
  grep for stubs are in [references/minitest.md](references/minitest.md).
- **The example inventory.** Run this skill's `scripts/inventory.rb` on the
  JSON saved in step 3 (for Minitest, the JSON from `scripts/minitest_inventory.rb`): `ruby <skill-dir>/scripts/inventory.rb inventory-before.json`.
  It lists every example by file and flags pending examples, duplicate names,
  generic names, code words, and names that stutter once flattened.
- **Git history for skipped specs.** `git log -S'xit' -- <file>` (or
  `xscenario`, `xdescribe`, `skip`) tells you why. Usually the feature was
  removed and the spec was skipped instead of deleted.

## 5. Audit

Read [references/findings.md](references/findings.md) before you start. It
defines each kind of finding, what to do about it, and the judgment calls.

1. **Build the behavior × level matrix.** One row per behavior the flow
   specifies. Columns for browser (feature/system), request, and unit specs.
   Each cell holds `file:line` for the tests that assert it.

   | Behavior | Browser | Request | Unit |
   |---|---|---|---|
   | Overdue loans charge a fine on return | returns_spec:40 | loans_request:55 | fine_spec:12, loan_spec:88 |
   | Returning another member's loan is refused | — | loans_request:20 | loan_spec:30, :41, :52 |
   | Renewing a loan already renewed twice | — | — | — |

   Rows tested at several levels are redundancy candidates. Rows with one
   wiring test above and variants below are the right shape. Empty rows are
   gaps.
2. **Classify every example** using the findings reference. Give each one an
   action (keep, delete, merge, move down, rename, rewrite) and a
   justification. For a deletion, the justification names its surviving test,
   or says why the test never specified behavior.
3. **Check names in their flattened form.** Failure messages, `--profile`, and
   CI join every parent description into one line. A name that reads well in
   the nested documentation output can still read badly when joined.
4. **Separate code questions from spec questions.** Sometimes a test specifies
   behavior no client uses any more, such as a parameter only a removed UI sent.
   Deleting the test means deleting the code too, so flag it for the user rather
   than deciding during a spec pass.

## 6. Present the plan, then stop

Present the plan in this shape:

```markdown
## Spec prune plan: <flow>

**Flow map:** <the steps, briefly>

<the behavior × level matrix>

### Changes
Grouped by kind of finding. Each item: file:line, action, justification.

### Gaps to fill
### Flagged, not changing
Code questions, convention questions, and anything outside the flow.

**Expected result:** about N → M examples, browser scenarios X → Y.
```

**Wait for the user to approve before changing anything.** They know which
flows matter to the business and which behaviors are intentional, which you
can't tell from the code. Adjust the plan with their feedback.

## 7. Apply in commits by kind of finding

Make one commit per kind of finding, in this order, so each one is easy to
review and the history explains itself:

1. Dead specs.
2. Stub-only, vacuous, and implementation-coupled specs. When one of these was
   the only coverage of a real behavior, add its replacement in the same
   commit, so coverage never drops between commits.
3. Redundant and misplaced specs: delete, merge, move down, and group
   browser-only scenarios into journeys.
4. Renames and reorganization.
5. Gap-filling specs.

Run each new gap-filling test against the unchanged code before anything
else. It should pass; if it fails, the test is wrong, not the app. Then break
the code it protects, see it fail, and restore the code.

Before each commit, run the specs you changed and rubocop on the changed files.
Stage the exact paths. Each commit message says why: what kind of finding it
fixes and where the remaining coverage lives. Follow the project's and the
user's commit conventions.

## 8. Verify

Use the same spec paths as the baseline, minus any files you deleted (RSpec
and `bin/rails test` stop with a load error on a missing path). Run the same
way as the baseline, including `PARALLEL_WORKERS=1` for Minitest.

1. **Run the flow's spec set twice again**, the same way as the baseline, and
   save the outputs.
2. **Diff the coverage.** Copy the new `.resultset.json`, then run this from
   the project root:
   `ruby <skill-dir>/scripts/coverage_diff.rb coverage-before.json coverage-after.json`.
   Every line or branch that lost coverage needs an explanation, or a test to
   restore it. Gained coverage usually comes from tests that replaced stub-only
   ones.
3. **Treat new failures as findings.** If a merged or rewritten scenario
   fails even once, report it with the failure output, and say whether the
   original scenario has the same weakness.
4. **Compare the output.** Save `docs-after.txt` and `inventory-after.json` the
   same way as in step 3. Diff the documentation against `docs-before.txt`,
   and run the inventory script on both JSON files: the flags you meant to fix
   should be gone. Also look at the flattened names in the `--profile` output
   (for Minitest, the `-v` output).

Coverage shows which lines ran, not what was asserted. It can't prove a merged
scenario still catches everything its parts did, or that browser-only
JavaScript behavior is still covered. When a merge matters, break the code it
protects on purpose, run the scenario, see it fail, and restore the code.

## 9. Report

```markdown
## Spec prune: <flow>

| | Before | After |
|---|---|---|
| Examples | N (P pending) | M (Q pending) |
| Wall time (2 runs) | a / b | c / d |
| Browser spec time | ... | ... |
| Coverage lost | — | none / list |

### Commits
### What changed in the output
A few before/after lines from the documentation and profile output.

### Flagged, not changed
### Not verified
Anything you couldn't check, and why. Never count a skipped check as passing.
```

Speed gains are usually modest: fixed startup cost doesn't shrink, and merged
scenarios run longer. Say so plainly. The main payoffs are specs that read as
the app's specification and fewer tests that can't fail.
