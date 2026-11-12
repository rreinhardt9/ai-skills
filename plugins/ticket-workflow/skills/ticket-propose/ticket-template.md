# Ticket template

A ticket body has these `##` sections, in this order, with these exact headings.
Skills find a section by its heading, so never rename one. Omit `## Design` when
it isn't needed; every other section is required.

```markdown
## Why

## What changes

## Out of scope

## Acceptance criteria

### Requirement: <name>
<one behavior, stated with SHALL/MUST>

#### Scenario: <name>
- **WHEN** <trigger>
- **THEN** <observable outcome>

## Design

## Tasks

### 1. <group name>
- [ ] 1.1 <task> (verify: <test, command, or observable result>)
- [ ] 1.2 <task> (verify: ...)
```

## Writing each section

**Why**: One or two sentences on the problem or opportunity, and why now.

**What changes**: A bullet list of new, changed, or removed behavior. Mark
breaking changes **BREAKING**. Focus on what and why, not how.

**Out of scope**: What a reader might assume is included but isn't. Write
"Nothing notable" rather than inventing items.

**Acceptance criteria**: A contract for behavior, not a plan for implementing it.
These become the outside-in tests, and the test suite is the living spec, so
write each scenario as something a system/feature or integration/request test
can check.

- Describe observable behavior: what users or downstream systems see, the inputs
  and outputs, error cases, and external constraints such as security or
  compatibility.
- Leave out class and method names, library choices, and step-by-step detail.
  Test: if the implementation could change without changing visible behavior,
  the detail belongs in Design.
- State one behavior per requirement. Every requirement has at least one
  scenario, and every scenario has a WHEN (or GIVEN) and a THEN.
- Put edge cases in their own scenarios, not in the requirement's prose.
- For a change with no visible behavior change (a refactor, tooling), write one
  requirement: "Existing behavior SHALL be unchanged", with a scenario saying the
  existing suite passes unmodified. Don't invent requirements to fill the
  section.

**Design**: Include it only for one of these:
- a cross-cutting change or a new pattern;
- a new dependency or a significant change to the data model;
- complexity around security, performance, or migration;
- ambiguity that needs decisions before coding.

Cover the domain objects and the messages between them ("who would I send this
message to?"), key decisions with the alternatives you rejected, and risks
written as "[Risk] → Mitigation". List open questions only if they can be
deferred without changing the acceptance criteria, the approach, or the tasks.
Resolve any other open question with the user before writing Tasks.

**Tasks**: A numbered checklist that apply works through from top to bottom.
- Write each task as a checkbox (`- [ ] N.M ...`) and state how to verify it.
  Only `- [x]` counts as done.
- Make tasks small enough for one session, and order them by dependency.
- Every group lands its own tests. Never put testing in a final group; a final
  group is only for integration checks. Within a group, the first task covers
  that group's scenarios with failing tests.
- Write a test task as the scenarios it covers. Name an existing test to extend
  when one fits. Name a test level only when the scenario needs it (for example,
  a browser for JavaScript behavior); otherwise apply picks the cheapest level
  that exercises the behavior.
- The tasks should cover the acceptance criteria, and nothing more.
