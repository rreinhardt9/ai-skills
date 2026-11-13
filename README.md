# ai-skills

Agent skills for coding agents. Every skill follows the open
[Agent Skills](https://agentskills.io/) format, as defined in its
[specification](https://agentskills.io/specification): a folder with a
`SKILL.md`, plus optional `scripts/`, `references/`, and `assets/` folders.
Claude Code, OpenCode, Codex, Cursor, and other agents that read that format
can load them.

Skills are grouped into plugins, which are sets you install together. The repo
can be installed several ways from one source:

- as plain skill folders, through [`gh skill`](https://cli.github.com/manual/gh_skill), for any agent;
- as a Claude Code plugin marketplace, through `.claude-plugin/marketplace.json`;
- from a local clone, through `gh skill`, for trying out changes before a PR;
- from a branch on GitHub, through `gh skill`, for trying out a PR's changes.

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

### Option 1: `gh skill` (any agent)

[`gh skill`](https://cli.github.com/manual/gh_skill) is part of the GitHub CLI.
It installs one skill per command, so run it once for each skill in the plugin.
Each plugin's README lists its skills.

```bash
gh skill install rreinhardt9/ai-skills <skill> --agent claude-code --scope user
```

`--scope user` installs into your home directory so the skill works in every
repo. Without it, the skill goes into the current repo. Use `--agent` to pick
the agent, such as `opencode` or `codex`. To install for more than one agent,
run the command once per agent. Skills added to this repo later won't appear
unless you install them.

```bash
gh skill update --dry-run   # see what's changed upstream
gh skill update --all       # pull the changes
```

The installed copies are snapshots, not git checkouts. Edits made to them
aren't saved anywhere, and `gh skill update --force` overwrites them. To change
a skill, see [Contributing](#contributing).

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

### Option 3: From a local clone (for trying out changes)

`gh skill` also installs from a path on disk with `--from-local`. Run it for
each skill, as in Option 1:

```bash
git clone git@github.com:rreinhardt9/ai-skills.git ~/dev/ai-skills
gh skill install ~/dev/ai-skills <skill> --from-local --agent claude-code --scope user --force
```

`--force` replaces the copy that's already installed without prompting. This
copies the clone's current files rather than linking to them, so edits in the
clone take effect only when you run the command again. `gh skill update` skips
skills installed from a path and reports that each one "has no GitHub
metadata", which reminds you which skills aren't on the released version.

To go back to the released version, run Option 1's command again with
`--force`.

### Option 4: From a branch (for reviewing a PR)

`gh skill` also installs from a branch on GitHub with `--pin`, with no clone
needed. Run it for each skill, as in Option 1:

```bash
gh skill install rreinhardt9/ai-skills <skill> --pin <branch> --agent claude-code --scope user --force
```

`gh skill update` skips pinned skills, so to pick up new commits pushed to the
branch, such as fixes made during review, run the command again. For a PR from
a fork, use the fork's name in place of `rreinhardt9/ai-skills`.

To go back to the released version, run Option 1's command again with
`--force`, which also clears the pin.

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
      <skill>/
        SKILL.md            frontmatter (name, description, compatibility) and instructions
        scripts/            code the agent runs
        references/         docs the agent reads when it needs them
        assets/             templates and example files
```

## Contributing

To try out a change to an existing skill before opening a PR:

1. **Clone** the repo, or fork it if you don't have write access, and create a
   branch.
2. **Edit the skill in your clone.** When asking an agent to make the change,
   point it at the clone. By default it edits the installed copy it loaded,
   and your next install overwrites that copy.
3. **Install from your clone** with Option 3, passing every skill in the
   plugin. Skills in a plugin can read each other's files, so installing only
   some of them mixes your version with the released one. If you use the Claude
   Code plugin, disable it first so you don't load two copies:
   `claude plugin disable <plugin>@ai-skills`.
4. **Try it in a new session.** Repeat steps 2–4 until you're happy with it.
5. **Open a PR**, or throw the branch away. Reviewers can try your change
   by installing your branch with Option 4 in place of Option 3 in step 3.
6. **Switch back** to the released version with Option 1's command, or
   re-enable the plugin, once the PR merges or you've abandoned it.

### Developing a new skill

While a skill changes a lot, keep it out of this repo: write it directly in
your agent's skills directory (for example `~/.claude/skills/<skill>/`), where
every edit takes effect immediately. When it's ready to share, move it into a
plugin as described below, then install it from your clone (Option 3) to
replace your working copy.

Guidelines:

- **Keep skills generic.** Write "the project tracker", not a specific board or
  person. Put personal preferences in your own `CLAUDE.md` or `AGENTS.md`, and
  per-repo facts in the plugin's config.
- **Group skills into plugins by what people would install together.** People
  install whole plugins, so a skill added to an existing plugin reaches everyone
  who has it on their next update. A standalone skill gets its own plugin.
- **Keep every skill at `plugins/<plugin>/skills/<skill>/SKILL.md`.** That's
  where `gh skill` looks for them. Also list each one in `marketplace.json`,
  which the Claude Code plugin reads.
- **Put files a skill reads inside a skill folder.** `gh skill` copies only
  skill folders, so files at the plugin root or repo root never reach those
  installs. Skills in the same plugin can share files through a sibling path
  like `../other-skill/`.
- **Follow the [Agent Skills specification](https://agentskills.io/specification).**
  The `name` matches the folder name. The `description` says what the skill
  does and when to use it. Add `compatibility` when the skill needs CLIs or
  environment variables. Put code in `scripts/`, extra docs in `references/`,
  and templates or examples in `assets/`, and refer to them by paths relative
  to the skill folder.
- **Validate before pushing:** `claude plugin validate .`,
  `gh skill publish --dry-run` to confirm `gh skill` finds every skill, and
  [`skills-ref validate`](https://github.com/agentskills/agentskills/tree/main/skills-ref)
  on each skill folder to check its frontmatter against the spec.

### Adding a plugin

1. Create `plugins/<plugin>/skills/<skill>/SKILL.md` for each skill.
2. Add an entry to `.claude-plugin/marketplace.json` with `"source": "<plugin>"`,
   `"strict": false`, and every skill listed under `skills`.
3. Write `plugins/<plugin>/README.md` covering what the plugin is for, its
   requirements, setup, and usage, and add a row to the Plugins table above.
4. If the plugin needs configuration:
   - keep personal config in `~/.config/<plugin>/`, never in the repo;
   - ship an example file in a skill's `assets/` folder;
   - have the skills offer to set up missing config instead of just stopping,
     ideally through a `<prefix>-setup` skill people can also run directly;
   - keep secrets in environment variables, never in config files.

## License

[MIT](LICENSE)
