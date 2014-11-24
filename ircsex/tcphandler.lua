local tpack = table.pack or function(...) return {n=select('#', ...), ...} end

local M = {}

-- handlers

local handlers = {}

function handlers.socketHandler(session, event, ...)
  while true do
    local s = session.socket
    if event == ">RAW" then
      local x = tpack(...)
      local out = ""
      if x.n == 1 then
        out = x[1]
      else
        if x[x.n].find(" ") then
          x[x.n] = ":" .. x[x.n]
        end
        out = table.concat(x, " ", 1, x.n)
      end
      -- TODO send `out`
    end
    -- TODO receive
  end
end

M.handlers = handlers

return M