# Renders a Jira ADF document as markdown for reading. Not for writing back.
def wrap($marks):
  reduce ($marks // [])[] as $m (.;
    if $m.type == "code" then "`" + . + "`"
    elif $m.type == "strong" then "**" + . + "**"
    elif $m.type == "em" then "_" + . + "_"
    elif $m.type == "strike" then "~~" + . + "~~"
    elif $m.type == "link" then "[" + . + "](" + $m.attrs.href + ")"
    else . end);

def inline:
  if .type == "text" then (.marks // []) as $m | .text | wrap($m)
  elif .type == "hardBreak" then "\n"
  elif .type == "mention" then "@" + ((.attrs.text // "someone") | ltrimstr("@"))
  elif .type == "inlineCard" then .attrs.url
  elif .type == "emoji" then (.attrs.text // .attrs.shortName)
  else [.content[]? | inline] | join("") end;

def inlines: [.content[]? | inline] | join("");

def block($indent):
  def item($bullet):
    (.content[0] | if .type == "paragraph" then $indent + $bullet + inlines else block($indent) end)
    + ([.content[1:][] | "\n" + block($indent + "  ")] | join(""));
  if .type == "paragraph" then $indent + inlines
  elif .type == "heading" then ("#" * .attrs.level) + " " + inlines
  elif .type == "bulletList" then [.content[] | item("- ")] | join("\n")
  elif .type == "orderedList" then
    [.content | to_entries[] | .key as $k | .value | item("\($k + 1). ")] | join("\n")
  elif .type == "taskList" then
    [.content[] |
      if .type == "taskItem" then
        $indent + "- [" + (if .attrs.state == "DONE" then "x" else " " end) + "] " + inlines
      else block($indent + "  ") end] | join("\n")
  elif .type == "codeBlock" then
    "```" + (.attrs.language // "") + "\n" + ([.content[]?.text] | join("")) + "\n```"
  elif .type == "rule" then "---"
  elif .type == "blockquote" or .type == "panel" then
    [.content[] | block("") | "> " + .] | join("\n")
  elif .type == "table" then
    [.content[] | "| " + ([.content[] | [.content[]? | block("")] | join(" ")] | join(" | ")) + " |"] | join("\n")
  else [.content[]? | block($indent)] | join("\n") end;

[.content[]? | block("")] | join("\n\n")
