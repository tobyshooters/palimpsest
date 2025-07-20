local M = {}

function M.get_selection()
  local first, final = vim.fn.line('.'), vim.fn.line('.')
  if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
    first = vim.fn.line('v')
  end
  return math.min(first, final), math.max(first, final)
end

return M
