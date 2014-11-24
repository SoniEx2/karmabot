local next,type,rawset,setmetatable = next,type,rawset,setmetatable

local gmt = debug and debug.getmetatable or getmetatable

local function getmetamethod(obj, name)
  local mt = gmt(obj)
  if type(mt) == "table" then
    local f = mt[name]
    if type(f) == "function" then
      return f
    else
      return nil
    end
  end
end

local function tryinvokemeta(obj, name, ...)
  local x = getmetamethod(obj, name)
  if x then
    return pcall(x, obj, ...)
  else
    return false, "Metamethod " .. name .. " not found"
  end
end

local M = {}

do
-- deepcopy for long tables
  local function deep_mode1(inp, copies, nokeys)
    local status, c = tryinvokemeta(inp, "__copy")
    if status then
      if copies then
        copies[inp] = c
      end
      return c
    elseif type(inp) ~= "table" then
      return inp
    end
    local out = {}
    copies = (type(copies) == "table") and copies or {}
    copies[inp] = out
    for key,value in next,inp do
      if nokeys then
        rawset(out,key,copies[value] or deep_mode1(value,copies))
      else
        rawset(out,copies[key] or deep_mode1(key,copies),copies[value] or deep_mode1(value,copies))
      end
    end
    return out
  end
  M.deepchain = deep_mode1
end

do
-- deepcopy for long chains
  local function check(obj, todo, copies, skip)
    if skip then
      return obj
    end
    if copies[obj] ~= nil then
      return copies[obj]
    end
    local status, c = tryinvokemeta(obj, "__copy")
    if status then
      copies[obj] = c
      return c
    end
    if type(obj) == "table" then
      local t = {}
      todo[obj] = t
      copies[obj] = t
      return t
    end
    return obj
  end
  local function deep_mode2(inp, copies, nokeys)
    local status, out = tryinvokemeta(inp, "__copy")
    if status then
      return out
    end
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
  M.deeplong = deep_mode2
end

do
  function M.shallow(inp)
    local out = {}
    for key,value in next,inp do -- skip metatables by using next directly
      out[key] = value
    end
    return out
  end
end

-- default deep copy
M.deep = M.deepchain

-- ////////////
-- // ADDONS //
-- ////////////

do
-- metatable deep copy
  local mtdeepcopy_mt = {
    __newindex = function(t,k,v)
      setmetatable(v,debug.getmetatable(k))
      rawset(t,k,v)
    end
  }

  function M.deep_keep_metatable(inp)
    return M.deep(inp,setmetatable({},mtdeepcopy_mt))
  end
end

do
-- metatable shallow copy
  local mtshallowcopy_mt = {
    __newindex = function(t,k,v) -- don't rawset() so that __index gets called
      setmetatable(v,debug.getmetatable(k))
    end,
    __index = function(t,k)
      return k
    end
  }

  function M.shallow_keep_metatable(inp)
    return M.deep(inp,setmetatable({},mtshallowcopy_mt))
  end
end

return M