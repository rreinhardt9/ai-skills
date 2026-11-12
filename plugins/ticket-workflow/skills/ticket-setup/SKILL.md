---
name: ticket-setup
description: Set up the ticket workflow on this machine and for the current repo, by checking prerequisites and writing the repo's entry in the personal projects.yml config. Use when the user says "ticket setup", asks to set up or configure the ticket workflow for a repo, or when another ticket skill finds the config missing.
compatibility: Requires the gh CLI, signed in. The GitHub Projects backend needs the project scope; the Jira backend needs curl, jq, the jira CLI, and a JIRA_API_TOKEN environment variable.
---

# Setup

Configures the ticket workflow so the other ticket skills can run in this repo.
The shared files live in the sibling directory `../ticket-propose/`:
`assets/projects.example.yml` shows the shape of an entry, and
`references/<backend>.md` has the setup steps for each tracker.

Ask before every change outside the conversation: creating files, creating or
changing a board, writing an entry.

## 1. Check prerequisites

- `gh auth status` succeeds. Every skill uses `gh` to identify the repo.
- For GitHub Projects, `gh auth status` lists the `project` scope. If it
  doesn't, ask the user to run `gh auth refresh -s project`.
- For Jira, `curl`, `jq`, and `jira` are installed, and `JIRA_API_TOKEN` is
  set. Check that the variable is set without printing its value.

Report anything missing with the command or link that fixes it, and stop until
it's fixed.

## 2. Find what's missing

1. Find the repo key with `gh repo view --json nameWithOwner -q .nameWithOwner`.
2. If `~/.config/ticket-workflow/projects.yml` doesn't exist, offer to create it,
   starting with the comment header from `assets/projects.example.yml` and no entries.
3. If the file already has an entry for the repo key, show it and ask whether
   to change it. If not, stop: setup is done.

## 3. Write the repo's entry

1. Ask which tracker the repo uses, GitHub Projects or Jira, unless the user
   already said.
2. Follow the "Setting up a new project" section of `references/<backend>.md`.
3. Draft `context`, `rules`, and `apply_guidance` from the repo itself: its
   `CLAUDE.md` or `AGENTS.md`, test setup, and lint config. Don't ask for facts
   you can read.
4. Show the full entry and write it only after the user confirms. Never put a
   token or other secret in `projects.yml`; credentials stay in environment
   variables.

## 4. Hand back

If another ticket skill sent you here, continue with the user's original
request. Otherwise, suggest `ticket-explore` or `ticket-propose` as the next
step.
