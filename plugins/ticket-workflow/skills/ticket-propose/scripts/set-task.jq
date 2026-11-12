# Sets the state of the task whose text starts with "$task " to $state (DONE or TODO).
# Fails if no task matches, so a stale task number can't silently do nothing.
def text_of: [.. | .text? // empty] | join("");

([.. | objects | select(.type == "taskItem" and (text_of | startswith($task + " ")))] | length) as $n
| if $n != 1 then error("expected 1 task numbered \($task), found \($n)") else . end
| walk(if type == "object" and .type == "taskItem" and (text_of | startswith($task + " "))
       then .attrs.state = $state else . end)
