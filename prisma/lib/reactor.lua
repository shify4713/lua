-- PRISMA · reactor: до 5 реакторов Draconic Evolution
-- Логика: щит держится через входной гейт (drain / (1 - shield)), выход подстраивается по температуре.
local P = ...
local U = P.util
local log = P.log

local R = {}
local list = {}
local MAX = 5

local KIND = {
  running = "running", online = "running",
  warming_up = "warming", charging = "warming", starting = "warming", charged = "warming",
  cold = "off", offline = "off", off = "off",
  stopping = "stopping", cooling = "stopping",
  invalid = "invalid", beyond_hope = "invalid",
}
R.KIND_TEXT = { running = "РАБОТА", warming = "ПРОГРЕВ", off = "ВЫКЛ", stopping = "ОСТАНОВКА", invalid = "ОШИБКА", unknown = "?" }

local function cfg() return P.cfg.reactors end
local function path() return P.dataDir .. "/reactors.dat" end

local function save()
  local out = {}
  for _, r in ipairs(list) do out[#out + 1] = { r = r.rAddr, i = r.inAddr, o = r.outAddr, auto = r.auto } end
  U.writeTable(path(), { v = 1, list = out })
end

local function resolve(r)
  r.proxy = U.proxy(r.rAddr)
  r.gateIn = U.proxy(r.inAddr)
  r.gateOut = U.proxy(r.outAddr)
  r.resolveAt = U.now()
  -- принудительный режим: гейты слушают именно наше значение, а не внешний редстоун
  if r.gateIn and type(r.gateIn.setOverrideEnabled) == "function" then pcall(r.gateIn.setOverrideEnabled, true) end
  if r.gateOut and type(r.gateOut.setOverrideEnabled) == "function" then pcall(r.gateOut.setOverrideEnabled, true) end
end

local function make(d)
  local r = {
    rAddr = d.r, inAddr = d.i, outAddr = d.o, auto = d.auto ~= false,
    online = false, kind = "unknown", stateText = "ПОИСК", info = {}, d = {},
    hist = {}, histAt = 0, nextAt = 0, fail = 0, verifyAt = 0,
  }
  resolve(r)
  return r
end

function R.init()
  list = {}
  local t = U.readTable(path())
  if t and type(t.list) == "table" then
    for _, d in ipairs(t.list) do list[#list + 1] = make(d) end
  else
    local old = U.readTable(P.base .. "/reactors.cfg")     -- старый формат
    if old then
      for _, d in ipairs(old) do
        if d.rAddr and d.inAddr and d.outAddr then
          list[#list + 1] = make({ r = d.rAddr, i = d.inAddr, o = d.outAddr, auto = d.auto })
        end
      end
      if #list > 0 then save(); log.info("РЕАКТОРЫ", "импортировано из старой версии: " .. #list) end
    end
  end
end

function R.list() return list end
function R.count() return #list end
function R.max() return MAX end

function R.usedAddrs()
  local u = {}
  for _, r in ipairs(list) do u[r.rAddr] = true; u[r.inAddr] = true; u[r.outAddr] = true end
  return u
end

-- ───────── шлюзы ─────────
local function gateRead(g)
  if not g or type(g.getSignalLowFlow) ~= "function" then return nil end
  local ok, v = pcall(g.getSignalLowFlow)
  if ok and tonumber(v) then return tonumber(v) end
end

local function gateWrite(r, which, v, force)
  local g = which == "in" and r.gateIn or r.gateOut
  if not g or type(g.setSignalLowFlow) ~= "function" then return end
  v = math.max(0, math.floor(v))
  local key = which == "in" and "lastIn" or "lastOut"
  local cur = r[key]
  if cur and not force then
    if which == "in" then
      if math.abs(v - cur) < math.max(1000, cur * 0.01) then return end
    elseif v == cur then return end
  end
  if pcall(g.setSignalLowFlow, v) then r[key] = v end
end

local function verifyGates(r, now)
  if now - r.verifyAt < 20 and r.lastIn and r.lastOut then return end
  r.verifyAt = now
  local a, b = gateRead(r.gateIn), gateRead(r.gateOut)
  if a then r.lastIn = a end
  if b then r.lastOut = b end
end

-- ───────── шаг управления одним реактором ─────────
local function emergency(r, why, now)
  if r.estopAt and now - r.estopAt < 8 then return end
  r.estopAt = now
  if r.proxy then pcall(r.proxy.stopReactor) end
  r.auto = false
  r.stateText = "АВАРИЯ"
  log.crit("РЕАКТОР " .. (r.idx or "?"), "АВАРИЙНАЯ ОСТАНОВКА: " .. why)
end

local function step(r, idx, now)
  r.idx = idx
  if not r.proxy or type(r.proxy.getReactorInfo) ~= "function" then
    r.wasRunning = false
    r.online = false
    r.stateText = "НЕТ СВЯЗИ"
    if now - (r.resolveAt or 0) > 10 then resolve(r) end
    return
  end
  local ok, inf = pcall(r.proxy.getReactorInfo)
  if not ok or type(inf) ~= "table" then
    r.fail = r.fail + 1
    if r.fail >= 3 then
      r.online = false
      r.stateText = "НЕТ СВЯЗИ"
      if now - (r.resolveAt or 0) > 10 then resolve(r) end
    end
    return
  end
  r.fail = 0
  if not r.online then r.online = true end
  r.info = inf

  local c = cfg()
  local kind = KIND[tostring(inf.status or ""):lower()] or "unknown"
  local temp = tonumber(inf.temperature) or 0
  local gen = tonumber(inf.generationRate) or 0
  local drain = tonumber(inf.fieldDrainRate) or 0
  local satMax = tonumber(inf.maxEnergySaturation) or 1
  local fieldMax = tonumber(inf.maxFieldStrength) or 1
  local fuelMax = tonumber(inf.maxFuelConversion) or 1
  local sat = (tonumber(inf.energySaturation) or 0) / (satMax > 0 and satMax or 1)
  local field = (tonumber(inf.fieldStrength) or 0) / (fieldMax > 0 and fieldMax or 1)
  local fuel = (tonumber(inf.fuelConversion) or 0) / (fuelMax > 0 and fuelMax or 1)
  r.kind = kind
  r.d = { temp = temp, gen = gen, drain = drain, sat = sat, field = field, fuel = fuel }

  -- холодный старт: реактор только что вышел на «РАБОТА» со свежим топливом —
  -- на время разгона используем увеличенный шаг, чтобы быстрее выйти на рабочую температуру
  if kind == "running" and not r.wasRunning then
    r.cold = (fuel < 0.03)
    r.coldSince = now
    if r.cold then log.info("РЕАКТОР " .. idx, "холодный старт — ускоренный разгон включён") end
  end
  r.wasRunning = (kind == "running")
  if r.cold and (kind ~= "running" or now - (r.coldSince or now) > (c.coldBoostTime or 180) or temp >= c.forceModeTemp) then
    r.cold = false
  end

  if now - r.histAt >= 3 then
    r.histAt = now
    r.hist[#r.hist + 1] = temp
    if #r.hist > 60 then table.remove(r.hist, 1) end
  end

  -- аварийная защита
  if c.emergency and kind == "running" then
    if temp >= c.tempEmergency then emergency(r, string.format("температура %.0f°", temp), now); return end
    if drain > 0 and field * 100 < c.fieldEmergency then emergency(r, string.format("поле %.1f%%", field * 100), now); return end
  end
  -- топливо
  if kind == "running" then
    if fuel * 100 >= c.fuelWarn and not r.fuelWarned then
      r.fuelWarned = true
      log.warn("РЕАКТОР " .. idx, string.format("топливо %.0f%% — пора менять", fuel * 100))
    elseif fuel * 100 < c.fuelWarn - 3 then
      r.fuelWarned = false
    end
    if c.fuelStop > 0 and fuel * 100 >= c.fuelStop then
      pcall(r.proxy.stopReactor)
      r.auto = false
      log.crit("РЕАКТОР " .. idx, "остановлен по топливу")
      return
    end
  end

  verifyGates(r, now)

  -- реальный измеренный поток (для отображения; наша команда может не совпадать с фактом)
  if r.gateIn and type(r.gateIn.getFlow) == "function" then
    local ok, v = pcall(r.gateIn.getFlow); if ok and tonumber(v) then r.realIn = tonumber(v) end
  end
  if r.gateOut and type(r.gateOut.getFlow) == "function" then
    local ok, v = pcall(r.gateOut.getFlow); if ok and tonumber(v) then r.realOut = tonumber(v) end
  end

  -- входной гейт (щит)
  if kind == "warming" then
    gateWrite(r, "in", 1000000)
  elseif kind == "running" or kind == "stopping" then
    local shield = U.clamp(c.targetShield, 1, 90) / 100
    gateWrite(r, "in", math.ceil(drain / (1 - shield)))
  end

  -- выходной гейт
  local out = r.lastOut or 0
  if not r.auto then
    r.stateText = (kind == "running") and "РУЧНОЙ" or (R.KIND_TEXT[kind] or "?")
  elseif kind == "running" then
    if temp < c.forceModeTemp then
      local boostStep = r.cold and (c.coldBoostStep or 6000) or 1000
      if out > c.initialFlow + 50000 then
        r.stateText = r.cold and "РАЗГОН" or "ВОССТ."
        if out - gen < boostStep then gateWrite(r, "out", out + boostStep) end
      else
        r.stateText = "УДЕРЖ."
        if out ~= c.initialFlow then gateWrite(r, "out", c.initialFlow) end
      end
    elseif temp < c.safeModeTemp then
      r.stateText = "СТАБИЛЬНО"
      if out - gen < 1500 then gateWrite(r, "out", out + 800) end
    elseif temp > c.tempCrit then
      r.stateText = "КРИТИЧНО"
      gateWrite(r, "out", c.initialFlow)
    else
      r.stateText = "ОПТИМАЛЬНО"
      local targetOut = gen + (sat < 0.15 and 2000 or 500)
      if math.abs(out - targetOut) > 2000 then gateWrite(r, "out", targetOut) end
    end
    if fuel > 0.92 then
      r.stateText = "ТОПЛИВО!"
      gateWrite(r, "out", math.min(out, c.initialFlow))
    end
  else
    r.stateText = R.KIND_TEXT[kind] or "?"
    if kind == "warming" and out ~= c.initialFlow then gateWrite(r, "out", c.initialFlow) end
  end
end

-- по одному-двум реакторам за вызов, чтобы не забивать очередь вызовов
function R.update(now)
  now = now or U.now()
  local done = 0
  for i, r in ipairs(list) do
    if now >= r.nextAt then
      r.nextAt = now + cfg().interval
      local ok, err = pcall(step, r, i, now)
      if not ok then log.warn("РЕАКТОР " .. i, "ошибка: " .. U.trunc(tostring(err), 60)) end
      done = done + 1
      if done >= 2 then break end
    end
  end
end

-- ───────── команды ─────────
function R.toggleAuto(i)
  local r = list[i]
  if r then r.auto = not r.auto; save() end
end

function R.charge(i)
  local r = list[i]
  if r and r.proxy then
    pcall(r.proxy.chargeReactor)
    log.info("РЕАКТОР " .. i, "заряд запущен")
  end
end

function R.power(i)
  local r = list[i]
  if not r or not r.proxy then return end
  if r.kind == "running" then
    pcall(r.proxy.stopReactor)
    r.auto = false
    log.info("РЕАКТОР " .. i, "остановка")
  else
    pcall(r.proxy.activateReactor)
    log.info("РЕАКТОР " .. i, "запуск")
  end
  save()
end

function R.stopAll()
  for i, r in ipairs(list) do
    if r.proxy and r.kind == "running" then pcall(r.proxy.stopReactor); r.auto = false end
  end
  log.crit("РЕАКТОРЫ", "ручная остановка всех")
  save()
end

function R.adjustFlow(i, delta)
  local r = list[i]
  if not r then return end
  local cur = r.lastOut or gateRead(r.gateOut) or 0
  gateWrite(r, "out", math.max(1000, cur + delta), true)
end

function R.remove(i)
  if list[i] then table.remove(list, i); save(); return true end
end

-- ───────── добавление ─────────
function R.free()
  local used = R.usedAddrs()
  local reactors, gates = {}, {}
  for _, a in ipairs(U.compList("draconic_reactor")) do if not used[a] then reactors[#reactors + 1] = a end end
  for _, a in ipairs(U.compList("flux_gate")) do
    if not used[a] and a ~= (P.mods.core and P.mods.core.gateAddr) then
      gates[#gates + 1] = { addr = a, flow = gateRead(U.proxy(a)) }
    end
  end
  return reactors, gates
end

function R.addManual(rAddr, inAddr, outAddr)
  if #list >= MAX then return false, "максимум " .. MAX .. " реакторов" end
  if inAddr == outAddr then return false, "входной и выходной шлюз должны отличаться" end
  local r = make({ r = rAddr, i = inAddr, o = outAddr, auto = true })
  r.stateText = "ДОБАВЛЕН"
  list[#list + 1] = r
  save()
  log.info("РЕАКТОР " .. #list, "добавлен")
  return true
end

-- авто: первый свободный реактор и два шлюза, роль определяем по фактической генерации
-- реактора (если он уже включён), иначе — по прежней эвристике из абсолютных порогов
function R.addAuto()
  local reactors, gates = R.free()
  if #reactors < 1 or #gates < 2 then return false, "нужен 1 свободный реактор и 2 свободных шлюза" end
  local rAddr = reactors[1]
  local g1, g2 = gates[1], gates[2]
  local f1, f2 = g1.flow or 0, g2.flow or 0
  local out, inn = g1.addr, g2.addr
  local gen
  local rp = U.proxy(rAddr)
  if rp and type(rp.getReactorInfo) == "function" then
    local ok, inf = pcall(rp.getReactorInfo)
    if ok and type(inf) == "table" then gen = tonumber(inf.generationRate) end
  end
  if gen and gen > 1000 then
    -- выходной шлюз — тот, чей текущий поток ближе к реальной генерации реактора
    if math.abs(f1 - gen) > math.abs(f2 - gen) then out, inn = g2.addr, g1.addr end
  elseif f2 > (cfg().detectOutMin or 530000) and f1 < (cfg().detectInMax or 500000) then
    out, inn = g2.addr, g1.addr
  end
  return R.addManual(rAddr, inn, out)
end

function R.totals()
  local gen, on = 0, 0
  for _, r in ipairs(list) do
    if r.online and r.kind == "running" then gen = gen + (r.d.gen or 0); on = on + 1 end
  end
  return { gen = gen, running = on, count = #list }
end

function R.flush() end

return R
