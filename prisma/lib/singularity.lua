-- PRISMA · singularity: учёт блоков и сингулярностей в ME
--   • инкрементальное сканирование (не вешает интерфейс)
--   • прогресс до следующей сингулярности, скорость накопления и ETA
--   • список редактируется в интерфейсе (добавить / изменить / удалить)
local P = ...
local U = P.util
local log = P.log
local me = P.me

local S = {}
local items = {}
local dirty = false
local lastSave = 0

local function cfg() return P.cfg.singularity end
local function path() return P.dataDir .. "/singularity.dat" end

local DEFAULTS = {
  { name = "Железная",       block = "minecraft:iron_ore",          dmg = 0,  need = 4500,  singu = "Avaritia:Singularity", sDmg = 0 },
  { name = "Золотая",        block = "minecraft:gold_ore",          dmg = 0,  need = 2700,  singu = "Avaritia:Singularity", sDmg = 1 },
  { name = "Лазуритовая",    block = "minecraft:lapis_ore",         dmg = 0,  need = 600,   singu = "Avaritia:Singularity", sDmg = 2 },
  { name = "Редстоун",       block = "minecraft:redstone_ore",      dmg = 0,  need = 720,   singu = "Avaritia:Singularity", sDmg = 3 },
  { name = "Кварцевая",      block = "minecraft:quartz_ore",        dmg = 0,  need = 2200,  singu = "Avaritia:Singularity", sDmg = 4 },
  { name = "Медная",         block = "IC2:copperOre",               dmg = 0,  need = 4500,  singu = "Avaritia:Singularity", sDmg = 5 },
  { name = "Оловянная",      block = "IC2:tinOre",                  dmg = 0,  need = 10000, singu = "Avaritia:Singularity", sDmg = 6 },
  { name = "Бронзовая",      block = "IC2:blockMetal",              dmg = 2,  need = 600,   singu = "universalsingularities:universal.general.singularity", sDmg = 2 },
  { name = "Свинцовая",      block = "ThermalFoundation:Ore",       dmg = 3,  need = 9000,  singu = "Avaritia:Singularity", sDmg = 7 },
  { name = "Серебряная",     block = "ThermalFoundation:Ore",       dmg = 2,  need = 2700,  singu = "Avaritia:Singularity", sDmg = 8 },
  { name = "Глиняная",       block = "minecraft:clay",              dmg = 0,  need = 666,   singu = "Avaritia:Singularity", sDmg = 10 },
  { name = "Угольная",       block = "minecraft:coal_block",        dmg = 0,  need = 600,   singu = "universalsingularities:universal.vanilla.singularity", sDmg = 0 },
  { name = "Алмазная",       block = "minecraft:diamond_block",     dmg = 0,  need = 600,   singu = "universalsingularities:universal.vanilla.singularity", sDmg = 2 },
  { name = "Эндериумовая",   block = "ThermalFoundation:Storage",   dmg = 12, need = 111,   singu = "thermsingul:Thermal Singularity", sDmg = 4 },
  { name = "Инвариумовая",   block = "ThermalFoundation:Storage",   dmg = 8,  need = 111,   singu = "universalsingularities:universal.general.singularity", sDmg = 5 },
  { name = "Наэлектросталь", block = "EnderIO:blockIngotStorage",   dmg = 0,  need = 111,   singu = "universalsingularities:universal.enderIO.singularity", sDmg = 1 },
  { name = "Энергосплав",    block = "EnderIO:blockIngotStorage",   dmg = 1,  need = 111,   singu = "universalsingularities:universal.enderIO.singularity", sDmg = 2 },
  { name = "Тёмная сталь",   block = "EnderIO:blockIngotStorage",   dmg = 6,  need = 111,   singu = "universalsingularities:universal.enderIO.singularity", sDmg = 3 },
  { name = "Пульсирующее",   block = "EnderIO:blockIngotStorage",   dmg = 5,  need = 111,   singu = "universalsingularities:universal.enderIO.singularity", sDmg = 4 },
  { name = "Соулариевая",    block = "EnderIO:blockIngotStorage",   dmg = 7,  need = 111,   singu = "universalsingularities:universal.enderIO.singularity", sDmg = 6 },
  { name = "Вибрирующий",    block = "EnderIO:blockIngotStorage",   dmg = 2,  need = 111,   singu = "universalsingularities:universal.enderIO.singularity", sDmg = 7 },
  { name = "Дракониевая",    block = "DraconicEvolution:draconium", dmg = 0,  need = 600,   singu = "universalsingularities:universal.draconicEvolution.singularity", sDmg = 0 },
  { name = "Ториевая",       block = "mcs_addons:tile.thorium_block",     dmg = 0, need = 111, singu = "thermsingul:Thermal Singularity", sDmg = 0 },
  { name = "Обедн. торий",   block = "mcs_addons:tile.thorium_imp_block", dmg = 0, need = 55,  singu = "universalsingularities:universal.bigReactors.singularity", sDmg = 1 },
  { name = "Обогащ. торий",  block = "mcs_addons:tile.thorium_reb_block", dmg = 0, need = 33,  singu = "universalsingularities:universal.bigReactors.singularity", sDmg = 0 },
}

