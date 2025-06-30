local M = {}

local state = {
  buf       = 0,  -- a reference to the Vim buffer
  start_idx = 0,  -- where the target selection starts
  lines     = {}, -- the patch lines and types (e.g. Add, Delete)
  accepted  = {}, -- toggle whether lines are accepted
}

local function compute_diff(original_lines, new_lines)
  local tmp_dir = vim.fn.tempname()
  local orig_file = tmp_dir .. "/original"
  local new_file = tmp_dir .. "/new"

  vim.fn.mkdir(tmp_dir)
  vim.fn.writefile(original_lines, orig_file)
  vim.fn.writefile(new_lines, new_file)
  local diff = vim.fn.system("diff -u " .. orig_file .. " " .. new_file)
  
  vim.fn.delete(tmp_dir, "rf")
  return diff
end

local function parse_and_apply_diff(diff, start_idx)
  local prefix_types = {['+'] = 'Add', ['-'] = 'Delete', [' '] = 'Equals'}

  local lines = {}      -- all lines for state
  local hunks = {}      -- lines by hunk for insertion
  local curr_hunk = nil -- current hunk being processsed
  
  for _, line in ipairs(vim.split(diff, '\n')) do
    if line:match("^@@") then
      local old_start = tonumber(line:match("@@ %-(%d+)"))
      local pos = start_idx + old_start - 2
      curr_hunk = { start_pos = pos, text = {}, src_count = 0 }
      table.insert(hunks, curr_hunk)
      
    elseif curr_hunk and line ~= "" then
      local line_type = prefix_types[line:sub(1, 1)]
      local pos = curr_hunk.start_pos + #curr_hunk.text + 1
      local text = line:sub(2)

      table.insert(lines, { type = line_type, text = line:sub(2), buf_idx = pos })
      table.insert(curr_hunk.text, text)

      if line_type ~= 'Add' then
        curr_hunk.src_count = curr_hunk.src_count + 1
      end
    end
  end
  
  for i = #hunks, 1, -1 do -- reverse order to avoid index shifting
    local hunk = hunks[i]
    vim.api.nvim_buf_set_lines(state.buf, hunk.start_pos, hunk.start_pos + hunk.src_count, false, hunk.text)
  end
  
  return lines
end

local function update_signs()
  vim.fn.sign_unplace('palimpsest_patch')
  vim.api.nvim_buf_clear_namespace(state.buf, -1, 0, -1) -- clear highlights

  for i, line in ipairs(state.lines) do
    if line.type == 'Add' or line.type == 'Delete' then
      local sign_type = state.accepted[i] and 'Accepted' or line.type
      vim.fn.sign_place(0, 'palimpsest_patch', sign_type, state.buf, { lnum = line.buf_idx })
      
      local hl_group = line.type == 'Add' and 'DiffAddLine' or 'DiffDeleteLine'
      vim.api.nvim_buf_add_highlight(state.buf, -1, hl_group, line.buf_idx - 1, 0, -1)
    end
  end
end

local function mark(bool)
  local first, final = vim.fn.line('.'), vim.fn.line('.')
  if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
    first = vim.fn.line('v')
  end
  first, final = math.min(first, final), math.max(first, final)

  for i = first, final do
    local idx = i - state.start_idx + 1
    state.accepted[idx] = bool
  end

  update_signs()
end

local function finalize()
  -- Tally lines that must be removed
  local indices = {}
  for i, line in ipairs(state.lines) do
    if (line.type == 'Add' and not state.accepted[i]) or 
       (line.type == 'Delete' and state.accepted[i]) 
    then
      table.insert(indices, line.buf_idx)
    end
  end
  table.sort(indices, function(a, b) return a > b end)
  
  -- Cluster consecutive indices, and remove as batch
  local s, e = indices[1], indices[1]
  for i = 2, #indices do
    if indices[i] ~= s - 1 then
      vim.api.nvim_buf_set_lines(state.buf, s - 1, e, false, {})
      e = indices[i]
    end
    s = indices[i]
  end
  vim.api.nvim_buf_set_lines(state.buf, s - 1, e, false, {})

  vim.fn.sign_unplace('palimpsest_patch')
  vim.api.nvim_buf_clear_namespace(state.buf, -1, 0, -1) -- clear highlights
end

function M.review(original_lines, new_lines, start_idx, end_line)
  state.buf = vim.api.nvim_get_current_buf()
  state.start_idx = start_idx

  local diff = compute_diff(original_lines, new_lines)
  local lines = parse_and_apply_diff(diff, start_idx)
  
  state.lines = lines
  state.accepted = {}
  update_signs()
end

function M.setup(config)
  local signs = config.signs
  local keymaps = config.keymaps
  
  vim.fn.sign_define('Add',      { text = signs.add,      texthl = "DiffAdd"        })
  vim.fn.sign_define('Delete',   { text = signs.delete,   texthl = "DiffDelete"     })
  vim.fn.sign_define('Accepted', { text = signs.accepted, texthl = "DiagnosticInfo" })

  vim.keymap.set({'v', 'n'}, keymaps.accept,   function() mark(true)  end)
  vim.keymap.set({'v', 'n'}, keymaps.decline,  function() mark(false) end)
  vim.keymap.set({'v', 'n'}, keymaps.finalize, finalize)
end

return M
