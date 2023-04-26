local Entry = require('antelope.picker.entry')
local Machine = require('antelope.machine')
local Picker = require('antelope.picker.picker')
local cache = require('antelope.cache')
local config = require('antelope.config')
local helpers = require('antelope.helpers')
local highlights = require('antelope.highlights')
local util = require('antelope.util')
local buffer_util = require('antelope.buffers.util')

local notify = helpers.notify

local buffers = require('antelope.buffers')
local marks = require('antelope.marks')
local tabpages = require('antelope.tabpages')

local make_buffers = require('antelope.buffers.make_buffers')
local make_marks = require('antelope.marks.make_marks')
local make_tabpages = require('antelope.tabpages.make_tabpages')

local module = {}

function module.setup(cfg)
  config.setup(cfg)
  highlights.setup()
  cache.setup()
end

function module.tabpages(options)
  options = tabpages.options.extend(options)

  local tabs = make_tabpages(options)

  if not options.show_current and #tabs < 2 then
    return notify('Only one tab')
  end

  local machine = Machine:new(tabpages.machine)

  local entries = vim.tbl_map(function(tabpage)
    return Entry:new({
      component = tabpages.component,
      data = tabpage,
    })
  end, tabs)

  machine.ctx = {
    picker = Picker:new(entries),
    options = options,
  }

  machine:init()
end

function module.buffers(options)
  options = buffers.options.extend(options)

  local bufs = make_buffers(options)

  local count = #bufs

  if not options.show_current then
    local current = vim.api.nvim_get_current_buf()
    count = util.count(function(buffer)
      return buffer.bufnr ~= current
    end, bufs)
  end

  if count < 1 then
    return notify('Only one buffer')
  end

  local entries = vim.tbl_map(function(buffer)
    return Entry:new({
      component = buffers.component,
      data = buffer,
    })
  end, bufs)

  local picker = Picker:new(entries)

  local max_handle_length = 0
  local marker_present = false

  for _, buffer in pairs(bufs) do
    if #buffer.handle > max_handle_length then
      max_handle_length = #buffer.handle
    end

    if buffer.previous_marker then
      marker_present = true
    end
  end

  picker:set_ctx({
    options = options,
    marker_present = marker_present,
    max_handle_length = max_handle_length,
  })

  local machine = Machine:new(buffers.machine)

  machine.ctx = {
    picker = picker,
    options = options,
  }

  machine:init()
end

function module.marks(options)
  options = marks.options.extend(options)

  local mrks = make_marks(options)

  if #mrks == 0 then
    vim.api.nvim_command('redraw')
    return notify('No marks')
  end

  local machine = Machine:new(marks.machine)

  local entries = vim.tbl_map(function(mark)
    return Entry:new({
      component = marks.component,
      data = mark,
    })
  end, mrks)

  machine.ctx = {
    picker = Picker:new(entries),
    options = options,
  }

  machine:init()
end

function module.switch_to_buffer(n, options)
  local bufs = make_buffers(buffers.options.extend(options))
  if bufs[n] then
    buffer_util.switch_buf(bufs[n])
  end
end

return module
