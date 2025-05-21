-- storage.lua — сохранение/загрузка таблицы из файла

local serialization = require("serialization")
local fs = require("filesystem")

local storage = {}

function storage.save(PATH, tbl)
  local f = io.open(PATH, "w")
  if f then f:write("return "..serialization.serialize(tbl)); f:close() end
end

function storage.load(PATH)
  if not fs.exists(PATH) then return {} end
  local f = io.open(PATH, "r")
  if not f then return {} end
  local dat = f:read("*a"); f:close()
  local ok, t = pcall(function() return load("return "..dat)() end)
  if ok then return t else return {} end
end

return storage