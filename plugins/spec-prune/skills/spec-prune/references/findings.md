# Findings

Each kind of finding, how to spot it, and what to do about it. Examples use an
invented library app where members borrow and return books.

## Contents

- [Dead](#dead)
- [Vacuous](#vacuous)
- [Stub-only](#stub-only)
- [Implementation-coupled](#implementation-coupled)
- [Redundant](#redundant)
- [Misplaced too high](#misplaced-too-high)
- [Browser-only](#browser-only)
- [Copy assertions](#copy-assertions)
- [Regression](#regression)
- [Orphaned behavior](#orphaned-behavior)
- [Gaps](#gaps)
- [Misnamed](#misnamed)
- [Misorganized](#misorganized)
- [Convention questions](#convention-questions)

## Dead

Skipped examples (`xit`, `xscenario`, `xdescribe`, `skip`, `pending` with no
plan to fix). They appear as pending in every run and in the documentation
output, so the spec claims behavior nobody checks.

**Do:** find out why with `git log -S'xscenario' -- <file>`.
- The feature was removed: delete the spec. Also check whether the code it
  tested is now orphaned (views nothing renders, routes nothing calls), and
  flag that.
- The feature still exists: the skipped spec marks a gap. Restore it, or
  replace it with a test at the right level.

In Minitest, also look for:

- a `def test_` method defined twice in one class. Ruby keeps only the last
  definition, so the first test never runs and never shows as skipped.
  `minitest_inventory.rb` warns about these.
- test methods that don't start with `test_`, which Minitest never runs
  (`Minitest/NonExecutableTestMethod`).

If the replaced or misnamed test specifies a real behavior, it's a gap; if
it's an older copy of the test that replaced it, delete it.

## Vacuous

Tests that pass no matter what the app does, or that assert the framework
works.

- "Page loads" or "renders successfully" tests that only check the status.
- `it 'has a valid factory'`. Other specs using the factory already fail when
  it breaks; `FactoryBot.lint` is the dedicated check.
- Rails defaults: a required `belongs_to`, or `respond_to(:title)`.
- `be_a(Loan)` on a method whose whole job is to build a `Loan`.
- Tests of an icon class or a CSS class with no behavior behind it.

**Do:** delete. If a vacuous test is the only thing touching a page, the real
gap is a missing flow test, so note it.

**Judgment:** a validation test can be a real business rule ("a loan needs a
due date") rather than structure. Keep tests that state a rule; drop tests that
state a schema.

## Stub-only

Tests that stub a value and then assert the same value comes back. They pass no
matter what the code does.

```ruby
allow(Loan).to receive_message_chain(:where, :overdue, :count).and_return(3)
expect(desk.overdue_count).to eq(3)
```

Signs: `receive_message_chain`, `allow_any_instance_of`, stubbing the object
under test (`allow(subject)`, `allow(desk).to receive(:own_method)`), and
memoization tests. `rubocop --only RSpec/MessageChain,RSpec/AnyInstance,RSpec/SubjectStub`
finds most of them.

**Do:** if real records or a real collaborator can prove the behavior cheaply,
rewrite the test that way. If another test already proves it, delete this one.
If this was the only coverage of real behavior, put the replacement in the same
commit as the deletion.

## Implementation-coupled

Tests that break on refactors without catching bugs, sometimes called
change-detectors.

- Calling private methods with `send`.
- Asserting messages an object sends to itself
  (`expect(handler).to have_received(:render_row)`).
- Testing outgoing queries, meaning stubbing a collaborator's return value and
  asserting it was asked for.
- Asserting exact SQL, exact call order, or internal state.

**Do:** rewrite against the public interface (the return value, a public side
effect, an outgoing command sent to a collaborator), or delete when a
request-level test already proves the behavior. Sandi Metz's rules apply: test
incoming queries by their result, incoming commands by their public side
effects, and outgoing commands by the message sent.

## Redundant

The same behavior asserted at more than one level.

Overlap is not automatically redundant. Here's the distinction that matters:

- **Wiring check plus variants (keep both).** One request spec proves the
  pieces connect ("returning another member's loan is refused"). Unit specs
  cover the variants (another member, another branch, a mix of valid and
  foreign IDs). This is the shape you want.
- **Redundant (keep the lowest).** The browser spec, the request spec, and the
  unit spec all walk through the same variants. Keep the cheapest test that can
  prove each variant, and keep one higher test only if it proves wiring nothing
  else proves.

When two browser scenarios go through the same UI branch with different data,
merge them into one scenario whose data covers both conditions. For example,
one loan already returned and one on hold both make "nothing to return" true.
The merged test must still fail if either condition breaks. Check that by
reasoning, or by breaking the code on purpose.

## Misplaced too high

Edge cases proven through the browser when a request or unit test could prove
them: pluralization, count arithmetic, validation variants, permission
variants.

**Do:** move the case down, or delete it when a lower test already covers it.
Keep the browser for flows a user goes through and for behavior only a browser
can show.

## Browser-only

Behavior that only exists in the browser: JavaScript toggles, steps that show
and hide fields, previews that update as you choose options. It can't move to a
request spec.

**Do:** check for a JavaScript test runner.
- One exists: move the toggle logic into JavaScript unit tests and keep one
  browser journey.
- None exists: group scenarios that each boot a browser to click one toggle
  into a few journeys, where each journey walks one part of the UI and
  asserts as it goes. Tell the user a JavaScript test layer is the longer-term
  fix.

## Copy assertions

Exact marketing or help text in assertions ("Returning on time keeps fines
low and shelves full."). They break when the wording changes and catch no bugs.

**Do:** assert on the behavior instead, such as the warning appearing, the
count, or a recommendation badge. Keep assertions on text that carries data
("2 books are overdue") or that's legally required.

## Regression

A test added to stop a specific bug from coming back. You'll often find its
commit message or ticket in `git log -L` or `git blame`.

**Do:** keep it, and name it after the rule it protects rather than the bug.
"A second book returned from the same page can still be rated", not "fixes
rating radio buttons after second return".

## Orphaned behavior

A test that specifies behavior no client uses any more. Examples: a parameter
only a removed form sent, or an endpoint nothing calls.

**Do:** flag it, don't change it. Deleting the test means deciding to delete
the code, and that belongs in a code change, not a spec pass.

## Gaps

Rows in the matrix with no test, or a flow branch only covered by unit tests.

- A branch of the flow that nothing submits end to end. For example, the form
  offers three answers, but only two are ever posted in a request spec.
- A user-visible message or warning that no request or browser test checks.
- Behavior whose only test was a stub-only or vacuous one you're deleting.

**Do:** add the cheapest test that proves the wiring, usually a request spec.
Add a browser scenario only for a main happy path with no browser coverage.

## Misnamed

The name is the specification. Good names state the rule in the domain's
language and read as a sentence when RSpec joins them to their parents.

| Smell | Example | Better |
|---|---|---|
| Says nothing | `it 'works'`, `it 'creates a record with the correct attributes'` | `it 'records the fine and the date it was paid'` |
| Code words | `context 'when overdue_flag is nil'`, `describe '#call'` | `context 'when the loan was never marked overdue'` |
| History words | `it 'saves the rating, as the old form did'` | `it 'saves a rating sent with the return'` |
| Stutter | `context 'renders the row'` → `it 'renders the row'` | one level, named for the outcome |
| Structure words | `it 'is valid'`, `it 'returns true'` | `it 'accepts a return without a condition note'` |
| Doesn't join | `feature 'return a book'` + `scenario 'returning charges a fine'` | the joined form reads as one sentence |

Grammar that joins well:

- `describe` names the subject: a class, an endpoint, or a flow.
- `context` names the situation, starting with "when", "with", or "without".
- `it` or `scenario` is a predicate of the subject: "charges a fine",
  "refuses a loan from another member".

Several examples with identical names usually hide one rule they share. Name
that rule.

## Misorganized

- The spec follows the code's structure (one `describe` per method) when the
  readers need the flow's structure.
- Deep `context` nesting that has to be read bottom-up.
- Helpers defined between scenarios.
- Scenarios in random order instead of following the flow.

**Do:** order browser scenarios along the flow map, keep nesting shallow, and
put helpers at the top. Unit specs can keep `describe '#method'` grouping when
the method is the public interface, but the `it` names still state rules.

## Convention questions

Tests that conflict with the team's or user's own testing rules without being
clearly wrong. One example: asserting that a command method returns `self`,
which is the very return value command/query separation says nobody should
depend on.

**Do:** flag for discussion. Don't change these on your own judgment.

**Assertion-count limits.** Merging tests raises each merged test's number of
assertions, and a browser journey that asserts as it goes has several by
design. Before you propose merges, check whether the project enforces a limit
(`Minitest/MultipleAssertions`, `RSpec/MultipleExpectations`, or
`RSpec/ExampleLength`) with `bundle exec rubocop --show-cops <Cop>`, and how
many existing tests already break it. If merges would break it, put the
question in the plan: exclude browser tests from the cop, raise its limit,
disable it inline, or keep those tests separate. Don't find out at commit
time.
