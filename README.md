# ai-skills

Agent skills for coding agents, written to the open
[Agent Skills](https://agentskills.io/) format: a folder with a `SKILL.md`.
Claude Code, OpenCode, Codex, Cursor, and other agents that read that format
can load them.

The repo can be installed several ways from one source:

- as plain skill folders, through [`npx skills`](https://skills.sh), for any agent;
- as a Claude Code plugin marketplace, through `.claude-plugin/marketplace.json`;
- as a git clone you link into your agent, for editing and contributing.

## Available skills

### `ticket-workflow` plugin

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

| Skill | When to use it | What it does |
|---|---|---|
| `ticket-explore` | Thinking an idea through, or rethinking an existing ticket | Acts as a thinking partner. It investigates the code but never writes any, asks one focused question at a time, and keeps decisions separate from open questions. When the idea is solid, it offers to hand off to `ticket-propose`. |
| `ticket-propose` | Capturing a change as a ticket, or revising one | Writes the ticket from the template, and checks its own draft: every scenario has a task, and the tasks cover the criteria and nothing more. It then creates the ticket in the proposed stage. Run it on an existing ticket for a coherence review across its sections. |
| `ticket-apply` | Implementing an approved ticket | Checks the ticket is ready, moves it to in progress, creates a branch, and works through the unchecked tasks with tests first, checking each one off in the ticket. It pauses instead of quietly narrowing scope, and proposes plan changes as ticket comments. Best run in a fresh session. |
| `ticket-verify` | Checking work before review | Reports on completeness (tasks done), correctness (each scenario has a passing test), and coherence (design and conventions followed), with each issue graded CRITICAL, WARNING, or SUGGESTION. With your OK, it then posts the report, opens the PR, and moves the ticket to in review. |

`ticket-propose` holds the files the other three skills share: the ticket
template, the backend recipes, and the Jira `jq` filters. The others read them
from the sibling `../ticket-propose/` directory, so **install all four
together**.

A typical run:

```
/ticket-explore shelf sorting by genre       # think it through
/ticket-propose                              # the agent creates the ticket in the proposed stage
   ... review and edit the ticket, then move it to the ready stage ...
/ticket-apply #42                            # new session; works through the tasks
/ticket-verify #42                           # report; then PR and move to in review
```

## Requirements

- [`gh`](https://cli.github.com/), signed in. Every skill uses it to identify
  the repo, and the GitHub backend needs the `project` scope:
  `gh auth refresh -s project`.
- For Jira: `curl`, `jq`, [`jira-cli`](https://github.com/ankitpokhrel/jira-cli),
  and a `JIRA_API_TOKEN` environment variable.

## Installation

Pick one path per machine. Don't combine the Claude Code plugin with another
path, or the agent sees two copies of each skill (`ticket-apply` and
`ticket-workflow:ticket-apply`) and may use either one.

### Option 1: `npx skills` (any agent)

```bash
npx skills add rreinhardt9/ai-skills -g \
  --skill ticket-explore --skill ticket-propose --skill ticket-apply --skill ticket-verify
```

This copies each skill into a shared directory and links it into every agent it
detects. Use `-a claude-code -a opencode` to pick agents. Listing skills with
`--skill` means you get only those; skills added to this repo later won't
appear unless you install them.

```bash
npx skills check -g     # see what's changed upstream
npx skills update -g    # pull the changes
```

The installed copies are snapshots, not git checkouts. Edits made to them
aren't saved anywhere and may be lost on update. To change a skill, see
[Contributing](#contributing).

### Option 2: Claude Code plugin marketplace

```
/plugin marketplace add rreinhardt9/ai-skills
/plugin install ticket-workflow@ai-skills
```

To get updates automatically, run `/plugin`, open the **Marketplaces** tab,
select `ai-skills`, and turn on auto-update. Skills are namespaced by plugin,
for example `/ticket-workflow:ticket-apply`.

For a private repo, Claude Code clones with your shell's git credentials (SSH
keys or a credential helper), or with `GITHUB_TOKEN` if it's set.

### Option 3: Clone and link (for editing and contributing)

```bash
git clone git@github.com:rreinhardt9/ai-skills.git ~/dev/ai-skills
for s in ticket-explore ticket-propose ticket-apply ticket-verify; do
  ln -sfn ~/dev/ai-skills/skills/$s ~/.claude/skills/$s
done
```

Claude Code reads `~/.claude/skills`, and so does OpenCode. For agents that only
read `~/.agents/skills`, link there instead. Changes apply as soon as you save,
and `git pull` updates the skills.

## Configuration

The skills look up the current repo in `~/.config/ticket-workflow/projects.yml`,
which is personal and never committed. Start from the sample:

```bash
mkdir -p ~/.config/ticket-workflow
cp ~/dev/ai-skills/skills/ticket-propose/projects.example.yml ~/.config/ticket-workflow/projects.yml
```

If you installed with Option 1 or 2, copy the file from GitHub instead, or
from the installed `ticket-propose` folder.

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
Map each one to a status in your tracker.

### Adding a project

Open the agent in the repo and say *"Set up the ticket workflow for this repo
using GitHub Projects"* (or Jira). It follows the "Setting up a new project"
section of the matching backend file. For GitHub, it creates and links a board
if you agree, adds any missing stages, collects the board's IDs, and writes the
`projects.yml` entry, with rules taken from the repo's own test and lint
commands.

## Using the skills

| | Claude Code | OpenCode |
|---|---|---|
| Automatic | The agent picks a skill from your request ("propose this as a ticket") | Same |
| Slash command | `/ticket-propose <args>` (`/ticket-workflow:ticket-propose` when installed as a plugin) | Add a command wrapper (below) |

An OpenCode command wrapper is a file in `~/.config/opencode/commands/`, such as
`ticket-apply.md`:

```markdown
---
description: Implement an approved tracker ticket
---

Load the `ticket-apply` skill and follow it.

$ARGUMENTS
```

## Repository layout

```
.claude-plugin/
  marketplace.json          plugin definitions: which skills each plugin contains
skills/
  ticket-explore/SKILL.md
  ticket-propose/
    SKILL.md                also defines how every ticket skill loads its config
    ticket-template.md      the ticket's sections and how to write each one
    projects.example.yml    sample config to copy to ~/.config/ticket-workflow/
    backends/
      github.md             gh commands for each tracker operation, plus project setup
      jira.md               REST and ADF recipes for each operation, plus project setup
      jira/*.jq             ADF helpers: read as markdown, check off a task, replace a section
  ticket-apply/SKILL.md
  ticket-verify/SKILL.md
```

## Contributing

To try out a change before opening a PR:

1. **Clone** the repo, or fork it if you don't have write access.
2. **Point your agent at the clone** for the skills you're changing, using
   Option 3's `ln -sfn` command. If you installed through the Claude Code
   plugin, disable it first so you don't load two copies:
   `claude plugin disable ticket-workflow@ai-skills`.
3. **Experiment.** The agent reads your working copy, so you can ask it to
   change the skill directly.
4. **Open a PR** from a branch.
5. **Switch back** after it merges: re-enable the plugin or run
   `npx skills update -g`, or keep the links and `git pull`.

Guidelines:

- **Keep skills generic.** Write "the project tracker", not a specific board or
  person. Put personal preferences in your own `CLAUDE.md` or `AGENTS.md`, and
  per-repo facts in `projects.yml`.
- **Group skills into plugins by what people would install together.** People
  install whole plugins, so a skill added to an existing plugin reaches everyone
  who has it on their next update. Give a standalone skill its own plugin entry
  in `marketplace.json`.
- **Validate before pushing:** `claude plugin validate .`

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
