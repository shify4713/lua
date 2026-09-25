-- PRISMA · log: журнал событий + звуковые сигналы
local P = ...
local U = P.util
local computer = require("computer")

local L = {}
local DEBUG = os.getenv and os.getenv("PRISMA_DEBUG")
local entries = {}
local MAX = 300
local lastBeep = 0
L.seq = 0
L.counts = { info = 0, warn = 0, crit = 0 }

-- lvl: "info" | "warn" | "crit"
function L.add(lvl, src, msg)
  lvl = lvl or "info"
  L.seq = L.seq + 1
  entries[#entries + 1] = { t = U.now(), clock = U.clock(), lvl = lvl, src = src or "sys", msg = tostring(msg), n = L.seq }
  if #entries > MAX then table.remove(entries, 1) end
  L.counts[lvl] = (L.counts[lvl] or 0) + 1
  if DEBUG then io.stderr:write(string.format("[%s] %s: %s\n", lvl, src or "sys", tostring(msg))) end
  if P.state then P.state.dirty = true end
  if lvl == "crit" then L.beep(2) elseif lvl == "warn" then L.beep(1) end
end

function L.info(src, msg) L.add("info", src, msg) end
function L.warn(src, msg) L.add("warn", src, msg) end
function L.crit(src, msg) L.add("crit", src, msg) end

function L.beep(kind)
  if not (P.cfg and P.cfg.ui.sound) then return end
  local now = U.now()
  if now - lastBeep < 4 then return end
  lastBeep = now
  pcall(computer.beep, kind == 2 and 1200 or 800, kind == 2 and 0.25 or 0.1)
end

function L.all() return entries end

-- последние n записей (новые в конце), с фильтром по уровню (минимальному)
local RANK = { info = 1, warn = 2, crit = 3 }
function L.recent(n, minLvl)
  local r = {}
  local min = RANK[minLvl or "info"] or 1
  for i = #entries, 1, -1 do
    if RANK[entries[i].lvl] >= min then
      table.insert(r, 1, entries[i])
      if #r >= n then break end
    end
  end
  return r
end

function L.last() return entries[#entries] end

function L.clear() entries = {}; L.counts = { info = 0, warn = 0, crit = 0 }; if P.state then P.state.dirty = true end end

return L
