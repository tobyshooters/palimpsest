## Palimpsest

![demo](https://raw.githubusercontent.com/tobyshooters/palimpsest/master/assets/translate.gif)

A dead-simple Claude interface for Neovim.

1. Replaces "chat" metaphor with a palimpsest—layers of writing, on top of
   each other. No distinction between user input and machine output by sharing
   the same editable text buffer.
2. Complete control over context. I'm often frustrated by a chat where editing
   a query is harder than just appending a new one, leading to previous wrong
   replies polluting the context, wasting tokens, and slowing down responses.
   Optionally mark lines as relevant context with `<leader>m`. Then, use visual
   selection to designate the query and send with `<leader>c`.
3. Does a lot less than other tools (e.g. Cursor), but more than you'd expect
   with just ~150 loc. There's tons of functionality "for free" by being
   embedded in a powerful text editor.
4. Allows for easy "folk tools" along the lines of the Acme text editor by
   toggling lines in and out of context with ease, akin to incantations.

```lua
require('palimpsest').setup({

  -- LLM setup
  api_key = os.getenv("ANTHROPIC_API_KEY"),
  model = "claude-3-5-sonnet-latest",
  system = "Be concise and direct in your responses. Respond without unnecessary explanation.",
  
  -- Visual display of context markers
  signs = {
    context = "∙",
    highlight = "DiagnosticInfo"
  },
  
  -- Keymap for marking context and querying
  keymaps = {
    mark = "<leader>m",
    ask = "<leader>c",
  }
})
```
