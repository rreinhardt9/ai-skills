---
name: ticket-propose
description: Turn an exploration or a described change into a project-tracker ticket containing the proposal, acceptance criteria, optional design, and task checklist, then put it in the proposed stage for review. Also revises an existing ticket and checks its sections for consistency. Use when the user says "ticket propose", asks to capture or propose a change as a ticket, or asks to review or update a proposed ticket.
---

# Propose

Writes the plan for a change into a tracker ticket, where the user reviews it.
Approving it, by moving it to the ready stage, is the user's job, never yours.
This skill never implements anything.

## 1. Load the project

1. Find the repo key with `gh repo view --json nameWithOwner -q .nameWithOwner`.
2. Find that key in `~/.config/ticket-workflow/projects.yml`. If it's missing,
   stop. Tell the user, and point them to the setup steps in
   `~/.config/ticket-workflow/backends/<backend>.md`.
3. Read `~/.config/ticket-workflow/backends/<backend>.md`. Do every tracker
   operation exactly as it describes.
4. Read `~/.config/ticket-workflow/ticket-template.md`.
5. Treat the entry's `context` and its `rules.<section>` as constraints to
   follow. Don't copy them into the ticket.

## 2. Choose the mode

- If the user names an existing ticket, use **Revise** (section 4).
- Otherwise, use **Create** (section 3).

## 3. Create

1. **Ground the plan.** Draw on the conversation, and read the relevant code and
   tests. Don't ask the user for facts you can check.
2. **Resolve open questions that change the plan.** If an unknown would change
   the acceptance criteria, the approach, or the tasks, ask the user before
   writing anything. Only questions that can truly wait belong in Design.
3. **Draft the body** to the template: Why, What changes, Out of scope,
   Acceptance criteria, Design if one is warranted, and Tasks. Write it to a
   temp file.
4. **Review your draft before creating the ticket:**
   - Every requirement has at least one scenario with WHEN/THEN.
   - The scenarios describe behavior, not implementation.
   - The tasks cover the acceptance criteria, and nothing more.
   - Every task group lands its own tests, and every task says how to verify it.
   - Nothing contradicts the conversation.

   Fix anything that fails.
5. **Create the ticket.** Give it a short, outcome-focused title, add it to the
   board, and set its stage to `proposed`.
6. **Report and stop.** Give the ticket's link and a short summary: how many
   requirements and tasks it has, whether it includes a design, and any
   deferred open questions. Explain the next steps: review and edit the ticket
   in the tracker, move it to the ready stage to approve it, then run
   `ticket-apply` in a fresh session.

## 4. Revise

1. Read the ticket fresh, including its comments.
2. If the user asked for a specific revision, make it. Otherwise, run a
   **coherence review**: look for contradictions, gaps, and duplication between
   sections. Typical problems are:
   - a scenario with no task;
   - a task that serves no scenario;
   - a design decision the tasks ignore;
   - a scope item that is missing from the acceptance criteria.
3. Propose the edits one section at a time. For each, show what would change and
   apply it only after the user confirms. Follow the backend's procedure for
   editing a section.
4. If the ticket is already in the ready stage and an edit changes what gets
   built, say so, and suggest moving it back to `proposed` until it's
   re-approved. Ask before moving it.
