--[[
  PRISMA CORE Installer
  OpenComputers 1.7.10
  Запуск:  wget -f https://raw.githubusercontent.com/shify4713/lua/main/prisma/installer.lua /tmp/prisma_install.lua && /tmp/prisma_install.lua
]]

local component = require("component")
local fs = require("filesystem")
local shell = require("shell")
local computer = require("computer")
local term = require("term")
local gpu = component.gpu

local REPO = "https://raw.githubusercontent.com/shify4713/lua/main/prisma/"
local BASE = "/home/prisma/"

local files = {
  "main.lua",
  "config.lua",
  "lib/ui.lua",
  "lib/utils.lua",
  "lib/reactor.lua",
  "lib/core.lua",
  "lib/precraft.lua",
  "lib/singularity.lua",
  "lib/glasses.lua",
  "lib/radar.lua",
  "lib/chat.lua",
}

local function printStatus(msg, color)
  gpu.setForeground(color or 0x00E5FF)
  print(msg)
  gpu.setForeground(0xFFFFFF)
end

local function ensureDir(path)
  if not fs.exists(path) then
    fs.makeDirectory(path)
  end
end

printStatus("══════════════════════════════════════", 0x00E5FF)
printStatus("   PRISMA CORE Installer v1.0", 0x69F0AE)
printStatus("══════════════════════════════════════", 0x00E5FF)
print()

ensureDir(BASE)
ensureDir(BASE .. "lib")
ensureDir("/lib")

local okCount, failCount = 0, 0

for _, file in ipairs(files) do
  local url = REPO .. file
  local dest = BASE .. file
  printStatus("[↓] " .. file, 0x90A4AE)
  local ok, err = pcall(function()
    shell.execute("wget -fq " .. url .. " " .. dest)
  end)
  if ok and fs.exists(dest) then
    printStatus("    OK", 0x69F0AE)
    okCount = okCount + 1
  else
    printStatus("    FAIL: " .. tostring(err), 0xFF5555)
    failCount = failCount + 1
  end
end

-- Создаём ярлык запуска
local launcher = [[
#!/usr/bin/env lua
-- PRISMA CORE Launcher
dofile("/home/prisma/main.lua")
]]
local f = io.open("/home/prisma.lua", "w")
if f then
  f:write(launcher)
  f:close()
  printStatus("[+] Создан ярлык: /home/prisma.lua", 0x69F0AE)
end

print()
printStatus("══════════════════════════════════════", 0x00E5FF)
printStatus(string.format("Установлено: %d  |  Ошибок: %d", okCount, failCount), okCount > 0 and 0x69F0AE or 0xFF5555)
print()
printStatus("Запуск:  prisma", 0x00E5FF)
printStatus("или:     /home/prisma/main.lua", 0x90A4AE)
printStatus("══════════════════════════════════════", 0x00E5FF)

if failCount == 0 then
  print()
  printStatus("Всё готово. Перезагружать компьютер не нужно.", 0x69F0AE)
  printStatus("Можно сразу запускать.", 0x69F0AE)
end
