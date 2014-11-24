local M = {}

local coresume = coroutine.resume
local costatus = coroutine.status

local tpack = table.pack or function(...) return {n=select('#', ...), ...} end
local tunpack = table.unpack or unpack
local tremove = table.remove
local tinsert = table.insert

local sfmt = string.format

local trace = debug.traceback

-- unpack event `evt` as in `evt.name, evt[1], evt[2], ..., evt[evt.n]`
local function evtunpack(evt)
  return evt.name, tunpack(evt, 1, evt.n)
end

local function evtpack(name, ...)
  local t = tpack(...)
  t.name = name
  return t
end

local threadMetatable = {}

function threadMetatable:start()
  local f = self.step
  local status, err = f(self)
  while status do
    status, err = f(self)
  end
  return status, err
end

function threadMetatable:step()
  local threadPool = self.threadPool
  local eventQueue = self.eventQueue
  local event = tremove(eventQueue) -- pop
  if not event then
    return false, "No events available"
  end
  local threads = threadPool.threads
  local events = threadPool.events
  local i = 1
  local thread = threads[i]
  if not thread then
    return false, "All threads finished execution normally."
  end
  while thread do
    if costatus(thread) == "dead" then
      tremove(threads,i)
      tremove(events,i)
    else
      if event.name == events[i] then
        local status, msg = coresume(thread, self, evtunpack(event))
        if not status then
          local thread = thread
          tremove(threads,i)
          tremove(events,i)
          error(trace(thread, msg))
        else
          events[i] = msg
        end
      end
      i = i + 1
      thread = threads[i]
    end
  end
  return true
end

-- for inter-coroutine stuff
function threadMetatable:pushEvent(name, ...)
  tinsert(self.eventQueue, evtpack(name, ...))
end

function M.newPool()
  local t = setmetatable({}, threadMetatable)
  t.mainThreadPool = {threads={}, events={}}
  t.eventQueue = {}
  return t
end

return M