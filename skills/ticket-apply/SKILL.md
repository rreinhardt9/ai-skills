---
name: ticket-apply
description: Implement an approved project-tracker ticket by working through its task checklist outside-in, with tests first, checking off tasks in the ticket as they're done. Use when the user says "ticket apply", or asks to implement, start, or continue work on a ticket.
---

# Apply

Implements an approved ticket. The ticket is the whole plan, and its checkboxes
are the only record of progress. That makes a fresh session the best place to
run this, and lets you resume at any time: start again from the first
unchecked task.

## 1. Load the project and the ticket

1. Load the project config, backend, and template the way `ticket-propose`
   step 1 describes.
2. If the user didn't name a ticket, ask which one to use.
3. Read the ticket fresh, including its comments, and look up its current stage.
4. Announce which ticket you're using, and how to choose a different one.

## 2. Check that it's approved

- **In the `ready` stage**: set it to `in_progress` and continue.
- **Already in `in_progress`**: you're resuming. Continue.
- **In any other stage**: stop. If it's `proposed`, say the user approves it by
  moving it to the ready stage. Never move it there yourself.

If you're on the default branch, create a branch named the way the backend
describes.

## 3. Work through the tasks

Show progress as "N/M tasks complete". Then, for each unchecked task in order:

1. Say which task you're on.
2. Work outside-in. When the task is a test, write it from the ticket's
   scenarios and confirm it fails for the expected reason. When it's
   implementation, make the smallest change that moves the failing test forward.
3. Run the task's stated verification, and everything in the config's
   `apply_guidance`.
4. Check the task off only when its behavior is fully implemented and verified.
   Never check off partial or deferred work. Re-fetch the body right before
   editing it, confirm the checkbox still matches the task, then make a
   targeted edit.

## When to pause

Stop and ask the user when:
- a task is ambiguous;
- an error or blocker comes up;
- the user interrupts;
- implementing shows that the plan is wrong (a missing scenario, a bad design
  decision, a task that doesn't make sense);
- a task needs more than the ticket describes, or you're tempted to narrow,
  defer, or make exceptions to specified behavior to make it fit.

When you pause:
- Raise added scope instead of quietly absorbing it.
- Never edit the approved sections of the ticket on your own. Instead, post a
  ticket comment describing the problem and the change you'd make, and ask the
  user how to proceed.
- Report N/M progress, the issue, and two or three options.

## 4. Finish

When every task is checked off, report what was completed this session.
Suggest running `ticket-verify` before opening a pull request. Commit only if
the user asks you to.
