vim.api.nvim_create_user_command("Renamer", function()
  require("file-renamer").start()
end, {})

vim.api.nvim_create_user_command("Ren", function()
  require("file-renamer").perform_rename()
end, {})
