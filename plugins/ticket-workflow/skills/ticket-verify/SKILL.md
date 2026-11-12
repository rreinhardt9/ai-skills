---
name: ticket-verify
description: Check that an implementation matches its project-tracker ticket (all tasks done, every acceptance scenario covered by a passing test, design followed), report issues by severity, then optionally post the report, open the PR, and move the ticket to review. Use when the user says "ticket verify", or asks whether a ticket's work is complete or ready for review.
compatibility: Requires the gh CLI, signed in. The GitHub Projects backend needs the project scope; the Jira backend needs curl, jq, the jira CLI, and a JIRA_API_TOKEN environment variable.
---

# Verify

Checks the work against the ticket, and changes no code. The test suite is the
living spec, so the key question is whether every acceptance scenario has a
test that passes.

## 1. Gather evidence

1. Load the project config, backend, and template the way `ticket-propose`
   step 1 describes. Its `SKILL.md` and bundled files are in the sibling
   directory `../ticket-propose/`.
2. Read the ticket fresh, including its comments.
3. Collect the change with `git diff <default-branch>...HEAD` plus any
   uncommitted changes.

## 2. Check three things

**Completeness**
- Every task is checked off. Each unchecked task is CRITICAL.

**Correctness**
- For each scenario, find the test that exercises it and note its `file:line`.
  A scenario with no test is CRITICAL. A test that only loosely matches the
  scenario is a WARNING.
- Run the matched tests. A failing test is CRITICAL.
- Confirm the code actually delivers each requirement's behavior, not only that
  a test exists. A divergence is a WARNING.
- Anything listed under Out of scope that the change implements anyway is a
  WARNING.

**Coherence**
- The implementation follows the Design section's decisions. A contradiction is
  a WARNING. If there is no Design section, mark this not applicable.
- The code fits the project's conventions and passes the config's
  `apply_guidance` checks. Deviations are a SUGGESTION.

When you're unsure, choose the lower severity. Every issue needs a specific,
actionable recommendation, with a `file:line` where possible.

If you couldn't run a check (for example, the tests won't run), mark it
**Not verified** with the reason. Never count a skipped check as passing.

## 3. Report

```markdown
## Verification: <ticket title> (<ticket id>)

| Dimension    | Result                         |
|--------------|--------------------------------|
| Completeness | X/Y tasks                      |
| Correctness  | M/N scenarios covered, passing |
| Coherence    | Followed / Issues / N/A        |

### CRITICAL
### WARNING
### SUGGESTION

**Assessment:** <ready for review / N critical issues to fix / what wasn't verified>
```

## 4. Hand off

Show the report. If nothing is CRITICAL and every check ran, ask whether to do
any of the following, and do only what the user confirms:
- post the report as a ticket comment;
- commit, push, and open a PR that summarizes the change and links the ticket
  the way the backend describes;
- move the ticket to `in_review`.

If anything is CRITICAL, list what to fix. If the plan itself was wrong,
suggest revising the ticket with `ticket-propose`.
