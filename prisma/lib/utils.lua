-- PRISMA CORE Utils

local component = require("component")
local unicode = require("unicode")

local M = {}

function M.get(compName)
  local addr = component.list(compName)()
  return addr and component.proxy(addr) or nil
end

function M.getAll(compName)
  local list = {}
  for addr in component.list(compName) do
    table.insert(list, component.proxy(addr))
  end
  return list
end

function M.clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

function M.formatNum(n)
  if type(n) ~= "number" or n ~= n then return "0" end
  local absN = math.abs(n)
  if absN >= 1e12 then return string.format("%.2fT", n / 1e12) end
  if absN >= 1e9  then return string.format("%.2fG", n / 1e9)  end
  if absN >= 1e6  then return string.format("%.2fM", n / 1e6)  end
  if absN >= 1e3  then return string.format("%.1fk", n / 1e3)  end
  return tostring(math.floor(n))
end

function M.formatRF(n)
  return M.formatNum(n) .. " RF"
end

function M.pad(s, len, right)
  s = tostring(s)
  local l = unicode.wlen(s)
  if l >= len then return unicode.sub(s, 1, len) end
  local spaces = string.rep(" ", len - l)
  return right and (spaces .. s) or (s .. spaces)
end

function M.center(s, width)
  s = tostring(s)
  local l = unicode.wlen(s)
  if l >= width then return unicode.sub(s, 1, width) end
  local left = math.floor((width - l) / 2)
  return string.rep(" ", left) .. s .. string.rep(" ", width - l - left)
end

function M.timeMS()
  return computer.uptime()
end

return M
