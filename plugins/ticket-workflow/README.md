# ticket-workflow

A plan-first workflow, modeled on [OpenSpec](https://github.com/Fission-AI/OpenSpec),
that plans each change in a project-tracker ticket instead of in files in the
repo. You explore an idea with the agent, and it writes a proposal into a ticket.
You review and edit the ticket in the tracker, and approve it by moving it to
the ready stage. The agent then implements from the ticket, checking off tasks
as it goes. GitHub Projects and Jira are supported as trackers.

```
explore ──> propose ──> [you review and edit in the tracker] ──> apply ──> verify ──> PR
              │               move the ticket to ready              │          │
              v                 to approve it                       v          v
          proposed                                              in_progress  in_review ──> done
```

- **The ticket is the plan.** It holds the proposal, the acceptance criteria,
  an optional design, and a task checklist. Its checkboxes are the only record
  of progress, so `ticket-apply` can resume in any session.
- **Tests are the living spec.** Acceptance criteria are written as WHEN/THEN
  scenarios, and each one becomes an outside-in test. No separate document
  describes the system's behavior, so there's nothing to drift.
- **You hold the gate.** The agent never moves a ticket to ready, and
  `ticket-apply` won't start until you have.

## Skills

| Skill | When to use it | What it does |
|---|---|---|
| `ticket-setup` | First use on a machine or in a repo | Checks prerequisites, then writes the repo's entry in your personal config, creating or configuring the tracker board if you agree. The other skills offer to run it when config is missing. |
| `ticket-explore` | Thinking an idea through, or rethinking an existing ticket | Acts as a thinking partner. It investigates the code but never writes any, asks one focused question at a time, and keeps decisions separate from open questions. When the idea is solid, it offers to hand off to `ticket-propose`. |
| `ticket-propose` | Capturing a change as a ticket, or revising one | Writes the ticket from the template, and checks its own draft: every scenario has a task, and the tasks cover the criteria and nothing more. It then creates the ticket in the proposed stage. Run it on an existing ticket for a coherence review across its sections. |
| `ticket-apply` | Implementing an approved ticket | Checks the ticket is ready, moves it to in progress, creates a branch, and works through the unchecked tasks with tests first, checking each one off in the ticket. It pauses instead of quietly narrowing scope, and proposes plan changes as ticket comments. Best run in a fresh session. |
| `ticket-verify` | Checking work before review | Reports on completeness (tasks done), correctness (each scenario has a passing test), and coherence (design and conventions followed), with each issue graded CRITICAL, WARNING, or SUGGESTION. With your OK, it then posts the report, opens the PR, and moves the ticket to in review. |

The skills refer to each other through sibling directories (`../ticket-propose/`,
`../ticket-setup/`), so **install all five together**. With `npx skills`:

```bash
npx skills add rreinhardt9/ai-skills -g --skill ticket-setup --skill ticket-explore \
  --skill ticket-propose --skill ticket-apply --skill ticket-verify
```

See the [main README](../../README.md#installation) for the other install paths.

## Requirements

- [`gh`](https://cli.github.com/), signed in. Every skill uses it to identify
  the repo, and the GitHub backend needs the `project` scope:
  `gh auth refresh -s project`.
- For Jira: `curl`, `jq`, [`jira-cli`](https://github.com/ankitpokhrel/jira-cli),
  and a `JIRA_API_TOKEN` environment variable.

## Setup

In the repo you want to plan work for, run `/ticket-setup`, or just start with
`/ticket-propose`, which offers setup when it's needed. The agent checks the
requirements, asks whether the repo uses GitHub Projects or Jira, and walks
through the backend's setup steps. For GitHub, it creates and links a board if
you agree, and adds any missing stages. It then drafts the repo's entry from
the repo's own test and lint commands, and writes it once you confirm.

Each repo needs this once per machine.

### Configuration

Entries live in `~/.config/ticket-workflow/projects.yml`, which is personal and
never committed. `ticket-setup` writes it for you, but you can also edit it by
hand, starting from
[`skills/ticket-propose/assets/projects.example.yml`](skills/ticket-propose/assets/projects.example.yml).
Each entry is keyed by the repo's `owner/name`:

```yaml
owner/repo:
  backend: github | jira
  # github: a `project` block with owner, number, id, status_field_id, and
  #   statuses.<stage>: { name, option_id }
  # jira: a `jira` block with site, email, project_key, issue_type, and
  #   statuses.<stage>: { name }
  context: |                 # facts the agent should know when planning and implementing
  rules:
    tasks: [...]             # extra rules applied when writing that section
  apply_guidance: [...]      # checks to run before checking a task off
```

The five stages are `proposed`, `ready`, `in_progress`, `in_review`, and `done`.
Each one maps to a status in your tracker.

## Usage

```
/ticket-explore shelf sorting by genre       # think it through
/ticket-propose                              # the agent creates the ticket in the proposed stage
   ... review and edit the ticket, then move it to the ready stage ...
/ticket-apply #42                            # new session; works through the tasks
/ticket-verify #42                           # report; then PR and move to in review
```

You can also just describe what you want ("propose this as a ticket"), and the
agent picks the skill. When installed as a Claude Code plugin, the slash
commands are namespaced, for example `/ticket-workflow:ticket-apply`.

## Layout

```
skills/
  ticket-setup/SKILL.md
  ticket-explore/SKILL.md
  ticket-propose/
    SKILL.md                also defines how every ticket skill loads its config
    scripts/
      *.jq                  Jira ADF helpers: read as markdown, check off a task, replace a section
    references/
      github.md             gh commands for each tracker operation, plus project setup
      jira.md               REST and ADF recipes for each operation, plus project setup
    assets/
      ticket-template.md    the ticket's sections and how to write each one
      projects.example.yml  sample config entries
  ticket-apply/SKILL.md
  ticket-verify/SKILL.md
```

The shared files live in `ticket-propose/`, in the `scripts/`, `references/`,
and `assets/` folders the [Agent Skills spec](https://agentskills.io/specification)
defines. They aren't at the plugin root because `npx skills` installs only skill
folders.

## Gotchas

- **Don't edit a Jira description through `jira-cli` (`-b`), or rebuild one from
  `jira issue view`.** Both lose data: inline code, checkboxes, and anything
  written in Jira's editor. The Jira backend reads and writes ADF over REST.
  Comments are the exception: `jira issue comment add` is fine.
- **Adding Status options on GitHub replaces the whole option list.** Send every
  existing option back with its `id`, or every item's status resets. The GitHub
  backend's setup section covers this.
- **The agent writes Jira ADF by hand.** That's verbose, but Jira rejects
  malformed ADF with a 400, so a mistake never reaches the ticket.
