local util = require('antelope.util')

local strdisplaywidth = vim.fn.strdisplaywidth

local module = {}

local default = {
  show_icons = true,
  show_current = true,
  show_modified = true,
  modified_icon = "",
  grayout_current = true,
  force_delete = {},
  filter = nil,
  sort = nil,
  handle = 'auto',
  terminal_char = '\\',
  grayout = true,
  auto_handles = require('antelope.buffers.constant').auto_handles,
  auto_exclude_handles = {},
  previous = {
    enable = true,
    depth = 2,
    chars = { '•' },
    groups = { 'String', 'Comment' },
  },
  actions = {
    split = '-',
    vertsplit = '|',
    tabsplit = ']',
    delete = '<Space>',
    priority = '=',
  },
}

local function optional(predicate)
  return function(value)
    if not value then
      return true
    end
    return predicate(value)
  end
end

local function one_of(values)
  return function(value)
    return type(values) == 'table' and vim.tbl_contains(values, value), 'one of: ' .. table.concat(values, ', ')
  end
end

local function width(w)
  return function(value)
    return type(value) == 'string' and strdisplaywidth(value) == w, w .. ' column width string'
  end
end

local function every(predicate)
  return function(value)
    return type(value) == 'table' and util.every(predicate, value)
  end
end

local function validate(options)
  vim.validate({
    options = { options, 'table', true },
  })

  if options then
    local previous = options.previous
    local actions = options.actions

    vim.validate({
      show_icons = { options.show_icons, 'boolean', true },
      show_current = { options.show_current, 'boolean', true },
      show_modified = { options.show_modified, 'boolean', true },
      modified_icon = { options.modified_icon, 'string', true },
      grayout_current = { options.grayout_current, 'boolean', true },
      force_delete = { options.force_delete, 'table', true },
      filter = { options.filter, 'function', true },
      sort = { options.sort, 'function', true },
      handle = { options.handle, optional(one_of({ 'auto', 'dynamic', 'bufnr' })), 'auto, dynamic or bufnr' },
      terminal_char = { options.terminal_char, optional(width(1)), 'one column width character' },
      grayout = { options.grayout, 'boolean', true },
      auto_handles = { options.auto_handles, optional(every(width(1))), 'list of one column width characters' },
      auto_exclude_handles = {
        options.auto_exclude_handles,
        optional(every(width(1))),
        'list of one column width characters',
      },
      previous = { previous, 'table', true },
      actions = { actions, 'table', true },
    })

    if previous then
      vim.validate({
        enable = { previous.enable, 'boolean', true },
        depth = { previous.depth, 'number', true },
        chars = { previous.chars, optional(every(width(1))), 'list of one column width characters' },
        groups = {
          previous.groups,
          optional(every(function(value)
            return type(value) == 'string'
          end)),
          'list of highlight groups',
        },
      })
    end

    if actions then
      vim.validate({
        split = { actions.split, 'string', true },
        vertsplit = { actions.vertsplit, 'string', true },
        tabsplit = { actions.tabsplit, 'string', true },
        delete = { actions.delete, 'string', true },
        priority = { actions.priority, 'string', true },
      })
    end
  end
end

function module.extend(options)
  validate(options)
  return vim.tbl_deep_extend('force', default, options or {})
end

return module
