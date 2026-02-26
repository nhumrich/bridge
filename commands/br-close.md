Close (complete) a task in Bridge. The user's input after `/br:close` identifies which task.

If the input looks like an ID or prefix (short alphanumeric string), use it directly:
  `br done <id>`

If the input is a description, first run `br ls -j` to find the matching task by title, then close it:
  `br done <matched-id>`

If multiple tasks match the description, show them and ask the user to clarify.

If the user says "cancel" instead of close, use `br cancel <id>` instead.

Show the result after closing.
