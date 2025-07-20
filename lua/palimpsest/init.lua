local utils = require('palimpsest.utils')
local patch = require('palimpsest.patch')

local M = {}

M.config = {
  model = "anthropic/claude-3-haiku-20240307",
  system = "Be concise and direct in your responses. Respond without unnecessary explanation.",

  signs = {
    context  = "∙",
    add      = "+",
    delete   = "-",
    accepted = "✓",
  },

  keymaps = {
    mark     = "<leader>cm",  -- add line to context
    ask      = "<leader>cc",  -- ask visually selected question, append response
    review   = "<leader>cr",  -- ask visually selected question, review response diff 
    accept   = "<leader>ca",  -- accept diff proposal
    decline  = "<leader>cd",  -- decline diff proposal
    finalize = "<leader>cf"   -- finalize review
  }
}

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
  local first, final = utils.get_selection()
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

  -- Combine visual selection with context blocks
  local first, final = utils.get_selection()
  local lines = vim.fn.getline(first, final)
  local selection = table.concat(lines, "\n")

  local contexts = collect()
  local content = contexts .. selection

  -- What is this?
  vim.notify("Querying " .. M.config.model .. "...")

  local cmd = {
    "llm", "--no-stream",
    "-m", M.config.model,
    "-s", M.config.system
  }
  local result = vim.system(cmd, { stdin = content, text = true }):wait()
  local claude_lines = vim.split(result.stdout, "\n")

  if mode == 'append' then
    vim.fn.append(final, claude_lines)
  elseif mode == 'review' then
    local original_lines = vim.split(selection, "\n")
    patch.review(original_lines, claude_lines, first, final)
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  local signs = M.config.signs
  vim.fn.sign_define("claude_context", { text = signs.context, texthl = "DiagnosticInfo" })

  local keymaps = M.config.keymaps
  vim.keymap.set({'v', 'n'}, keymaps.ask,    M.ask)
  vim.keymap.set({'v', 'n'}, keymaps.review, function() M.ask('review') end)
  vim.keymap.set({'v', 'n'}, keymaps.mark,   M.mark)
  
  patch.setup(M.config)
end

return M
