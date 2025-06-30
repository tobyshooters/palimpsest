local M = {}

-- Inject sibling modules
M.patch = require('palimpsest.patch')

M.config = {
  api_key = os.getenv("ANTHROPIC_API_KEY"),
  model = "claude-3-5-sonnet-latest",
  system = "Be concise and direct in your responses. Respond without unnecessary explanation.",
  signs = {
    context = "∙",
    context_hl = "DiagnosticInfo",
    add = "+",
    add_hl = "DiffAdd",
    delete = "-",
    delete_hl = "DiffDelete",
    equals = " ",
    equals_hl = "Comment",
    accepted = "✓",
    accepted_hl = "DiagnosticOk"
  },
  keymaps = {
    ask = "<leader>c",
    diff = "<leader>r",
    mark = "<leader>m",
    accept = "<leader>a",
    reject = "<leader>d",
    finalize = "<leader>f"
  }
}

function M.setup(opts)
  -- Initialize plugin with optional user config
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.fn.sign_define("claude_context", {
    text = M.config.signs.context,
    texthl = M.config.signs.context_hl
  })

  -- Setup key bindings
  vim.keymap.set('v', M.config.keymaps.ask, M.ask)
  vim.keymap.set('v', M.config.keymaps.diff, function() M.ask('diff') end)
  vim.keymap.set('v', M.config.keymaps.mark, M.mark)
  
  -- Setup patch module
  M.patch.setup(M.config)
end

local function get_visual_selection()
  local first = vim.fn.line('v')
  local final = vim.fn.line('.')
  return math.min(first, final), math.max(first, final)
end

local sign_id = 1

local function get_sign(bufnr, lnum)
  -- Helper to simplify sign mess
  local signs = vim.fn.sign_getplaced(bufnr, {group = "claude", lnum = lnum})
  if signs[1] and signs[1].signs and signs[1].signs[1] then
    return signs[1].signs[1].id
  end
  return nil
end

function M.mark()
  -- Mark visually selected lines of code as context
  local first, final = get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()

  local has_signs = false
  for line = first, final do
    if get_sign(bufnr, line) then
      has_signs = true
      break
    end
  end

  if has_signs then
    for line = first, final do
      local sign_id = get_sign(bufnr, line)
      if sign_id then
        vim.fn.sign_unplace("claude", {buffer = bufnr, id = sign_id})
      end
    end
  else
    for line = first, final do
      vim.fn.sign_place(sign_id, "claude", "claude_context", bufnr, {lnum = line})
      sign_id = sign_id + 1
    end
  end
end

local function collect()
  -- Collect all lines that have a context sign
  local bufnr = vim.api.nvim_get_current_buf()
  local signs = vim.fn.sign_getplaced(bufnr, {group = "claude"})
  if not signs[1] or not signs[1].signs then
    return ""
  end

  local context_lines = {}
  for _, sign in ipairs(signs[1].signs) do
    if sign.name == "claude_context" then
      table.insert(context_lines, sign.lnum)
    end
  end
  table.sort(context_lines)

  local contexts = ""
  for _, lnum in ipairs(context_lines) do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    contexts = contexts .. line .. "\n"
  end
  return contexts
end

function M.ask(mode)
  mode = mode or 'append'

  if not M.config.api_key then
    vim.notify("ANTHROPIC_API_KEY missing", vim.log.levels.ERROR)
    return
  end

  -- Combine visual selection with context blocks
  local first, final = get_visual_selection()
  local lines = vim.fn.getline(first, final)
  local selection = table.concat(lines, "\n")

  local contexts = collect()
  local content = contexts .. selection

  vim.notify("Querying Claude...")

  -- Send off to Anthropic
  local curl_cmd = {
    "curl", "-s", "-X", "POST",
    "https://api.anthropic.com/v1/messages",
    "-H", "content-type: application/json",
    "-H", "anthropic-version: 2023-06-01",
    "-H", "x-api-key: " .. M.config.api_key,
    "-d", vim.json.encode({
      model = M.config.model,
      max_tokens = 1024,
      system = M.config.system,
      messages = {{ role = "user", content = content }}
    })
  }

  -- Place output after visual buffer
  vim.fn.jobstart(curl_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local response = table.concat(data, "")
        local ok, parsed = pcall(vim.json.decode, response)
        if ok and parsed.content and parsed.content[1] then
          local claude_lines = vim.split(parsed.content[1].text, "\n")

          -- Append mode
          if mode == 'append' then
            vim.fn.append(final, claude_lines)

          -- Patch mode
          elseif mode == 'diff' then
            local original_lines = vim.split(selection, "\n")
            M.patch.review_patch(original_lines, claude_lines, first, final)
          end

        else
          vim.notify("Error with Claude: " .. response)
        end
      end
    end
  })
end

return M
