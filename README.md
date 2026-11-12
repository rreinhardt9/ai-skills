# ai-skills

Agent skills for coding agents, written to the open
[Agent Skills](https://agentskills.io/) format: a folder with a `SKILL.md`.
Claude Code, OpenCode, Codex, Cursor, and other agents that read that format
can load them.

Skills are grouped into plugins, which are sets you install together. The repo
can be installed several ways from one source:

- as plain skill folders, through [`npx skills`](https://skills.sh), for any agent;
- as a Claude Code plugin marketplace, through `.claude-plugin/marketplace.json`;
- as a git clone you link into your agent, for editing and contributing.

## Plugins

| Plugin | Skills | What it's for |
|---|---|---|
| [`ticket-workflow`](plugins/ticket-workflow/README.md) | `ticket-setup`, `ticket-explore`, `ticket-propose`, `ticket-apply`, `ticket-verify` | Plan each change in a GitHub Projects or Jira ticket, then implement and verify it test-first against that ticket. |

Each plugin's README covers its requirements, setup, and usage. Read it before
installing, because some plugins need one-time configuration.

## Installation

Pick one path per machine. Don't combine the Claude Code plugin with another
path, or the agent sees two copies of each skill (`ticket-apply` and
`ticket-workflow:ticket-apply`) and may use either one.

### Option 1: `npx skills` (any agent)

Install the skills from a plugin by name. Each plugin's README lists the
command for its full set.

```bash
npx skills add rreinhardt9/ai-skills -g --skill <skill> --skill <skill> ...
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
/plugin install <plugin>@ai-skills
```

To get updates automatically, run `/plugin`, open the **Marketplaces** tab,
select `ai-skills`, and turn on auto-update. Skills are namespaced by plugin,
for example `/ticket-workflow:ticket-apply`.

For a private repo, Claude Code clones with your shell's git credentials (SSH
keys or a credential helper), or with `GITHUB_TOKEN` if it's set.

### Option 3: Clone and link (for editing and contributing)

```bash
git clone git@github.com:rreinhardt9/ai-skills.git ~/dev/ai-skills
for s in ~/dev/ai-skills/plugins/<plugin>/skills/*; do
  ln -sfn "$s" ~/.claude/skills/"$(basename "$s")"
done
```

Claude Code reads `~/.claude/skills`, and so does OpenCode. For agents that only
read `~/.agents/skills`, link there instead. Changes apply as soon as you save,
and `git pull` updates the skills.

## Using skills in OpenCode

OpenCode loads skills automatically from your request. To get a slash command,
add a wrapper file to `~/.config/opencode/commands/`, such as `ticket-apply.md`:

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
  marketplace.json          lists each plugin and the skills it contains
plugins/
  <plugin>/
    README.md               what the plugin does, its requirements, setup, and usage
    skills/
      <skill>/SKILL.md      plus any files the skill reads
```

## Contributing

To try out a change before opening a PR:

1. **Clone** the repo, or fork it if you don't have write access.
2. **Point your agent at the clone** for the skills you're changing, using
   Option 3's `ln -sfn` command. If you installed through the Claude Code
   plugin, disable it first so you don't load two copies:
   `claude plugin disable <plugin>@ai-skills`.
3. **Experiment.** The agent reads your working copy, so you can ask it to
   change the skill directly.
4. **Open a PR** from a branch.
5. **Switch back** after it merges: re-enable the plugin or run
   `npx skills update -g`, or keep the links and `git pull`.

Guidelines:

- **Keep skills generic.** Write "the project tracker", not a specific board or
  person. Put personal preferences in your own `CLAUDE.md` or `AGENTS.md`, and
  per-repo facts in the plugin's config.
- **Group skills into plugins by what people would install together.** People
  install whole plugins, so a skill added to an existing plugin reaches everyone
  who has it on their next update. A standalone skill gets its own plugin.
- **List every skill in `marketplace.json`.** `npx skills` finds skills under
  `plugins/` only through that file.
- **Put files a skill reads inside a skill folder.** `npx skills` copies only
  skill folders, so files at the plugin root or repo root never reach those
  installs. Skills in the same plugin can share files through a sibling path
  like `../other-skill/`.
- **Validate before pushing:** `claude plugin validate .`, and
  `npx skills add . --list` to confirm `npx skills` finds every skill.

### Adding a plugin

1. Create `plugins/<plugin>/skills/<skill>/SKILL.md` for each skill.
2. Add an entry to `.claude-plugin/marketplace.json` with `"source": "<plugin>"`,
   `"strict": false`, and every skill listed under `skills`.
3. Write `plugins/<plugin>/README.md` covering what the plugin is for, its
   requirements, setup, and usage, and add a row to the Plugins table above.
4. If the plugin needs configuration:
   - keep personal config in `~/.config/<plugin>/`, never in the repo;
   - ship an example file inside a skill folder;
   - have the skills offer to set up missing config instead of just stopping,
     ideally through a `<prefix>-setup` skill people can also run directly;
   - keep secrets in environment variables, never in config files.
