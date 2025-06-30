local M = {}

function M.setup(config)
  local signs = config.signs
  local keymaps = config.keymaps
  
  -- Define patch signs
  vim.fn.sign_define('PatchAdd', { text = signs.add, texthl = signs.add_hl })
  vim.fn.sign_define('PatchDelete', { text = signs.delete, texthl = signs.delete_hl })
  vim.fn.sign_define('PatchEquals', { text = signs.equals, texthl = signs.equals_hl })
  vim.fn.sign_define('PatchAccepted', { text = signs.accepted, texthl = signs.accepted_hl })

  -- Setup patch keymaps
  vim.keymap.set('v', keymaps.accept, M.accept, { noremap = true, silent = true })
  vim.keymap.set('v', keymaps.reject, M.reject, { noremap = true, silent = true })
  vim.keymap.set('n', keymaps.finalize, M.finalize, { noremap = true, silent = true })
end

local state = {
  original_lines = {},
  new_lines      = {},
  diff_lines     = {},
  start_line     = 0,
  bufnr          = 0,
  signs          = {},
  accepted       = {},
}

local function parse_hunk_header(line)
  local old_start, new_start = line:match("@@ %-(%d+),?%d* %+(%d+),?%d* @@")
  return tonumber(old_start), tonumber(new_start)
end

local function parse_diff(original_lines, new_lines)
  -- Generate diff
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir)
  local orig_file = tmp_dir .. "/original"
  local new_file = tmp_dir .. "/new"
  
  vim.fn.writefile(original_lines, orig_file)
  vim.fn.writefile(new_lines, new_file)
  
  local diff_cmd = string.format("diff -u %s %s", vim.fn.shellescape(orig_file), vim.fn.shellescape(new_file))
  local diff = vim.fn.system(diff_cmd)
  
  vim.fn.delete(tmp_dir, "rf")

  -- Parse diff
  local diff_lines = {}
  local prefix_map = {['+'] = 'PatchAdd', ['-'] = 'PatchDelete', [' '] = 'PatchEquals'}

  -- Loop over diff, keeping track of where the line came from for easier resolution
  local old_idx, new_idx
  for _, line in ipairs(vim.split(diff, '\n')) do

    if line:match("^@@") then
      local old_start, new_start = parse_hunk_header(line)
      old_idx = old_start - 1
      new_idx = new_start - 1

    elseif old_idx and line ~= "" then
      local line_type = prefix_map[line:sub(1, 1)]
      if line_type then
        local orig_line_num, last_orig_line
        if line_type == 'PatchEquals' then
          old_idx = old_idx + 1
          new_idx = new_idx + 1
          orig_line_num = old_idx
          last_orig_line = old_idx
        elseif line_type == 'PatchDelete' then
          old_idx = old_idx + 1
          orig_line_num = old_idx
          last_orig_line = old_idx
        elseif line_type == 'PatchAdd' then
          new_idx = new_idx + 1
          orig_line_num = nil
          last_orig_line = old_idx
        end
        table.insert(diff_lines, {
          type = line_type, 
          text = line:sub(2), 
          orig_line_num = orig_line_num,
          last_orig_line = last_orig_line
        })
      end
    end
  end

  return diff_lines
end

local function clear_signs()
  vim.fn.sign_unplace('palimpsest_patch')
  state.signs = {}
end

local function update_signs()
  clear_signs()
  for i, line in ipairs(state.diff_lines) do
    local line_num = state.start_line + i - 1
    local sign_type = state.accepted[i] and 'PatchAccepted' or line.type
    local sign_id = vim.fn.sign_place(0, 'palimpsest_patch', sign_type, state.bufnr, { lnum = line_num })
    table.insert(state.signs, sign_id)
  end
end

local function get_visual_selection()
  local first = vim.fn.line('v')
  local final = vim.fn.line('.')
  first, final = math.min(first, final), math.max(first, final)
  
  -- Convert to relative indices within our diff
  local rel_first = math.max(1, first - state.start_line + 1)
  local rel_final = math.min(#state.diff_lines, final - state.start_line + 1)
  return rel_first, rel_final
end

function M.accept()
  local first, final = get_visual_selection()
  for i = first, final do
    state.accepted[i] = true
  end
  update_signs()
end

function M.reject()
  local first, final = get_visual_selection()
  for i = first, final do
    local line = state.diff_lines[i]
    if line and (line.type == "PatchAdd" or line.type == "PatchDelete") then
      state.accepted[i] = false
    end
  end
  update_signs()
end

function M.finalize()
  clear_signs()
end

function M.review_patch(original_lines, new_lines, start_line, end_line)
  state.original_lines = original_lines
  state.new_lines = new_lines
  state.start_line = start_line
  state.bufnr = vim.api.nvim_get_current_buf()
  
  state.diff_lines = parse_diff(state.original_lines, state.new_lines)
  if #state.diff_lines == 0 then
    return
  end
  
  state.accepted = {}
  for i, line in ipairs(state.diff_lines) do
    state.accepted[i] = line.type == 'PatchEquals'
  end

  local diff_text = vim.tbl_map(function(line) return line.text end, state.diff_lines)
  vim.api.nvim_buf_set_lines(state.bufnr, start_line - 1, end_line, false, diff_text)
  update_signs()
end

return M
