local cache = require('antelope.cache')
local handles = require('antelope.buffers.handles')
local helpers = require('antelope.helpers')
local read = require('antelope.buffers.read')
local sort = require('antelope.buffers.sort')
local util = require('antelope.util')
local buffer_util = require('antelope.buffers.util')

local auto_handles = require('antelope.buffers.constant').auto_handles

local assign_auto_handles = handles.assign_auto_handles
local read_many = read.read_many
local read_one = read.read_one
local notify = helpers.notify

local insert = table.insert
local f = string.format

local M = {}

M.options = require('antelope.buffers.options')

local state_to_handle_hl = setmetatable({
  ['DELETING'] = 'AntelopeHandleDelete',
  ['SPLITTING'] = 'AntelopeHandleSplit',
}, {
  __index = function()
    return 'AntelopeHandleBuffer'
  end,
})

function M.component(state)
  local buffer = state.data
  local ctx = state.ctx
  local is_current = buffer.bufnr == vim.api.nvim_get_current_buf()

  local parts = {}

  if ctx.marker_present then
    local marker = buffer.previous_marker or { ' ', 'Normal' }

    insert(parts, { f(' %s', marker[1]), marker[2] })
  end

  local pad = string.rep(' ', ctx.max_handle_length - #buffer.handle + 1)

  insert(parts, { f(' %s%s', buffer.handle, pad), state_to_handle_hl[ctx.state] })

  if ctx.state == 'SETTING_PRIORITY' then
    insert(parts, { f('%s ', buffer.priority or ' '), 'AntelopePriority' })
  end

  if ctx.options.show_icons and buffer.icon then
    insert(parts, { f('%s ', buffer.icon[1]), buffer.icon[2] })
  end

  local tail_hl = 'AntelopeTail'

  if state.exact then
    tail_hl = 'AntelopeMatchExact'
  elseif is_current then
    tail_hl = 'AntelopeCurrent'
  end

  insert(parts, { f('%s ', buffer.tail), tail_hl })

  if ctx.options.show_modified and buffer.modified then
    insert(parts, { f('%s ', ctx.options.modified_icon), 'AntelopeModifiedIndicator' })
  end

  if buffer.deduped > 0 then
    local sp = buffer.split_path
    local dir = table.concat(sp, '/', #sp - buffer.deduped, #sp - 1)

    insert(parts, { f(' · /%s ', dir), 'AntelopeDirectory' })
  end

  if state.grayout or (is_current and ctx.options.grayout_current and ctx.state == 'OPEN') then
    for _, part in pairs(parts) do
      part[2] = 'AntelopeGrayOut'
    end
  end

  return parts
end

local function target_state(input, actions)
  local r = util.replace_termcodes

  if input == r(actions.delete) then
    return 'DELETING'
  end

  if vim.tbl_contains({ r(actions.split), r(actions.vertsplit), r(actions.tabsplit) }, input) then
    return 'SPLITTING'
  end

  if input == r(actions.priority) then
    return 'SETTING_PRIORITY'
  end

  return 'SWITCHING'
end

local function set_grayout(entries, matches)
  matches = vim.tbl_map(function(entry)
    return entry.data.bufnr
  end, matches)

  util.for_each(function(entry)
    entry:set_state({ grayout = not vim.tbl_contains(matches, entry.data.bufnr) })
  end, entries)
end

local function hide_current()
  local current = vim.api.nvim_get_current_buf()

  return function(entry)
    return entry.data.bufnr ~= current
  end
end

M.machine = {
  initial = 'OPEN',
  state = {
    CLOSED = {
      hooks = {
        on_enter = function(self)
          self.ctx.picker:close()
        end,
      },
    },
    OPEN = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          picker:set_ctx({ state = self.current })
          picker:render(not self.ctx.options.show_current and hide_current() or nil)

          local input = util.pgetcharstr()

          if not input then
            return self:transition('CLOSED')
          end

          self.ctx.state = {
            input = input,
          }

          self:transition(target_state(self.ctx.state.input, self.ctx.options.actions))
        end,
      },
      targets = { 'SWITCHING', 'DELETING', 'SPLITTING', 'SETTING_PRIORITY', 'CLOSED' },
    },
    SWITCHING = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          local match = read_one(picker.entries, {
            input = self.ctx.state.input,
            on_input = function(matches, exact)
              if exact then
                exact:set_state({ exact = true })
              end

              if self.ctx.options.grayout then
                set_grayout(picker.entries, matches)
              end

              picker:render(not self.ctx.options.show_current and hide_current() or nil)
            end,
          })

          if match then
            buffer_util.switch_buf(match.data)
          end

          self:transition('CLOSED')
        end,
      },
      targets = { 'CLOSED' },
    },
    DELETING = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          picker:set_ctx({ state = self.current })
          picker:render()

          if self.ctx.options.handle == 'bufnr' then
            local matches = read_many(picker.entries)

            if not matches then
              return self:transition('OPEN')
            end

            picker:close()

            local count = 0
            local unsaved

            for _, match in pairs(matches) do
              local status = pcall(vim.api.nvim_command, match.data.delete_command)

              if status then
                count = count + 1
                picker:remove('bufnr', match.data.bufnr)
              elseif not unsaved then
                unsaved = match.data
              end
            end

            vim.api.nvim_command('redraw')

            notify(string.format('%s buffer%s deleted', count, count > 1 and 's' or ''), vim.log.levels.INFO)

            if unsaved then
              notify('Save your changes first\n', vim.log.levels.ERROR, true)
              buffer_util.switch_buf(unsaved)
            else
              return self:transition('OPEN')
            end
          else
            local match

            repeat
              local input = util.pgetcharstr()

              if not input then
                return self:transition('CLOSED')
              end

              if input == util.replace_termcodes(self.ctx.options.actions.delete) and #picker.entries > 1 then
                return self:transition('OPEN')
              end

              match = read_one(picker.entries, { input = input })

              if match then
                if match.data.bufnr == vim.api.nvim_get_current_buf() then
                  picker:close()
                end

                local status = pcall(vim.api.nvim_command, match.data.delete_command)

                if status then
                  picker:remove('bufnr', match.data.bufnr)
                else
                  notify('Save your changes first', vim.log.levels.ERROR, true)
                  break
                end

                if #picker.entries == 0 then
                  break
                end

                picker:render()
              end

            until not match
          end

          self:transition('CLOSED')
        end,
      },
      targets = { 'CLOSED', 'OPEN' },
    },
    SPLITTING = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          picker:set_ctx({ state = self.current })
          picker:render()

          local match = read_one(picker.entries, {
            on_input = function(matches, exact)
              if exact then
                exact:set_state({ exact = true })
              end

              if self.ctx.options.grayout then
                set_grayout(picker.entries, matches)
              end

              picker:render()
            end,
          })

          if match then
            local action_to_command = {
              split = 'sbuffer',
              vertsplit = 'vertical sbuffer',
              tabsplit = 'tab sbuffer',
            }

            local action = util.find_key(function(value)
              return self.ctx.state.input == util.replace_termcodes(value)
            end, self.ctx.options.actions)

            buffer_util.split_buf(match.data, action_to_command[action])
          end

          self:transition('CLOSED')
        end,
      },
      targets = { 'CLOSED' },
    },
    SETTING_PRIORITY = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker
          local options = self.ctx.options

          if options.handle ~= 'auto' then
            notify(f('Not available for options.handle == "%s"', options.handle), vim.log.levels.WARN)
            return self:transition('CLOSED')
          end

          picker:set_ctx({ state = self.current })
          picker:render()

          local priorities = cache.get('auto_priority')

          local buffers = vim.tbl_map(function(entry)
            return entry.data
          end, picker.entries)

          while true do
            local match = read_one(picker.entries)

            if not match then
              break
            end

            match:set_state({ exact = true })
            match.data.priority = nil
            picker:render()

            local input = util.pgetcharstr()

            if not input then
              return self:transition('CLOSED')
            end

            match:set_state({ exact = false })

            priorities = vim.tbl_filter(function(item)
              return item.name ~= match.data.name and item.priority ~= input
            end, priorities)

            if vim.tbl_contains(auto_handles, input) then
              table.insert(priorities, { name = match.data.name, priority = input })
            end

            cache.set('auto_priority', priorities)

            buffers = sort.sort_priority(buffers, { sort = options.sort })

            assign_auto_handles(
              buffers,
              { auto_handles = options.auto_handles, auto_exclude_handles = options.auto_exclude_handles }
            )

            table.sort(picker.entries, function(a, b)
              return util.index_of(a.data.handle, options.auto_handles)
                < util.index_of(b.data.handle, options.auto_handles)
            end)

            picker:render()
          end

          self:transition('CLOSED')
        end,
      },
      targets = { 'CLOSED' },
    },
  },
}

function M.buffers()
  local bufs = vim.api.nvim_list_bufs()
  bufs = vim.tbl_filter(function(buf)
    local is_loaded = vim.api.nvim_buf_is_loaded(buf)
    local is_listed = vim.fn.buflisted(buf) == 1

    if not (is_loaded and is_listed) then
      return false
    end

    return true
  end, bufs)
  local count = 0
  for _, buf in pairs(bufs) do
    count = count + 1
  end
  return count
end

return M
