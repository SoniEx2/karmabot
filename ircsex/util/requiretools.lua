local require = require

local M = {}

local function req(name)
  -- TODO relative require
  -- that is, if in module "something", require"something.test" can be rewritten as req"test"
end

M.req = req

local function opt(name)
  local s,m = pcall(require,name)
  if s then
    return m
  else
    return nil
  end
end

M.opt = opt

return M