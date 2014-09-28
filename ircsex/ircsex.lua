--[[
  IRCSEx IRC library
  Copyright (C) 2014 SoniEx2

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  ]]

-- copy _ENV so we can mess with it
local _ENV = _ENV
do
  local function check(obj, todo, copies, skip)
    if skip then return obj end
    if copies[obj] ~= nil then
      return copies[obj]
    elseif type(obj) == "table" then
      local t = {}
      todo[obj] = t
      copies[obj] = t
      return t
    end
    return obj
  end
  local function deep(inp, copies, nokeys)
    local out, todo = {}, {}
    copies = copies or {}
    todo[inp], copies[inp] = out, out

    -- we can't use pairs() here because we modify todo
    while next(todo) do
      local i, o = next(todo)
      todo[i] = nil
      for k, v in next, i do
        rawset(o, check(k, todo, copies, nokeys), check(v, todo, copies))
      end
    end
    return out
  end
  -- remove the space between "--" and "[[" to disable copy verification
  -- insert  a  space between "--" and "[[" to  enable copy verification
  -- THIS IS SLOW!
  --[[
  function deepcompare(table1, table2)
    local avoid_loops = {}
    local function recurse(t1, t2)
      -- compare value types
      if type(t1) ~= type(t2) then return false end
      -- Base case: compare simple values
      if type(t1) ~= "table" then return t1 == t2 end
      -- Now, on to tables.
      -- First, let's avoid looping forever.
      if avoid_loops[t1] then return avoid_loops[t1] == t2 end
      avoid_loops[t1] = t2
      -- Copy keys from t2
      local t2keys = {}
      local t2tablekeys = {}
      for k, _ in pairs(t2) do
        if type(k) == "table" then table.insert(t2tablekeys, k) end
        t2keys[k] = true
      end
      -- Let's iterate keys from t1
      for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if type(k1) == "table" then
          -- if key is a table, we need to find an equivalent one.
          local ok = false
          for i, tk in ipairs(t2tablekeys) do
            if deepcompare(k1, tk) and recurse(v1, t2[tk]) then
              table.remove(t2tablekeys, i)
              t2keys[tk] = nil
              ok = true
              break
            end
          end
          if not ok then return false end
        else
          -- t1 has a key which t2 doesn't have, fail.
          if v2 == nil then return false end
          t2keys[k1] = nil
          if not recurse(v1, v2) then return false end
        end
      end
      -- if t2 has a key which t1 doesn't have, fail.
      if next(t2keys) then return false end
      return true
    end
    return recurse(table1, table2)
  end
  --]]
  local env = deep(_ENV, {}, true)
  -- keep package.*
  env.package = _ENV.package
  -- force GC
  collectgarbage()
  if deepcompare then assert(deepcompare(old,new)) end
  _ENV = env
end

-- start of tweaks

do
  local olderror = error
  error = function(s, e, ...)
    s = s:format(...)
    if not e then
      error(s, 2)
    elseif e == 0 then
      error(s, 0)
    else
      error(s, 1+e)
    end
  end
end
-- start of IRC library

local socket = require("socket")
local ssl
do
  local s,e = pcall(require,"ssl")
  if s then ssl = e end
end

local M = {}

local connectionMetatable = {}

function connectionMetatable:start()
  local f = self.step
  local status, err = f(self)
  while status do
    status, err = f(self)
  end
  return status, err
end

function connectionMetatable:step()
  local mainThreadPool = self.mainThreadPool
  local eventQueue = self.eventQueue
  local event = table.remove(eventQueue) -- pop
  if not event then
    return false, "No events available"
  end
  local threads = mainThreadPool.threads
  local events = mainThreadPool.events
  local i = 1
  if not threads[i] then
    return false, "All threads finished execution normally."
  end
  while threads[i] do
    if coroutine.status(threads[i]) == "dead" then
      table.remove(threads,i)
      table.remove(events,i)
    else
      if event.name == events[i] then
        local status, msg = coroutine.resume(threads[i], self, event.name, table.unpack(event, 1, event.n))
        if not status then
          local thread = threads[i]
          table.remove(threads,i)
          table.remove(events,i)
          error("Error running coroutine.\n%s\n%s", debug.traceback(), debug.traceback(thread):gsub("^stack traceback:", "caused by:"))
        else
          events[i] = msg
        end
      end
      i = i + 1
    end
  end
  return true
end

-- for inter-coroutine stuff
function connectionMetatable:pushEvent(name, ...)
  local evt = table.pack(...)
  evt.name = name
  table.insert(self.eventQueue, evt)
end

-- handlers

local handlers = {}

function handlers.socketHandler(connection, event, ...)
  while true do
    local s = connection.socket
    -- TODO
  end
end

local setmetatable = function(t, mt)
  if mt == connectionMetatable then
    -- init basic stuff
    t.mainThreadPool = {threads={}, events={}}
    t.eventQueue = {}
  end
  return setmetatable(t, mt)
end

function M.open(to)
  local t
  if type(to) == "string" then
    t = setmetatable({}, connectionMetatable)
    local a, b, address = to:find("^irc://([%w.]+):?")
    if address then
      local c = to:find("/", b+1)
      local port = tonumber(to:sub(b+1, c-1)) or 6667
      -- TODO
    else
      a, b, address = to:find("([%w.]+)/")
      -- TODO
    end
  elseif type(to) == "table" then
    -- TODO
  else
    -- TODO check for socket
    error("Expected string or table for argument #1")
  end
end

return M