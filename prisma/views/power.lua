-- PRISMA · ЭНЕРГИЯ: энергоядро + карточки реакторов
local P = ...
local U, F, UI, V = P.util, P.fb, P.ui, P.vc
local C = UI.C

local W = { id = "power", title = "ЭНЕРГИЯ" }

local function editTarget()
  P.modal.input("Цель заряда ядра", {
    prompt = "Цель, RF (можно 200G, 1.5T)", numeric = true, value = P.cfg.core.target, min = 0,
    onOk = function(v) P.mods.core.setTarget(v); UI.toast("Цель: " .. U.num(v) .. " RF", "ok") end,
  })
end

local function pickGate()
  local core = P.mods.core
  local items = {}
  for _, a in ipairs(U.compList("flux_gate")) do
    if not P.mods.reactor.usedAddrs()[a] then items[#items + 1] = { addr = a } end
  end
  if #items == 0 then UI.toast("Свободных flux_gate нет", "warn"); return end
  P.modal.pick({
    title = "Выходной шлюз энергоядра", items = items, w = 60, h = 16,
    label = function(it) return U.shortAddr(it.addr) .. "…  поток " .. U.num(tonumber(select(1, U.call(U.proxy(it.addr), "getSignalLowFlow"))) or 0) end,
    onPick = function(it) core.assignGate(it.addr); UI.toast("Шлюз ядра назначен", "ok") end,
  })
end

local function drawCore(x, y, w, h)
  local core = P.mods.core
  local c = core.info()
  local cfg = P.cfg.core
  UI.panel(x, y, w, h, "ЭНЕРГОЯДРО")
  local ix, iw = x + 2, w - 4
  if not core.hasStorage() then UI.textC(ix, y + 4, iw, "накопитель энергии (draconic_rf_storage) не найден", C.bad, C.panel); return end
  local left = math.floor(iw * 0.52)
  UI.text(ix, y + 1, U.num(c.energy) .. " RF", C.bright, C.panel)
  UI.textR(ix, y + 1, left, "из " .. U.num(c.max) .. "  ·  цель " .. U.num(c.target), C.dim, C.panel)
  UI.bar(ix, y + 2, left, c.percent, c.percent > 0.95 and C.warn or C.acc, { label = U.pct(c.percent, 1), marks = { { c.max > 0 and c.target / c.max or 0, C.warn } } })
  UI.graph(ix, y + 4, left, 6, core.history(), nil, nil, C.accdim)
  UI.text(ix, y + 3, "История заряда (≈10 мин)", C.dim, C.panel)
  -- правая часть: показатели и управление
  local rx = ix + left + 3
  local rw = iw - left - 3
  local rate = c.rate * 20
  UI.kv(rx, y + 1, rw, "Приток в секунду", U.signed(rate) .. " RF", rate >= 0 and C.ok or C.warn)
  UI.kv(rx, y + 2, rw, "Выход шлюза", c.hasGate and (U.int(c.flow) .. " RF/t") or "—", C.text)
  local etxt, ecol = core.etaInfo()
  UI.kv(rx, y + 3, rw, "До цели", etxt, C[ecol])
  local gs = c.gateState
  local gtxt = ({ auto = "авто · " .. U.shortAddr(c.gate), manual = "вручную · " .. U.shortAddr(c.gate), none = "не найден", ambiguous = "выберите шлюз" })[gs] or gs
  UI.kv(rx, y + 4, rw, "Шлюз ядра", gtxt, (gs == "auto" or gs == "manual") and C.text or C.warn)
  UI.toggle(rx, y + 6, rw, "Авто-регулировка", cfg.auto, function() core.toggleAuto() end)
  UI.stepper(rx, y + 7, rw, "Цель заряда", U.num(cfg.target), function() core.adjustTarget(-1e9) end, function() core.adjustTarget(1e9) end, editTarget, { vw = 10 })
  UI.button(rx, y + 9, 20, "Выбрать шлюз…", pickGate, { style = (gs == "ambiguous" or gs == "none") and "warn" or "normal" })
  if not cfg.auto and c.hasGate then
    local bx = rx + 22
    for _, b in ipairs({ { "−100k", -1e5 }, { "−10k", -1e4 }, { "+10k", 1e4 }, { "+100k", 1e5 } }) do
      UI.button(bx, y + 9, 7, b[1], function() core.nudgeFlow(b[2]) end)
      bx = bx + 8
    end
  end
  UI.text(rx, y + 10, "Шаг: " .. U.num(cfg.step) .. " · окно: ±" .. U.num(cfg.maxDiff) .. " · поток " .. U.num(cfg.flowMin) .. "…" .. U.num(cfg.flowMax), C.dim, C.panel)
end

local function drawCard(x, y, w, h, i)
  local R = P.mods.reactor
  local rr = R.list()[i]
  local rc = P.cfg.reactors
  if not rr then
    UI.panel(x, y, w, h, "Слот " .. i, { border = C.line, tcolor = C.dim })
    if i == R.count() + 1 then
      UI.textC(x + 1, y + 6, w - 2, "свободен", C.dim, C.panel)
      UI.button(x + 3, y + 8, w - 6, "+ Добавить", function() P.actions.addReactor() end, { style = "primary" })
    end
    return
  end
  local col = V.reactorColor(rr)
  UI.panel(x, y, w, h, "Реактор " .. i, { right = rr.auto and "АВТО" or "РУЧНОЙ", rcolor = rr.auto and C.ok or C.warn, border = (rr.kind == "running") and col or C.line })
  local ix, iw = x + 2, w - 4
  UI.text(ix, y + 1, rr.stateText or "?", col, C.panel)
  if not rr.online then
    UI.text(ix, y + 3, "проверьте адаптер и", C.dim, C.panel)
    UI.text(ix, y + 4, "кабели реактора", C.dim, C.panel)
    UI.button(ix, y + h - 2, iw, "Удалить", function() P.modal.confirm("Удалить реактор", "Убрать реактор " .. i .. " из списка?", function() R.remove(i) end, "Удалить", true) end, { style = "danger" })
    return
  end
  local d = rr.d
  UI.kv(ix, y + 2, iw, "Температура", string.format("%.0f°", d.temp), col)
  UI.bar(ix, y + 3, iw, d.temp / 10000, col, { marks = { { rc.forceModeTemp / 10000, C.dim }, { rc.safeModeTemp / 10000, C.warn }, { rc.tempCrit / 10000, C.bad } } })
  UI.kv(ix, y + 4, iw, "Поле", U.pct(d.field, 1), UI.level(d.field, 0.15, 0.08))
  UI.bar(ix, y + 5, iw, d.field, UI.level(d.field, 0.15, 0.08), { marks = { { rc.targetShield / 100, C.bright } } })
  UI.kv(ix, y + 6, iw, "Насыщение", U.pct(d.sat, 1), C.text)
  UI.bar(ix, y + 7, iw, d.sat, C.accdim)
  UI.kv(ix, y + 8, iw, "Топливо", U.pct(d.fuel, 1), d.fuel > 0.9 and C.bad or C.text)
  UI.bar(ix, y + 9, iw, d.fuel, d.fuel > 0.9 and C.bad or C.warn)
  UI.kv(ix, y + 10, iw, "Генерация", U.num(d.gen) .. "/t", C.ok)
  UI.kv(ix, y + 11, iw, "Расход поля", U.num(d.drain) .. "/t", C.text)
  UI.kv(ix, y + 12, iw, "Вход / выход", U.num(rr.lastIn or 0) .. " / " .. U.num(rr.lastOut or 0), C.text)
  UI.spark(ix, y + 13, iw, rr.hist, nil, nil, col)
  local bw = math.floor((iw - 1) / 2)
  UI.button(ix, y + 14, bw, rr.auto and "Авто ✓" or "Авто", function() R.toggleAuto(i) end, { style = rr.auto and "ok" or "normal" })
  UI.button(ix + bw + 1, y + 14, iw - bw - 1, "Заряд", function() R.charge(i) end, { disabled = rr.kind == "running" })
  local running = rr.kind == "running"
  UI.button(ix, y + 15, iw, running and "■ СТОП" or "▶ СТАРТ", function() R.power(i) end, { style = running and "danger" or "ok" })
  local st = rc.manualStep
  UI.text(ix, y + 16, "Выход", C.dim, C.panel)
  UI.button(ix + 7, y + 16, 5, "−", function() R.adjustFlow(i, -st) end)
  UI.button(ix + 13, y + 16, 5, "+", function() R.adjustFlow(i, st) end)
  UI.textR(ix + 19, y + 16, iw - 19, "±" .. U.num(st), C.dim, C.panel)
  UI.button(ix, y + h - 2, iw, "Удалить", function()
    P.modal.confirm("Удалить реактор", "Убрать реактор " .. i .. " из списка?\n(сам реактор не остановится)", function() R.remove(i) end, "Удалить", true)
  end, { style = "ghost" })
end

function W.draw(x, y, w, h)
  local coreH = 12
  drawCore(x, y, w, coreH)
  local cy = y + coreH
  local cardH = math.min(20, h - coreH)
  local n = P.mods.reactor.max()
  local cols = V.split(x, w, { 1, 1, 1, 1, 1 })
  for i = 1, n do drawCard(cols[i].x, cy, cols[i].w, cardH, i) end
  local rest = h - coreH - cardH
  if rest >= 5 then
    local ry = cy + cardH
    local R = P.mods.reactor
    local t = R.totals()
    local cols2 = V.split(x, w, { 55, 45 })
    -- графики температуры
    local gx, gw = cols2[1].x, cols2[1].w
    UI.panel(gx, ry, gw, rest, "ТЕМПЕРАТУРА РЕАКТОРОВ", { right = string.format("Σ %s RF/t · %.0f/%.0f в работе", U.num(t.gen), t.running, t.count) })
    local list = R.list()
    local inner = rest - 2
    if #list == 0 then
      UI.text(gx + 2, ry + 1, "реакторы не настроены", C.dim, C.panel)
    else
      local per = math.floor(inner / #list)
      local gh = math.max(1, per - 1)
      for i, rr in ipairs(list) do
        local by = ry + 1 + (i - 1) * per
        UI.text(gx + 2, by, string.format("R%.0f", i), V.reactorColor(rr), C.panel)
        if per >= 2 then
          UI.graph(gx + 6, by, gw - 8, math.min(gh, per), rr.hist, 3000, 9500, V.reactorColor(rr))
        else
          UI.spark(gx + 6, by, gw - 8, rr.hist, 0, 10000, V.reactorColor(rr))
        end
      end
    end
    -- журнал
    local ex, ew = cols2[2].x, cols2[2].w
    UI.panel(ex, ry, ew, rest, "ЖУРНАЛ ЭНЕРГЕТИКИ")
    local shown = 0
    local all = P.log.all()
    for i = #all, 1, -1 do
      local e = all[i]
      if e.src:find("РЕАКТОР") or e.src == "ЯДРО" then
        local col = e.lvl == "crit" and C.bad or (e.lvl == "warn" and C.warn or C.text)
        local row = ry + 1 + shown
        UI.text(ex + 2, row, string.sub(e.clock, 1, 5), C.dim, C.panel)
        UI.text(ex + 8, row, U.trunc(e.msg, ew - 11), col, C.panel)
        shown = shown + 1
        if shown >= inner then break end
      end
    end
    if shown == 0 then UI.text(ex + 2, ry + 1, "событий пока нет", C.dim, C.panel) end
  end
end

return W
