local module = {}

local group_to_fg_group = {
  AntelopeBorder = 'Comment',
  AntelopeDirectory = 'Directory',
  AntelopeModifiedIndicator = 'String',
  AntelopeHandleBuffer = 'String',
  AntelopeHandleDelete = 'Error',
  AntelopeHandleSplit = 'Directory',
  AntelopeTail = 'Normal',
  AntelopeHandleMarkLocal = 'Type',
  AntelopeHandleMarkGlobal = 'Number',
  AntelopeMark = 'Normal',
  AntelopeMarkLocation = 'Comment',
  AntelopeHandleTabpage = 'TabLineSel',
  AntelopeGrayOut = 'Comment',
  AntelopeMatchExact = 'String',
  AntelopePriority = 'Special',
  AntelopeCurrent = 'Title',
}

local highlights = {}

local function get_attr(group, attr)
  return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(group)), attr)
end

function module.setup()
  for group, fg_group in pairs(group_to_fg_group) do
    table.insert(highlights, { name = group, fg = fg_group })
  end

  module.reset()

  vim.api.nvim_command('autocmd ColorScheme * lua require("antelope.highlights").reset()')
end

function module.reset()
  for _, definition in pairs(highlights) do
    local fg = get_attr(definition.fg, 'fg')
    local bg = get_attr('Normal', 'bg')

    vim.api.nvim_command(string.format('hi! default %s guifg=%s guibg=%s gui=%s', definition.name, fg, bg, 'NONE'))
  end
end

return module
