-- PRISMA · util: форматирование, таблицы, файлы, компоненты
local P = ...
local unicode = require("unicode")
local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local serialization = require("serialization")

local U = {}
local ulen, usub = unicode.len, unicode.sub
U.ulen, U.usub = ulen, usub
U.unpack = table.unpack or unpack

function U.now() return computer.uptime() end

-- ───────── числа ─────────
function U.clamp(v, a, b)
  if v ~= v then return a end
  if v < a then return a elseif v > b then return b end
  return v
end

function U.round(v, n)
  local m = 10 ^ (n or 0)
  return math.floor(v * m + 0.5) / m
end

local UNITS = { { 1e15, "P" }, { 1e12, "T" }, { 1e9, "G" }, { 1e6, "M" }, { 1e3, "k" } }
-- 1234567 -> 1.23M
function U.num(n)
  if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then return "0" end
  local a = math.abs(n)
  for i = 1, #UNITS do
    if a >= UNITS[i][1] then
      local v = n / UNITS[i][1]
      local av = math.abs(v)
      local d = av >= 100 and 0 or (av >= 10 and 1 or 2)
      return string.format("%." .. d .. "f%s", v, UNITS[i][2])
    end
  end
  return string.format("%d", math.floor(n + (n >= 0 and 0.5 or -0.5)))
end

