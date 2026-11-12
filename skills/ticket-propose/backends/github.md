# GitHub backend

Each ticket is a GitHub issue on a Projects (v2) board, and the board's Status
field tracks its stage. Fill in the placeholders from the project's entry in
`projects.yml`: `<owner>`, `<number>`, `<project_id>`, `<status_field_id>`, and a
stage's `option_id`. `<repo>` is the `owner/name` key itself. `$TMP` means your
scratchpad or temp directory.

## Create a ticket

```bash
gh issue create --repo <repo> --title "<title>" --body-file "$TMP/ticket.md"   # prints the issue URL
gh project item-add <number> --owner <owner> --url <issue-url> --format json --jq .id   # prints the item id
```

Then set the stage to `proposed` (see below).

## Read a ticket

```bash
gh issue view <N> --repo <repo> --json number,title,body,state,url,comments
```

## Find a ticket's item id and current stage

```bash
gh api graphql -F n=<N> -f owner=<repo-owner> -f name=<repo-name> -f query='
query($owner:String!,$name:String!,$n:Int!){repository(owner:$owner,name:$name){issue(number:$n){
  projectItems(first:20){nodes{id project{id}
    fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}}}}}}' \
  --jq '.data.repository.issue.projectItems.nodes[] | select(.project.id=="<project_id>") | {item_id: .id, status: .fieldValueByName.name}'
```

If this prints nothing, the issue isn't on the board yet. Add it with
`gh project item-add` and use the item id that command prints.

## Set the stage

```bash
gh project item-edit --id <item_id> --project-id <project_id> \
  --field-id <status_field_id> --single-select-option-id <option_id>
```

## Edit a section or check off a task

Never rebuild the body from memory, because the user may have edited the ticket
since you last read it.

1. Fetch the current body: `gh issue view <N> --repo <repo> --json body --jq .body > "$TMP/issue-<N>.md"`
2. Change only the text you mean to change, with a targeted edit to that file.
   For example, `- [ ] 1.2 ` becomes `- [x] 1.2 `.
3. Write it back: `gh issue edit <N> --repo <repo> --body-file "$TMP/issue-<N>.md"`

## Comment

```bash
gh issue comment <N> --repo <repo> --body-file "$TMP/comment.md"
```

## Branches, PRs, and close-out

Name the branch `<N>-<short-slug>`, for example `42-shelf-sorting`. Open the PR
with `Closes #<N>` in its body. Merging the PR closes the issue, and
the board's built-in "Item closed" workflow moves it to Done.

## Setting up a new project

1. Check that `gh auth status` lists the `project` scope. If it doesn't, run
   `gh auth refresh -s project`.
2. If the repo has no board yet, create one and link it to the repo. Ask the
   user before creating it.
   ```bash
   gh project create --owner <owner> --title "<title>" --format json --jq .number
   gh project link <number> --owner <owner> --repo <repo>
   ```
3. Get the board's ids: `gh project view <number> --owner <owner> --format json --jq .id`
   and `gh project field-list <number> --owner <owner> --format json`. The latter
   gives the Status field's id and its option ids.
4. If the Status field lacks options for any of the five stages, add them. A new
   board has only Todo, In Progress, and Done, so it needs Backlog (proposed) and
   In Review. Check with the user before changing an existing board.

   `updateProjectV2Field` **replaces** the whole option list. Any existing option
   passed without its `id` is recreated under a new id, and every item that had
   it loses its status. So first read the current options:
   ```bash
   gh api graphql -f query='{node(id:"<status_field_id>"){... on ProjectV2SingleSelectField{options{id name color description}}}}' \
     --jq '.data.node.options'
   ```
   Then send every existing option back with its `id`, `name`, `color`, and
   `description` unchanged, plus the new options without ids, listed in board
   order:
   ```bash
   gh api graphql -f query='mutation { updateProjectV2Field(input: {
     fieldId: "<status_field_id>",
     singleSelectOptions: [
       {name: "Backlog", color: GRAY, description: "Proposed; awaiting review"},
       {id: "<todo id>", name: "Todo", color: GREEN, description: "<unchanged>"},
       {id: "<in progress id>", name: "In Progress", color: YELLOW, description: "<unchanged>"},
       {name: "In Review", color: BLUE, description: "Pull request open"},
       {id: "<done id>", name: "Done", color: PURPLE, description: "<unchanged>"}
     ] }) { projectV2Field { ... on ProjectV2SingleSelectField { options { id name } } } } }'
   ```
   On a board that already has items, save every item's status before the
   update and compare afterwards. Both lists must match:
   `gh project item-list <number> --owner <owner> --limit 500 --format json --jq '[.items[] | {id, status}] | sort_by(.id)'`
5. Add the project's entry to `~/.config/ticket-workflow/projects.yml`, mapping `proposed`, `ready`,
   `in_progress`, `in_review`, and `done` to Status options. Set `context`,
   `rules`, and `apply_guidance` from the repo's own test and lint commands.
6. In the board's settings, under Workflows, check that "Item closed" sets the
   status to Done. This can't be checked from the CLI, so ask the user to
   confirm it.
