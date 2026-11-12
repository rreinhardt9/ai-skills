# Jira backend

Each ticket is a Jira issue, and its status is its stage. Fill in the
placeholders from the project's entry in `projects.yml`: `<site>`, `<email>`,
`<project_key>`, `<issue_type>`, and a stage's status `name`. `$TMP` means your
scratchpad or temp directory, and `$B` means the skill's `scripts/` directory
(`../scripts/` from this file).

Descriptions are stored as ADF (Atlassian Document Format, JSON). **Never write a
description through `jira issue create -b` or `jira issue edit -b`, and never
rebuild one from `jira issue view`'s output.** Both are lossy: they drop inline
code, task-list checkboxes, and anything else written in Jira's editor. Read and
write descriptions as ADF through the REST API, as described below. Comments are
new text, so `jira issue comment add` with markdown is fine for them.

Every REST call uses this helper:

```bash
J(){ curl -sS -u "<email>:$JIRA_API_TOKEN" -H 'Content-Type: application/json' "$@"; }
```

## Writing ADF

Write the template's sections as ADF nodes:

| Markdown | ADF node |
|---|---|
| `## Why` | `{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Why"}]}` (levels 3 and 4 the same way) |
| Paragraph | `{"type":"paragraph","content":[<text nodes>]}` |
| `- item` | `{"type":"bulletList","content":[{"type":"listItem","content":[<paragraph>]}]}` |
| `- [ ] 1.1 task` | `{"type":"taskList","attrs":{"localId":"tasks-1"},"content":[{"type":"taskItem","attrs":{"localId":"task-1-1","state":"TODO"},"content":[<text nodes>]}]}` |
| `**bold**`, `` `code` ``, `[link](url)` | a text node with `"marks":[{"type":"strong"}]`, `[{"type":"code"}]`, or `[{"type":"link","attrs":{"href":"url"}}]` |

Things to get right:
- A `taskItem` holds text nodes directly, with no paragraph around them. Its text
  must start with the task number and a space (`1.1 ...`), because checking a
  task off finds it that way.
- Give each `taskList` and `taskItem` a unique `localId`.
- Wrap a whole description as `{"version":1,"type":"doc","content":[...]}`.
- Jira rejects malformed ADF with HTTP 400 `INVALID_INPUT`. If that happens, fix
  the JSON and retry; the ticket is unchanged.

## Create a ticket

```bash
ME=$(J https://<site>/rest/api/3/myself | jq -r .accountId)
jq -n --slurpfile d "$TMP/desc.json" --arg me "$ME" --arg title "<title>" \
  '{fields:{project:{key:"<project_key>"},issuetype:{name:"<issue_type>"},summary:$title,
    assignee:{accountId:$me},description:$d[0]}}' \
  | J -X POST https://<site>/rest/api/3/issue --data @-   # prints {"key":"CP-123",...}
```

Then set the stage to `proposed`.

## Read a ticket

```bash
J "https://<site>/rest/api/3/issue/<KEY>?fields=summary,status,description" > "$TMP/<KEY>.json"
jq -r '.fields.summary, .fields.status.name' "$TMP/<KEY>.json"
jq '.fields.description' "$TMP/<KEY>.json" | jq -r -f $B/adf-to-md.jq          # the body as markdown
J "https://<site>/rest/api/3/issue/<KEY>/comment" | jq -c '.comments[]' | while read -r c; do
  jq -r '"--- \(.author.displayName), \(.created)"' <<<"$c"
  jq '.body' <<<"$c" | jq -r -f $B/adf-to-md.jq
done                                                                              # comments, oldest first
```

The markdown output is only for reading. Never send it back to Jira.

## Set the stage

```bash
jira issue move <KEY> "<status name>"
```

## Check off a task

```bash
J "https://<site>/rest/api/3/issue/<KEY>?fields=description" | jq '.fields.description' > "$TMP/desc.json"
jq --arg task 1.2 --arg state DONE -f $B/set-task.jq "$TMP/desc.json" > "$TMP/desc-new.json"
jq '{fields:{description:.}}' "$TMP/desc-new.json" | J -X PUT https://<site>/rest/api/3/issue/<KEY> --data @-
```

Always fetch fresh right before the edit. `set-task.jq` errors unless exactly one
task has that number. Use `--arg state TODO` to un-check a task.

## Replace a section

Write the section's new body as a JSON array of ADF nodes to
`$TMP/section.json`, without its `##` heading. Then:

```bash
J "https://<site>/rest/api/3/issue/<KEY>?fields=description" | jq '.fields.description' > "$TMP/desc.json"
jq --arg heading "Design" --slurpfile nodes "$TMP/section.json" -f $B/replace-section.jq "$TMP/desc.json" > "$TMP/desc-new.json"
jq '{fields:{description:.}}' "$TMP/desc-new.json" | J -X PUT https://<site>/rest/api/3/issue/<KEY> --data @-
```

Everything outside that section stays exactly as stored. `replace-section.jq`
errors unless exactly one `##` heading has that text.

## Embed an image

An image can only point at an attachment that already exists on the issue, so
create the ticket first. Then upload the image (this is multipart, so it uses
plain `curl` rather than `J`):

```bash
curl -sS -u "<email>:$JIRA_API_TOKEN" -H 'X-Atlassian-Token: no-check' \
  -X POST https://<site>/rest/api/3/issue/<KEY>/attachments \
  -F "file=@$TMP/<image>.png;type=image/png"            # prints [{"id":"45091",...}]
```

An inline image needs the attachment's media file ID, which the REST API doesn't
return. Downloading the attachment redirects to the media service, and the ID is
in the redirect URL:

```bash
MEDIA_ID=$(curl -sS -o /dev/null -w '%{redirect_url}' -u "<email>:$JIRA_API_TOKEN" \
  https://<site>/rest/api/3/attachment/content/<attachment id> \
  | sed -E 's#.*/file/([0-9a-f-]{36})/.*#\1#')
```

The redirect URL also carries a short-lived access token, so never print or log
the whole URL. The image node is:

```json
{"type":"mediaSingle","attrs":{"layout":"center"},
 "content":[{"type":"media","attrs":{"type":"file","id":"<MEDIA_ID>","collection":""}}]}
```

Add it to a section with **Replace a section**, keeping the section's existing
nodes. A caption is an ordinary paragraph next to it. To check the image
resolves, look for its `data-attachment-name` in the rendered description:

```bash
J "https://<site>/rest/api/3/issue/<KEY>?expand=renderedFields&fields=description" \
  | jq -r '.renderedFields.description' | grep -oE 'data-attachment-name="[^"]*"'
```

Never delete an attachment an image points at; the image breaks.

## Comment

```bash
jira issue comment add <KEY> --template "$TMP/comment.md"
```

## Branches, PRs, and close-out

- Name the branch `<KEY>-<short-slug>`, for example `CP-123-filter-jobs-by-location`.
- Never put the key in a PR title or a commit subject line. Put it in the PR
  body, and on the first line of each commit's body (the line after the blank
  line that follows the subject).
- Merging doesn't move the ticket. After the PR merges, ask the user before
  moving it to `done`.

## Setting up a new project

1. Check that `JIRA_API_TOKEN` is set and that `jira me` works.
2. Get an issue's possible statuses:
   `J https://<site>/rest/api/3/issue/<any KEY>/transitions | jq -r '.transitions[].to.name'`.
3. Add the project's entry to `~/.config/ticket-workflow/projects.yml`, mapping `proposed`, `ready`,
   `in_progress`, `in_review`, and `done` to status names.
