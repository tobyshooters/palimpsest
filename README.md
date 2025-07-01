# Palimpsest

![demo](https://raw.githubusercontent.com/tobyshooters/palimpsest/master/assets/translate.gif)

A dead-simple Claude interface for Neovim.

1. Replaces "chat" metaphor with a palimpsest—layers of writing, on top of
   each other. No distinction between user input and machine output by sharing
   the same editable text buffer.
2. Complete control over context. I'm often frustrated by a chat where editing
   a query is harder than just appending a new one, leading to previous wrong
   replies polluting the context, wasting tokens, and slowing down responses.
   Optionally mark lines as relevant context with `<leader>cm`. Then, select the
   query and send with `<leader>cc`.
3. Does a lot less than other tools (e.g. Cursor), but more than you'd expect
   with just ~150 loc. There's tons of functionality "for free" by being
   embedded in a powerful text editor.
4. Allows for easy "folk tools" along the lines of the Acme text editor by
   toggling lines in and out of context with ease, akin to incantations.
5. Simple patch review mode with inline diffs.


### Configuation

```lua
require('palimpsest').setup({

  -- LLM setup
  api_key = os.getenv("ANTHROPIC_API_KEY"),
  model = "claude-3-5-sonnet-latest",
  system = "Be concise and direct in your responses. Respond without unnecessary explanation.",
  
  -- Display of context and line-by-line diff markers
  signs = {
    context  = "∙",
    add      = "+",
    delete   = "-",
    accepted = "✓",
  },
  
  keymaps = {
    -- Keymaps for core functionality
    ask      = "<leader>cc",  -- ask selected question, append response
    mark     = "<leader>cm",  -- add line to context
    
    -- Keymaps for patch review using diffs
    review   = "<leader>cr",  -- ask selected question, review response diff 
    accept   = "<leader>ca",  -- accept diff proposal
    decline  = "<leader>cd",  -- decline diff proposal
    finalize = "<leader>cf"   -- finalize review
  }
})
```

### Highlight groups

```vim
highlight DiagnosticInfo cterm=none ctermfg=4         ctermbg=none
highlight DiffAdd        cterm=none ctermfg=DarkGreen ctermbg=none
highlight DiffAddLine    cterm=none ctermfg=none      ctermbg=LightGreen
highlight DiffDelete     cterm=none ctermfg=DarkRed   ctermbg=none
highlight DiffDeleteLine cterm=none ctermfg=none      ctermbg=LightRed
```

### To Do

1. [bug] check for bug in indexing between patch.accepted and patch.lines
1. [polish] unify selection code between init.lua and patch.lua
1. [feature] support for local model
1. [feature] support for multiple API providers