local FIELDS = { "name", "block", "dmg", "need", "singu", "sDmg" }

local function normalize(it)
  it.name = tostring(it.name or "?")
  it.block = tostring(it.block or "")
  it.dmg = tonumber(it.dmg) or 0
  it.need = math.max(1, math.floor(tonumber(it.need) or 1))
  it.singu = tostring(it.singu or "")
  it.sDmg = tonumber(it.sDmg) or 0
  it.rt = it.rt or { nextScan = 0, hist = {} }
  it.rt.order = it.rt.order or { qty = 0 }
  return it
end

local function save()
  local out = {}
  for _, it in ipairs(items) do
    local t = {}
    for _, k in ipairs(FIELDS) do t[k] = it[k] end
    out[#out + 1] = t
  end
  U.writeTable(path(), { v = 1, items = out })
  dirty = false
  lastSave = U.now()
end

function S.init()
  items = {}
  local t = U.readTable(path())
  local src = (t and type(t.items) == "table") and t.items or DEFAULTS
  for _, s in ipairs(src) do items[#items + 1] = normalize(U.copy(s)) end
  local now = U.now()
  for i, it in ipairs(items) do it.rt.nextScan = now + (i - 1) * 0.3 end
end

function S.items() return items end
function S.markDirty() dirty = true end

function S.resetDefaults()
  items = {}
  for _, s in ipairs(DEFAULTS) do items[#items + 1] = normalize(U.copy(s)) end
  dirty = true
  S.rescan()
end

function S.rescan() for _, it in ipairs(items) do it.rt.nextScan = 0 end end

function S.add(spec)
  local it = normalize(spec)
  items[#items + 1] = it
  dirty = true
  return it
end

function S.remove(it)
  for i, x in ipairs(items) do
    if x == it then table.remove(items, i); dirty = true; return true end
  end
end

function S.apply(it, v)
  for k, val in pairs(v) do it[k] = val end
  normalize(it)
  it.rt.nextScan = 0
  it.rt.hist = {}
  dirty = true
end

local function pushHist(rt, now, have)
  local h = rt.hist
  local last = h[#h]
  if last and now - last[1] < 15 then return end
  h[#h + 1] = { now, have }
  while #h > 16 do table.remove(h, 1) end
end

local function onBlock(it, q)
  local rt = it.rt
  if q == nil then return end
  local now = U.now()
  rt.have = q
  rt.haveAt = now
  pushHist(rt, now, q)
  local ready = math.floor(q / it.need)
  if rt.prevReady ~= nil and ready > rt.prevReady and rt.prevReady == 0 and cfg().alert then
    log.info("СИНГУЛЯРКИ", it.name .. ": можно крафтить " .. ready .. " шт")
  end
  rt.prevReady = ready
end

local function onSingu(it, q)
  if q == nil then return end
  it.rt.sing = q
end

-- ───────── заказы («+N» → докрафтить недостающие блоки → скрафтить сингулярку) ─────────
local function cfg2() return cfg() end

local function orderFail(it, why)
  local o = it.rt.order
  o.req, o.reqAmount, o.stage = nil, nil, nil
  o.err = why
  o.nextTry = U.now() + (cfg2().orderCooldown or 20)
  log.warn("СИНГУЛЯРКИ", it.name .. ": заказ — " .. tostring(why))
end

local function orderDone(it, made)
  local o = it.rt.order
  o.qty = math.max(0, (o.qty or 0) - made)
  o.req, o.reqAmount, o.stage, o.err = nil, nil, nil, nil
  o.done = (o.done or 0) + made
  log.info("СИНГУЛЯРКИ", it.name .. ": готово " .. made .. " шт (заказ " .. (o.qty > 0 and ("остаток " .. o.qty) or "выполнен") .. ")")
  if o.qty <= 0 then o.doneAt = U.now() + 6 end
end

-- добавить к заказу (или создать новый); qty может быть отрицательным, чтобы уменьшить/отменить
function S.order(it, qty)
  local o = it.rt.order
  o.qty = math.max(0, (o.qty or 0) + qty)
  o.err = nil
  o.nextTry = 0
  if o.qty <= 0 then S.cancelOrder(it) end
  dirty = true
end

function S.setOrderQty(it, qty)
  local o = it.rt.order
  o.qty = math.max(0, math.floor(qty or 0))
  o.err = nil
  o.nextTry = 0
  dirty = true
end

function S.cancelOrder(it)
  local o = it.rt.order
  if o.req then me.cancel(o.req) end
  o.qty, o.req, o.reqAmount, o.stage, o.err, o.done = 0, nil, nil, nil, nil, nil
  dirty = true
end

-- прогресс текущего заказа: stage, frac, elapsed, eta, gained, total
function S.orderInfo(it)
  local o = it.rt.order
  if not o or (not o.req and (o.qty or 0) <= 0) then return nil end
  if not o.req then
    local stage = nil
    if not o.err then stage = "queue" end
    return { qty = o.qty, stage = stage, err = o.err, retryAt = o.nextTry }
  end
  local now = U.now()
  local total = math.max(1, o.reqAmount or 1)
  local have = (o.stage == "blocks") and (it.rt.have or 0) or (it.rt.sing or 0)
  local gained = math.max(0, have - (o.startAmt or 0))
  local frac = U.clamp(gained / total, 0, 1)
  local elapsed = now - (o.startAt or now)
  local eta
  if frac > 0.02 and frac < 1 then eta = elapsed * (1 - frac) / frac end
  return { qty = o.qty, stage = o.stage, frac = frac, elapsed = elapsed, eta = eta, gained = gained, total = total, err = o.err }
end

local function processOrder(it, now)
  local o = it.rt.order
  if not o or (o.qty or 0) <= 0 then return end
  local rt = it.rt

  if o.req then
    local st = me.status(o.req)
    local have = (o.stage == "blocks") and (rt.have or 0) or (rt.sing or 0)
    local gained = have - (o.startAmt or 0)
    if st == "done" or gained >= (o.reqAmount or 1) then
      if o.stage == "blocks" then
        -- блоков докрафтили достаточно — на следующем проходе запросим сингулярку
        o.req, o.reqAmount, o.stage = nil, nil, nil
        rt.nextScan = 0   -- пересканировать остаток блоков поскорее
      else
        orderDone(it, o.reqAmount or 0)
      end
    elseif st == "canceled" then
      orderFail(it, "отменено в ME")
    elseif st == "failed" then
      orderFail(it, "ошибка ME")
    elseif now - (o.startAt or now) > (cfg2().orderTimeout or 1200) then
      me.cancel(o.req)
      orderFail(it, "таймаут")
    end
    return
  end

  if now < (o.nextTry or 0) then return end
  if rt.have == nil then return end   -- ждём первого скана остатков

  local needed = it.need * o.qty
  if rt.have >= needed then
    local h, err = me.request(it.singu, it.sDmg, o.qty)
    if h then
      o.req, o.reqAmount, o.stage = h, o.qty, "singu"
      o.startAt, o.startAmt = now, rt.sing or 0
      o.err = nil
    else
      orderFail(it, err or "нет рецепта сингулярности")
    end
  else
    local shortfall = needed - rt.have
    local h, err = me.request(it.block, it.dmg, shortfall)
    if h then
      o.req, o.reqAmount, o.stage = h, shortfall, "blocks"
      o.startAt, o.startAmt = now, rt.have or 0
      o.err = nil
    else
      orderFail(it, err or "нехватка блоков, нет рецепта блока")
    end
  end
end

function S.update(now)
  now = now or U.now()
  local offline = (me.online == false)
  for _, it in ipairs(items) do
    local rt = it.rt
    if now >= rt.nextScan then
      rt.nextScan = now + math.max(cfg().scan, offline and 20 or 0)
      me.qty(it.block, it.dmg, function(q) onBlock(it, q) end)
      me.qty(it.singu, it.sDmg, function(q) onSingu(it, q) end)
    end
    if not offline then processOrder(it, now) end
  end
  if dirty and now - lastSave > 3 then save() end
end

function S.flush() if dirty then save() end end

-- ───────── производные данные ─────────
-- have, can, sing, frac, rate (блоков/мин), eta (сек)
function S.info(it)
  local rt = it.rt
  local have = rt.have or 0
  local can = math.floor(have / it.need)
  local frac = U.clamp(have / it.need, 0, 1)
  local rate, eta
  local h = rt.hist
  if #h >= 2 then
    local a, b = h[1], h[#h]
    local dt = b[1] - a[1]
    if dt >= 45 then
      rate = (b[2] - a[2]) / dt * 60
      if can == 0 and rate > 0.01 then eta = (it.need - have) / (rate / 60) end
    end
  end
  return { have = have, can = can, sing = rt.sing or 0, frac = frac, rate = rate, eta = eta, known = rt.have ~= nil }
end

function S.summary()
  local ready, kinds, total = 0, 0, 0
  for _, it in ipairs(items) do
    local n = math.floor((it.rt.have or 0) / it.need)
    if n > 0 then ready = ready + n; kinds = kinds + 1 end
    total = total + (it.rt.sing or 0)
  end
  return { ready = ready, kinds = kinds, singles = total, count = #items }
end

function S.view(sortMode)
  local r = {}
  for i, it in ipairs(items) do r[#r + 1] = { it = it, i = i, info = S.info(it) } end
  table.sort(r, function(a, b)
    if sortMode == "name" then
      if a.it.name ~= b.it.name then return a.it.name < b.it.name end
    elseif sortMode == "progress" then
      if a.info.frac ~= b.info.frac then return a.info.frac > b.info.frac end
    elseif sortMode == "ready" then
      if a.info.can ~= b.info.can then return a.info.can > b.info.can end
      if a.info.frac ~= b.info.frac then return a.info.frac > b.info.frac end
    end
    return a.i < b.i
  end)
  return r
end

return S
