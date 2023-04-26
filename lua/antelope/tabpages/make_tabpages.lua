local Tab = require('antelope.tabpages.tabpage')

return function(_)
  return vim.tbl_map(function(tabnr)
    return Tab:new(tabnr)
  end, vim.api.nvim_list_tabpages())
end
