-- PRISMA · core: контроль энергоядра Draconic Evolution
-- Держим заряд около цели, регулируя выходной flux-gate ядра.
local P = ...
local U = P.util
local log = P.log

local C = {}
local rf, gate
local st = { online = false, energy = 0, max = 1, percent = 0, flow = 0, rate = 0, filtered = 0 }
local last, lastT
local flowSet
local verifyAt, maxAt = 0, 0
local hist, histAt = {}, 0
local candidates = {}
C.gateAddr = nil
C.gateState = "none"      -- none | auto | manual | ambiguous

local function cfg() return P.cfg.core end

local function setGate(addr, how)
  gate = addr and U.proxy(addr) or nil
  C.gateAddr = gate and addr or nil
  C.gateState = gate and how or "none"
  flowSet = nil
  -- принудительный режим: гейт слушает именно наше значение, а не внешний редстоун-сигнал
  if gate and type(gate.setOverrideEnabled) == "function" then pcall(gate.setOverrideEnabled, true) end
end

function C.init()
  last, lastT, flowSet = nil, nil, nil
  hist, histAt = {}, 0
  st.rate, st.filtered = 0, 0
  rf = U.findComp("draconic_rf_storage", P.cfg.devices.storage)
  local pref = P.cfg.devices.coreGate
  if pref and pref ~= "" then
    local _, a = U.findComp("flux_gate", pref)
    if a then setGate(a, "manual"); return end
  end
  -- авто: только если после реакторов остался ровно один свободный шлюз
  local used = P.mods.reactor and P.mods.reactor.usedAddrs() or {}
  candidates = {}
  for _, a in ipairs(U.compList("flux_gate")) do
    if not used[a] then candidates[#candidates + 1] = a end
  end
  if #candidates == 1 then
    setGate(candidates[1], "auto")
  elseif #candidates > 1 then
    setGate(nil); C.gateState = "ambiguous"
  else
    setGate(nil)
  end
end

function C.candidates() return candidates end
function C.hasStorage() return rf ~= nil end
function C.hasGate() return gate ~= nil end

function C.assignGate(addr)
  P.cfg.devices.coreGate = addr or ""
  P.config.markDirty()
  C.init()
end

local function readFlow()
  if not gate then return nil end
  local ok, v = pcall(gate.getSignalLowFlow)
  if ok and tonumber(v) then return tonumber(v) end
  return nil
end

local function writeFlow(v)
  if not gate then return end
  v = math.floor(U.clamp(v, cfg().flowMin, cfg().flowMax) + 0.5)
  if v == flowSet then return end
  local ok = pcall(gate.setSignalLowFlow, v)
  if ok then flowSet = v end
end

function C.update(now)
  if not rf then st.online = false; return end
  now = now or U.now()
  local ok, cur = pcall(rf.getEnergyStored)
  if not ok or type(cur) ~= "number" then st.online = false; return end
  if now - maxAt > 30 or st.max <= 1 then
    maxAt = now
    local ok2, m = pcall(rf.getMaxEnergyStored)
    if ok2 and tonumber(m) and m > 0 then st.max = m end
  end
  st.online = true
  st.energy = cur
  st.percent = U.clamp(cur / st.max, 0, 1)

  if last then
    local dt = now - lastT
    if dt >= 0.05 then
      st.rate = st.rate + ((cur - last) / (dt * 20) - st.rate) * 0.3
      local nominal = cfg().interval or 0.4
      st.filtered = st.filtered + ((cur - last) * (nominal / dt) - st.filtered) * 0.25
      last, lastT = cur, now
    end
  else
    last, lastT = cur, now
  end

  if now - histAt >= 5 then
    histAt = now
    hist[#hist + 1] = cur
    if #hist > 120 then table.remove(hist, 1) end
  end

  if not gate then return end
  if not flowSet or now - verifyAt > 15 then
    verifyAt = now
    local f = readFlow()
    if f then flowSet = f end
  end
  st.flow = flowSet or 0
  if not cfg().auto or not flowSet then return end

  local c = cfg()
  local target = c.target
  local err = cur - target
  local dead = target * 0.0002
  if math.abs(err) < dead and math.abs(st.filtered) < c.maxDiff / 4 then return end
  local mult = 1
  if c.adaptive then
    mult = U.clamp(math.abs(err) / math.max(1e6, target * 0.0005), 1, 40)
  end
  local step = c.step * mult
  if err > 0 then
    if st.filtered > -c.maxDiff then writeFlow(flowSet + step) end
  else
    if st.filtered < c.maxDiff and flowSet > c.flowMin then writeFlow(flowSet - step) end
  end
  st.flow = flowSet or st.flow
end

function C.info()
  local t = cfg().target
  local real
  if gate and type(gate.getFlow) == "function" then
    local ok, v = pcall(gate.getFlow)
    if ok and tonumber(v) then real = tonumber(v) end
  end
  return {
    online = st.online, energy = st.energy, max = st.max, percent = st.percent,
    flow = st.flow, real = real, rate = st.rate, target = t, auto = cfg().auto,
    hasGate = gate ~= nil, gateState = C.gateState, gate = C.gateAddr,
  }
end

function C.eta()
  local err = cfg().target - st.energy
  if math.abs(st.rate) < 1 then return nil end
  local sec = err / (st.rate * 20)
  if sec > 0 then return sec end
  return nil
end

-- текст и цвет («ok»/«text»/«warn») для строки «до цели»
function C.etaInfo()
  local target = cfg().target
  local err = target - st.energy
  if math.abs(err) <= math.max(target * 0.002, 1e6) then return "в цели", "ok" end
  local eta = C.eta()
  if eta then return "через " .. U.dur(eta), "text" end
  return err > 0 and "не растёт" or "не падает", "warn"
end

function C.history() return hist end

function C.setTarget(v)
  cfg().target = U.clamp(v, 0, st.max > 1 and st.max or math.huge)
  P.config.markDirty()
end

function C.adjustTarget(d) C.setTarget((cfg().target or 0) + d) end

function C.toggleAuto()
  cfg().auto = not cfg().auto
  P.config.markDirty()
  log.info("ЯДРО", cfg().auto and "авто-регулировка включена" or "авто-регулировка выключена")
end

-- ручная регулировка выхода (когда авто выключено)
function C.nudgeFlow(d)
  if not gate then return end
  local f = flowSet or readFlow() or 0
  writeFlow(f + d)
  st.flow = flowSet or st.flow
end

return C
