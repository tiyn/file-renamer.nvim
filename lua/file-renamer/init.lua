local M = {}

local hashes = "### "

local header = {
  "Renamer: change names then give command :Ren\n",
}

local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local ns = vim.api.nvim_create_namespace("renamer_icons")

local function strip_indent(line)
  return (line:gsub("^%s+", ""))
end

local function add_indent(line)
  return "  " .. line
end

local function get_file_icon(name)
  if not has_devicons then
    return "", "Normal"
  end

  local icon, hl = devicons.get_icon(name, nil, { default = true })
  return icon or "", hl or "Normal"
end

local function is_editable_entry_line(line)
  return line ~= "" and not line:match("^#")
end

local function clear_icons(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

local function render_icons(buf)
  clear_icons(buf)

  if not has_devicons or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for i, line in ipairs(lines) do
    if is_editable_entry_line(line) then
      local clean = strip_indent(vim.trim(line))
      local icon, hl = "", "Normal"

      if clean:sub(-1) == "/" then
        icon, hl = "", "Directory"
      else
        icon, hl = get_file_icon(clean)
      end

      if icon ~= "" then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
          virt_text = { { icon .. " ", hl } },
          virt_text_win_col = 0,
        })
      end
    end
  end
end

local function setup_autocmd(buf)
  local group = vim.api.nvim_create_augroup("RenamerIcons_" .. buf, { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        render_icons(buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    buffer = buf,
    callback = function()
      local pos = vim.api.nvim_win_get_cursor(0)
      local row, col = pos[1], pos[2]

      local line = vim.api.nvim_get_current_line()

      if is_editable_entry_line(line) and col < 2 then
        vim.api.nvim_win_set_cursor(0, { row, 2 })
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

function M.start(start_dir, cursor_line)
  vim.cmd("enew")

  local buf = vim.api.nvim_get_current_buf()
  local cwd = start_dir or vim.fn.getcwd()
  vim.b.rename_cwd = cwd

  local files = vim.fn.readdir(cwd)

  local dirs, normal_files = {}, {}

  for _, f in ipairs(files) do
    if not f:match("^%.") then
      local full = cwd .. "/" .. f
      if vim.fn.isdirectory(full) == 1 then
        dirs[#dirs + 1] = f
      else
        normal_files[#normal_files + 1] = f
      end
    end
  end

  table.sort(dirs)
  table.sort(normal_files)

  local ordered = {}
  for _, d in ipairs(dirs) do
    ordered[#ordered + 1] = d
  end
  for _, f in ipairs(normal_files) do
    ordered[#ordered + 1] = f
  end

  vim.b.rename_original_names = ordered

  local lines = {}

  for _, line in ipairs(header) do
    lines[#lines + 1] = hashes .. line:gsub("\n", "")
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = hashes .. "Currently editing: " .. cwd .. "/*"
  lines[#lines + 1] = "# ../"

  for _, d in ipairs(dirs) do
    lines[#lines + 1] = add_indent(d .. "/")
  end
  for _, f in ipairs(normal_files) do
    lines[#lines + 1] = add_indent(f)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false

  vim.keymap.set("n", "<CR>", M.enter, { buffer = true, silent = true })

  setup_autocmd(buf)
  render_icons(buf)

  local line_count = vim.api.nvim_buf_line_count(buf)
  local target_line = cursor_line or (#header + 3)

  if target_line < 1 then
    target_line = 1
  end
  if target_line > line_count then
    target_line = line_count
  end

  vim.api.nvim_win_set_cursor(0, { target_line, 2 })

  vim.cmd("syntax clear")
  vim.cmd([[syntax match RenameComment "^#.*"]])
  vim.cmd([[syntax match RenameDirectory "^\s*[^#].*/$"]])
  vim.cmd([[syntax match RenameFile "^\s*[^#].*[^/]$"]])

  vim.cmd("highlight default link RenameComment Comment")
  vim.cmd("highlight default link RenameDirectory Constant")
  vim.cmd("highlight default link RenameFile Function")
end

function M.restore_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local cwd = vim.b.rename_cwd
  local original = vim.b.rename_original_names or {}

  local dirs, files = {}, {}

  for _, name in ipairs(original) do
    local full = cwd .. "/" .. name
    if vim.fn.isdirectory(full) == 1 then
      dirs[#dirs + 1] = name
    else
      files[#files + 1] = name
    end
  end

  table.sort(dirs)
  table.sort(files)

  local lines = {}

  for _, line in ipairs(header) do
    lines[#lines + 1] = hashes .. line:gsub("\n", "")
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = hashes .. "Currently editing: " .. cwd .. "/*"
  lines[#lines + 1] = "# ../"

  for _, d in ipairs(dirs) do
    lines[#lines + 1] = add_indent(d .. "/")
  end
  for _, f in ipairs(files) do
    lines[#lines + 1] = add_indent(f)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  render_icons(buf)
end

function M.enter()
  local line = vim.api.nvim_get_current_line()
  local cwd = vim.b.rename_cwd

  if line == "# ../" then
    M.start(vim.fn.fnamemodify(cwd, ":h"))
    return
  end

  local clean = strip_indent(line)

  if clean:sub(-1) == "/" then
    M.start(cwd .. "/" .. clean:gsub("/$", ""))
  end
end

function M.perform_rename()
  local cwd = vim.b.rename_cwd
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local new_names = {}
  for _, line in ipairs(lines) do
    if not line:match("^#") and line ~= "" then
      local clean = strip_indent(vim.trim(line)):gsub("/$", "")
      new_names[#new_names + 1] = clean
    end
  end

  local old_names = vim.b.rename_original_names or {}

  if #old_names ~= #new_names then
    print("Mismatch in file count!")
    M.restore_buffer()
    return
  end

  local target_count = {}
  for _, new in ipairs(new_names) do
    target_count[new] = (target_count[new] or 0) + 1
  end

  local moving_old_paths = {}
  for i, old in ipairs(old_names) do
    local new = new_names[i]
    if old ~= new then
      moving_old_paths[vim.fn.simplify(cwd .. "/" .. old)] = true
    end
  end

  local ops = {}

  for i, old in ipairs(old_names) do
    local new = new_names[i]

    if old ~= new then
      if target_count[new] ~= 1 then
        print("Skipping duplicate target:", new)
      else
        local old_path = vim.fn.simplify(cwd .. "/" .. old)
        local new_path = vim.fn.simplify(cwd .. "/" .. new)

        local exists = vim.fn.filereadable(new_path) == 1 or vim.fn.isdirectory(new_path) == 1

        local occupied_by_moving_source = moving_old_paths[new_path] == true

        if exists and not occupied_by_moving_source then
          print("Target exists, skipping:", new)
        else
          ops[#ops + 1] = {
            index = i,
            old = old,
            new = new,
            old_path = old_path,
            new_path = new_path,
          }
        end
      end
    end
  end

  for _, op in ipairs(ops) do
    op.tmp = cwd .. "/" .. op.index .. "_RENAMER_TMP_"

    local ok = os.rename(op.old_path, op.tmp)
    if not ok then
      print("Failed temp rename:", op.old)
      op.failed = true
    end
  end

  for _, op in ipairs(ops) do
    if not op.failed then
      local new_dir = vim.fn.fnamemodify(op.new_path, ":h")
      if vim.fn.isdirectory(new_dir) == 0 then
        vim.fn.mkdir(new_dir, "p")
      end
    end
  end

  for _, op in ipairs(ops) do
    if not op.failed then
      local ok = os.rename(op.tmp, op.new_path)
      if not ok then
        print("Failed final rename:", op.new)

        local rollback_ok = os.rename(op.tmp, op.old_path)
        if not rollback_ok then
          print("CRITICAL: rollback failed for:", op.old)
        end
      end
    end
  end

  print("Rename done")
  M.start(cwd)
end

return M
