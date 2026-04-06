local M = {}

local hashes = "### "

local header = {
  "Renamer: change names then give command :Ren\n",
}

function M.start(start_dir, cursor_line)
  vim.cmd("enew")

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
  for _, d in ipairs(dirs) do ordered[#ordered + 1] = d end
  for _, f in ipairs(normal_files) do ordered[#ordered + 1] = f end

  vim.b.rename_original_names = ordered

  local lines = {}

  for _, line in ipairs(header) do
    lines[#lines + 1] = hashes .. line:gsub("\n", "")
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = hashes .. "Currently editing: " .. cwd .. "/*"
  lines[#lines + 1] = "# ../"

  for _, d in ipairs(dirs) do lines[#lines + 1] = d .. "/" end
  for _, f in ipairs(normal_files) do lines[#lines + 1] = f end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false

  vim.keymap.set("n", "<CR>", M.enter, { buffer = true, silent = true })

  if cursor_line then
    vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })
  else
    vim.api.nvim_win_set_cursor(0, { #header + 3, 0 })
  end

  vim.cmd("syntax clear")
  vim.cmd([[syntax match RenameComment "^#.*"]])
  vim.cmd([[syntax match RenameDirectory "^[^#].*/$"]])
  vim.cmd([[syntax match RenameFile "^[^#].*[^/]$"]])

  vim.cmd("highlight default link RenameComment Comment")
  vim.cmd("highlight default link RenameDirectory Constant")
  vim.cmd("highlight default link RenameFile Function")
end

function M.restore_buffer()
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

  for _, d in ipairs(dirs) do lines[#lines + 1] = d .. "/" end
  for _, f in ipairs(files) do lines[#lines + 1] = f end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function M.enter()
  local line = vim.api.nvim_get_current_line()
  local cwd = vim.b.rename_cwd

  if line == "# ../" then
    M.start(vim.fn.fnamemodify(cwd, ":h"))
    return
  end

  if line:sub(-1) == "/" then
    M.start(cwd .. "/" .. line:gsub("/$", ""))
  end
end

function M.perform_rename()
  local cwd = vim.b.rename_cwd
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local new_names = {}
  for _, line in ipairs(lines) do
    if not line:match("^#") and line ~= "" then
      new_names[#new_names + 1] = vim.trim(line):gsub("/$", "")
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

  local target_set = {}
  for _, new in ipairs(new_names) do
    target_set[vim.fn.simplify(cwd .. "/" .. new)] = true
  end

  local ops = {}

  for i, old in ipairs(old_names) do
    local new = new_names[i]

    if old ~= new then
      if target_count[new] ~= 1 then
        print("Skipping duplicate target:", new)

      else
        local new_path = vim.fn.simplify(cwd .. "/" .. new)

        local exists = vim.fn.filereadable(new_path) == 1
          or vim.fn.isdirectory(new_path) == 1

        if exists and not target_set[new_path] then
          print("Target exists, skipping:", new)
        else
          ops[#ops + 1] = {
            index = i,
            old = old,
            new = new,
            old_path = cwd .. "/" .. old,
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
