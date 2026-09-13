local context = ...

context.answer = context.answer + 1
context.label = context.label .. ":done"

return context
