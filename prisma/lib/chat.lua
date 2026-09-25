-- PRISMA · chat: локальный чат (chat_box) + команды !prisma
local P = ...
local U = P.util
local log = P.log

local C = {}
local box
local logs = {}

local function cfg() return P.cfg.chat end

function C.init()
  logs = {}
  box = U.findComp("chat_box", P.cfg.devices.chat)
  if box then pcall(box.setName, "§3[PRISMA]§r") end
end

function C.available() return box ~= nil end

function C.say(text)
  if not box then return false end
  text = tostring(text)
  if U.ulen(text) > 200 then text = U.usub(text, 1, 200) end
  return pcall(box.say, text)
end

function C.add(name, msg)
  if not msg then return end
  logs[#logs + 1] = { name = tostring(name or "?"), msg = tostring(msg), t = U.now(), clock = U.clock() }
  while #logs > (cfg().maxLines or 60) do table.remove(logs, 1) end
  if P.state then P.state.dirty = true end
end

function C.logs() return logs end

-- последние n строк в виде «имя: текст»
function C.lines(n)
  local r = {}
  for i = math.max(1, #logs - n + 1), #logs do r[#r + 1] = logs[i].name .. ": " .. logs[i].msg end
  return r
end

local function reply(lines)
  for _, l in ipairs(lines) do C.say(l) end
end

local function command(name, msg)
  local args = {}
  for w in msg:gmatch("%S+") do args[#args + 1] = w end
  if args[1] ~= "!prisma" then return false end
  local what = (args[2] or "status"):lower()
  local m = P.mods
  local lines = {}
  if what == "status" or what == "s" then
    local c = m.core and m.core.info()
    if c and c.online then lines[#lines + 1] = string.format("§bЯдро:§r %s / %s (%.0f%%)", U.num(c.energy), U.num(c.target), math.floor(c.percent * 100)) end
    if m.reactor then
      local t = m.reactor.totals()
      lines[#lines + 1] = string.format("§bРеакторы:§r %.0f/%.0f в работе, %s RF/t", t.running, t.count, U.num(t.gen))
    end
    if m.autocraft then
      local s = m.autocraft.summary()
      lines[#lines + 1] = string.format("§bКрафт:§r %.0f идёт, %.0f ждёт, %.0f ошибок", s.running, s.want, s.fail)
    end
  elseif what == "craft" then
    local list = m.autocraft and m.autocraft.crafting() or {}
    if #list == 0 then lines[1] = "Сейчас ничего не крафтится" end
    for i, it in ipairs(list) do
      if i > 5 then break end
      local frac, el, eta = m.autocraft.progress(it)
      lines[#lines + 1] = string.format("%s — %.0f%%, %s", it.label, math.floor((frac or 0) * 100), U.dur(eta))
    end
  elseif what == "reactors" or what == "r" then
    for i, r in ipairs(m.reactor and m.reactor.list() or {}) do
      lines[#lines + 1] = string.format("#%.0f %s %.0f° поле %.0f%%", i, r.stateText or "?", math.floor(r.d.temp or 0), math.floor((r.d.field or 0) * 100))
    end
  elseif what == "sing" then
    local s = m.singularity and m.singularity.summary()
    if s then lines[1] = string.format("Сингулярки: готово %.0f шт (%.0f видов)", s.ready, s.kinds) end
  else
    lines[1] = "Команды: !prisma [status|craft|reactors|sing]"
  end
  reply(lines)
  return true
end

function C.onMessage(name, msg)
  if not msg then return end
  if msg:sub(1, 1) == "!" then
    if cfg().commands then pcall(command, name, msg) end
    return
  end
  C.add(name, msg)
end

return C
