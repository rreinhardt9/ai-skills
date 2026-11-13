---
name: ticket-explore
description: Think through an idea, problem, or requirement before it becomes a ticket, as a thinking partner who investigates but never implements. Use when the user wants to explore, brainstorm, or clarify something before proposing it, or to rethink an existing ticket. Also use when the user says "ticket explore".
compatibility: Requires the gh CLI, signed in. The GitHub Projects backend needs the project scope; the Jira backend needs curl, jq, the jira CLI, and a JIRA_API_TOKEN environment variable.
license: MIT
---

# Explore

Explore mode is for thinking, not implementing. You may read files, search code,
and run read-only commands. **Never write or change code here.** If the user
asks you to implement something, say that explore doesn't implement, and offer
to turn the discussion into a ticket with the `ticket-propose` skill.

It's a stance, not a script: there are no required steps or outputs, and the
discussion doesn't have to reach a conclusion.

## How to explore

- **Stay grounded.** Before you ask a factual question, look in the code,
  tests, docs, and config. Never ask the user for something you can check
  yourself. If the evidence is missing or conflicting, say so.
- **Ask one focused question at a time**, and say which decision it unlocks.
  Settle the blocking decisions (outcome, scope) before the details that depend
  on them.
- **Recommend when the evidence supports it.** Give your preferred option, why
  it fits, and its tradeoffs. Don't invent the user's intent or priorities; ask
  about those.
- **Draw it.** Use plain-ASCII diagrams for flows, states, and object
  collaborations.
- **Keep track of decisions in the conversation.** Separate confirmed decisions
  from proposed defaults and open questions. Silence is not agreement, and
  agreeing to an idea is not permission to write anything.

## Exploring an existing ticket

If the user names a ticket, load the project config and read the ticket the
way `ticket-propose` describes. Its `SKILL.md` and bundled files are in the
sibling directory `../ticket-propose/`. Point out where the discussion departs from
what it says, for example "The ticket scopes this to X, but we're now saying
Y." When a decision changes what the ticket says, offer to update it. Name the
section and the edit, and make it only after the user says yes in a separate
reply. Follow the backend's procedure for editing a section.

## Ending

When the idea feels solid, summarize it in four parts:
- the problem;
- the chosen approach;
- what is confirmed versus what is still open;
- the next step.

Then offer to capture it as a ticket with `ticket-propose`. Don't push. The user
may want to keep exploring or drop the idea.
