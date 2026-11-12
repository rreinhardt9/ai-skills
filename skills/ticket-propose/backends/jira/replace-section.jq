# Replaces the body of the level-2 section headed $heading with the ADF nodes in $nodes[0].
# The heading itself is kept; the body runs until the next level-2 heading or the end.
def h2: .type == "heading" and .attrs.level == 2;
def text_of: [.. | .text? // empty] | join("");

.content as $c
| ([$c | to_entries[] | select((.value | h2) and (.value | text_of) == $heading) | .key]) as $hits
| if ($hits | length) != 1 then error("expected 1 section headed \($heading), found \($hits | length)") else . end
| $hits[0] as $start
| ([$c | to_entries[] | select(.key > $start and (.value | h2)) | .key] | first // ($c | length)) as $end
| .content = $c[:$start + 1] + $nodes[0] + $c[$end:]
