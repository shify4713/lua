-- PRISMA · установщик / обновлятор
-- Запуск на компьютере OpenComputers (нужна интернет-карта):
--   rm -f /tmp/i.lua; wget -f https://raw.githubusercontent.com/shify4713/prisma/main/installer.lua /tmp/i.lua && /tmp/i.lua
-- Свой адрес репозитория:  /tmp/i.lua https://мой.сервер/путь/
local component = require("component")
local fs = require("filesystem")

local args = { ... }
local REPO = args[1] or "https://raw.githubusercontent.com/shify4713/prisma/main/"
if REPO:sub(-1) ~= "/" then REPO = REPO .. "/" end
local ROOT = "/home/prisma"

local FILES = {
  "main.lua", "config.lua", "installer.lua", "ADAPTER_SETUP.txt",
  "lib/util.lua", "lib/log.lua", "lib/fb.lua", "lib/ui.lua", "lib/modal.lua", "lib/me.lua",
  "lib/reactor.lua", "lib/core.lua", "lib/autocraft.lua", "lib/singularity.lua",
  "lib/radar.lua", "lib/chat.lua", "lib/glasses.lua",
  "views/common.lua", "views/actions.lua", "views/dash.lua", "views/power.lua", "views/craft.lua",
  "views/sing.lua", "views/hud.lua", "views/log.lua", "views/settings.lua",
}
-- файлы старых версий, которые больше не нужны
local OBSOLETE = { "lib/precraft.lua", "lib/utils.lua" }

local function say(s) io.write(s .. "\n") end

if not component.isAvailable("internet") then
  say("Нужна интернет-карта. Либо скопируйте папку prisma в /home вручную.")
  return
end

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDirectory(path) end
end

local function download(rel)
  local dest = ROOT .. "/" .. rel
  ensureDir(dest:match("^(.*)/[^/]+$"))
  local tmp = dest .. ".new"
  fs.remove(tmp)
  local ok = os.execute(string.format('wget -fq "%s%s" "%s"', REPO, rel, tmp))
  local size = fs.exists(tmp) and fs.size(tmp) or 0
  if (ok == true or ok == 0) and size > 0 then
    fs.remove(dest)
    if fs.rename(tmp, dest) then return true end
  end
  fs.remove(tmp)
  return false
end

say("PRISMA · установка в " .. ROOT)
ensureDir(ROOT)
ensureDir(ROOT .. "/data")

local failed = {}
for i, rel in ipairs(FILES) do
  io.write(string.format("[%2d/%d] %-24s ", i, #FILES, rel))
  if download(rel) then say("ok") else say("ОШИБКА"); failed[#failed + 1] = rel end
end

if #failed > 0 then
  say("")
  say("Не скачались файлы: " .. table.concat(failed, ", "))
  say("Проверьте адрес репозитория и повторите установку. Старая версия не тронута для этих файлов.")
  return
end

for _, rel in ipairs(OBSOLETE) do fs.remove(ROOT .. "/" .. rel) end

-- команда «prisma»
ensureDir("/home/bin")
local f = io.open("/home/bin/prisma.lua", "w")
if f then
  f:write('dofile("/home/prisma/main.lua")\n')
  f:close()
end

say("")
say("Готово! Запуск: prisma")
io.write("Запускать автоматически при старте компьютера? [y/N] ")
local a = io.read()
if a and a:lower():sub(1, 1) == "y" then
  local rc = io.open("/home/.shrc", "a")
  if rc then rc:write("\nprisma\n"); rc:close(); say("Автозапуск включён (/home/.shrc)") end
end
say("Старые настройки (config.cfg, reactors.cfg, precraft_bd.txt) подхватятся автоматически.")
