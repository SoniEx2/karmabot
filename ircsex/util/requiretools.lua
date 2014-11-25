local require = require

function makereqtools(bases)
  local M = {}

  local pack = table.pack or function(...) return {n=select('#',...),...} end

  local function req(name)
    -- TODO relative require
    -- that is, if in module "something", require"something.test" can be rewritten as req"test"
    local tlooked = {}
    for x,y in ipairs(bases) do
      local t=pack(pcall(require,name))
      if t[1] then
        return (unpack or table.unpack)(t,2,t.n)
      else
        table.insert(tlooked, t[2])
      end
    end
    error(table.concat(tlooked, "\n"))
  end

  M.req = req

  local function opt(name)
    local s,m = pcall(req,name)
    if s then
      return m
    else
      return nil
    end
  end

  M.opt = opt

  return M
end

local rawset = rawset

local _modname, _modpath = ...

local weakcache = setmetatable({}, {__mode="kv"})

-- monkeypatch package.loaded for fancy relative require to work

local reqmt = {
  __index = function(t,k)
    if k == _modname then
      -- TODO do stuff
      return "HEY LOOK I CAN MONKEYPATCH package.loaded"
    end
  end,
  __newindex = function(t,k,v,f) -- yep, we add an 'f' that's not used by normal calling
    print(t,k,v)
    if k  ~= _modname then
      (f or rawset)(t,k,v)
    else
      -- ignore
    end
  end
}

local oldmt = getmetatable(package.loaded)
if oldmt then
  local oldindex = oldmt.__index
  local oldnewindex = oldmt.__newindex
  oldmt.__index = function(t,k)
    local x = reqmt.__index(t,k)
    if x then
      return x
    elseif oldindex then
      return oldindex(t,k)
    end
  end
  oldmt.__newindex = function(t,k,v)
    reqmt.__newindex(t,k,v,oldnewindex) -- heh
  end
else
  setmetatable(package.loaded,reqmt)
end

-- TODO turn this into the proper code
-- this is only here to avoid UB
return makereqtools({})