-- 12345678 -> "12 345 678"
function U.int(n)
  if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then return "0" end
  local s = string.format("%d", math.floor(math.abs(n) + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  out = out:gsub("^ ", "")
  return (n < 0 and "-" or "") .. out
end

function U.signed(n)
  if n == nil or n ~= n then return "0" end
  if n > 0 then return "+" .. U.num(n) end
  return U.num(n)
end

function U.pct(f, d)
  if type(f) ~= "number" or f ~= f then return "0%" end
  return string.format("%." .. (d or 0) .. "f%%", f * 100)
end

-- секунды -> "3:05" / "1:02:03" / "—"
function U.dur(s)
  if type(s) ~= "number" or s ~= s or s == math.huge or s < 0 then return "—" end
  s = math.floor(s + 0.5)
  if s >= 86400 then return string.format("%dд%02dч", math.floor(s / 86400), math.floor(s % 86400 / 3600)) end
  if s >= 3600 then return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60) end
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- "10G" -> 1e10, "1 500" -> 1500, "2,5k" -> 2500
function U.parseNum(s)
  if type(s) == "number" then return s end
  if type(s) ~= "string" then return nil end
  s = s:gsub("%s+", ""):gsub(",", ".")
  if s == "" then return nil end
  local mult = 1
  local last = s:sub(-1):lower()
  if last == "k" or last == "к" then mult = 1e3
  elseif last == "m" or last == "м" then mult = 1e6
  elseif last == "g" or last == "г" then mult = 1e9
  elseif last == "t" or last == "т" then mult = 1e12 end
  if mult ~= 1 then s = s:sub(1, -2) end
  local v = tonumber(s)
  if not v then return nil end
  return v * mult
end

-- ───────── строки ─────────
function U.trunc(s, n)
  s = tostring(s or "")
  if n <= 0 then return "" end
  if ulen(s) <= n then return s end
  if n == 1 then return "…" end
  return usub(s, 1, n - 1) .. "…"
end

function U.pad(s, n, right)
  s = U.trunc(s, n)
  local l = ulen(s)
  if l >= n then return s end
  if right then return string.rep(" ", n - l) .. s end
  return s .. string.rep(" ", n - l)
end

function U.lower(s) return unicode.lower(tostring(s or "")) end

function U.trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function U.shortAddr(a) return a and tostring(a):sub(1, 8) or "—" end

-- ───────── таблицы ─────────
function U.copy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = U.copy(v) end
  return r
end

-- дополняет dst недостающими ключами из def (рекурсивно), возвращает dst
function U.fill(dst, def)
  if type(dst) ~= "table" then return U.copy(def) end
  for k, v in pairs(def) do
    if dst[k] == nil then
      dst[k] = U.copy(v)
    elseif type(v) == "table" and type(dst[k]) == "table" and #v == 0 and next(v) ~= nil then
      U.fill(dst[k], v)
    end
  end
  return dst
end

function U.count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- ───────── файлы ─────────
function U.ensureDir(path)
  if not fs.exists(path) then pcall(fs.makeDirectory, path) end
end

function U.readTable(path)
  local function try(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    if not data or data == "" then return nil end
    local ok, t = pcall(serialization.unserialize, data)
    if ok and type(t) == "table" then return t end
    return nil
  end
  return try(path) or try(path .. ".tmp")
end

function U.writeTable(path, t)
  local ok, data = pcall(serialization.serialize, t)
  if not ok then return false, data end
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then
    f = io.open(path, "w")
    if not f then return false, "не могу писать " .. path end
    f:write(data); f:close()
    return true
  end
  f:write(data); f:close()
  pcall(fs.remove, path)
  if not pcall(fs.rename, tmp, path) or not fs.exists(path) then
    local g = io.open(path, "w")
    if g then g:write(data); g:close() end
  end
  return true
end

-- ───────── компоненты ─────────
function U.compList(t)
  local r = {}
  for a in component.list(t, true) do r[#r + 1] = a end
  table.sort(r)
  return r
end

function U.proxy(addr)
  if not addr or addr == "" then return nil end
  local ok, p = pcall(component.proxy, addr)
  if ok and p then return p end
  return nil
end

-- ищем по типам (первый найденный), pref — предпочтительный адрес (можно частичный)
function U.findComp(types, pref)
  if type(types) == "string" then types = { types } end
  if pref and pref ~= "" then
    for _, t in ipairs(types) do
      for a in component.list(t, true) do
        if a == pref or a:sub(1, #pref) == pref then return U.proxy(a), a, t end
      end
    end
  end
  for _, t in ipairs(types) do
    local a = component.list(t, true)()
    if a then return U.proxy(a), a, t end
  end
  return nil
end

-- безопасный вызов метода: возвращает значение либо nil
function U.call(obj, name, ...)
  if not obj then return nil end
  local f = obj[name]
  if type(f) ~= "function" then return nil end
  local ok, a, b = pcall(f, ...)
  if ok then return a, b end
  return nil, a
end

function U.freeMem()
  local ok, f, t = pcall(function() return computer.freeMemory(), computer.totalMemory() end)
  if ok and t and t > 0 then return f, t end
  return 0, 1
end

-- время:
--   real  — computer.realTime() (часы Java-сервера, без интернет-карты)
--   game  — игровые сутки Minecraft (os.date)
--   uptime — с запуска программы
-- os.date/os.time в OpenOS часто привязаны к игровым тикам; для реальных суток
-- предпочитаем computer.realTime(). Если его нет — fallback на os.time / os.date.
local function fmtHMS(sec)
  sec = math.floor(sec % 86400)
  if sec < 0 then sec = sec + 86400 end
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

function U.clock()
  local mode = (P.cfg and P.cfg.clock and P.cfg.clock.mode) or "real"
  local tz = (P.cfg and P.cfg.clock and P.cfg.clock.tz) or 0
  if mode == "uptime" then
    return U.dur(U.now())
  elseif mode == "game" then
    local ok, s = pcall(os.date, "%H:%M:%S")
    if ok and type(s) == "string" and #s >= 5 then return s end
    return "??:??:??"
  end
  -- real
  local ok, ms = pcall(computer.realTime)
  if ok and type(ms) == "number" and ms > 1e9 then
    -- мс с эпохи
    return fmtHMS(ms / 1000 + tz * 3600)
  end
  if ok and type(ms) == "number" and ms > 0 then
    -- некоторые сборки отдают секунды
    local sec = ms
    if sec > 1e12 then sec = sec / 1000 end  -- мкс?
    if sec > 1e10 then sec = sec / 1000 end
    return fmtHMS(sec + tz * 3600)
  end
  -- fallback: os.time (может быть игровым)
  local ok2, t = pcall(os.time)
  if ok2 and type(t) == "number" and t > 1e9 then
    return fmtHMS(t + tz * 3600)
  end
  local ok3, s = pcall(os.date, "%H:%M:%S")
  if ok3 and type(s) == "string" and #s >= 5 then return s end
  return U.dur(U.now())
end

return U
