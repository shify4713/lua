-- PRISMA · ДАШБОРД: ядро, реакторы, ME, что крафтится сейчас, сингулярки, радар, чат, события
local P = ...
local U, F, UI, V = P.util, P.fb, P.ui, P.vc
local C = UI.C

local D = { id = "dash", title = "ДАШБОРД" }

local function fnum(v) return U.num(v) end

-- ───────── ядро ─────────
local function drawCore(x, y, w, h)
  local core = P.mods.core
  local c = core.info()
  UI.panel(x, y, w, h, "ЭНЕРГОЯДРО", { right = c.hasGate and ("шлюз " .. U.shortAddr(c.gate)) or nil })
  local ix, iw = x + 2, w - 4
  if not core.hasStorage() then
    UI.textC(ix, y + 4, iw, "накопитель не найден", C.bad, C.panel)
    UI.textC(ix, y + 5, iw, "(draconic_rf_storage)", C.dim, C.panel)
    return
  end
  if not c.online then UI.textC(ix, y + 4, iw, "нет связи с ядром", C.bad, C.panel); return end
  UI.text(ix, y + 1, fnum(c.energy), C.bright, C.panel)
  UI.textR(ix, y + 1, iw, "/ " .. fnum(c.max) .. " RF", C.dim, C.panel)
  local col = c.percent > 0.95 and C.warn or C.acc
  UI.bar(ix, y + 2, iw, c.percent, col, { label = U.pct(c.percent, 1), marks = { { c.max > 0 and c.target / c.max or 0, C.warn } } })
  local rate = c.rate * 20
  UI.kv(ix, y + 3, iw, "Приток/сек", U.signed(rate) .. " RF", rate >= 0 and C.ok or C.warn)
  UI.kv(ix, y + 4, iw, "Выход шлюза", c.hasGate and (fnum(c.flow) .. " RF/t") or "нет шлюза", c.hasGate and C.text or C.warn)
  local etxt, ecol = core.etaInfo()
  UI.kv(ix, y + 5, iw, "Цель " .. fnum(c.target), etxt, C[ecol])
  UI.graph(ix, y + 6, iw, 3, core.history(), nil, nil, C.accdim)
  local bw = math.floor((iw - 3) / 4)
  local cfg = P.cfg.core
  local bx = ix
  for _, b in ipairs({ { "−10G", -10e9 }, { "−1G", -1e9 }, { "+1G", 1e9 }, { "+10G", 10e9 } }) do
    UI.button(bx, y + h - 2, bw, b[1], function() core.adjustTarget(b[2]) end)
    bx = bx + bw + 1
  end
  UI.toggle(ix, y + h - 3, iw, "Авто-регулировка", cfg.auto, function() core.toggleAuto() end)
end

-- ───────── реакторы ─────────
local function drawReactors(x, y, w, h)
  local R = P.mods.reactor
  local t = R.totals()
  UI.panel(x, y, w, h, "РЕАКТОРЫ", { right = string.format("%.0f/%.0f в работе · %s RF/t", t.running, t.count, U.num(t.gen)) })
  local ix, iw = x + 2, w - 4
  local list = R.list()
  if #list == 0 then
    UI.textC(ix, y + 3, iw, "реакторы не настроены", C.dim, C.panel)
    UI.button(ix + math.floor(iw / 2) - 12, y + 5, 24, "+ Добавить реактор", function() P.actions.addReactor() end, { style = "primary" })
    return
  end
  local nameW = 2
  local stW = 10
  local tW = 6
  local barW = math.max(6, math.floor(iw * 0.2))
  local restW = iw - (nameW + stW + tW + barW + 4)
  UI.text(ix, y + 1, U.pad("#", nameW) .. " " .. U.pad("Состояние", stW) .. " " .. U.pad("Темп", tW, true) .. " " .. U.pad("", barW) .. " Поле  Топл.  Ген", C.dim, C.panel)
  for i, rr in ipairs(list) do
    local ry = y + 1 + i
    if ry >= y + h - 3 then break end
    local col = V.reactorColor(rr)
    UI.text(ix, ry, U.pad(tostring(i), nameW), C.dim, C.panel)
    UI.text(ix + nameW + 1, ry, U.pad(rr.stateText or "?", stW), col, C.panel)
    if rr.online then
      local d = rr.d
      local rc = P.cfg.reactors
      UI.textR(ix + nameW + stW + 2, ry, tW, string.format("%.0f°", d.temp), col, C.panel)
      UI.bar(ix + nameW + stW + tW + 3, ry, barW, d.temp / 10000, col, { marks = { { rc.forceModeTemp / 10000, C.dim }, { rc.safeModeTemp / 10000, C.warn }, { rc.tempCrit / 10000, C.bad } } })
      local rx = ix + nameW + stW + tW + barW + 4
      UI.text(rx, ry, U.pad(string.format("%.0f%%", d.field * 100), 5), UI.level(d.field, 0.15, 0.08), C.panel)
      UI.text(rx + 6, ry, U.pad(string.format("%.0f%%", d.fuel * 100), 5), d.fuel > 0.9 and C.bad or C.text, C.panel)
      UI.textR(rx + 12, ry, math.max(4, restW - 12), U.num(d.gen), C.ok, C.panel)
    end
  end
  local by = y + h - 2
  UI.button(ix, by, 20, "+ Добавить", function() P.actions.addReactor() end, { disabled = #list >= R.max() })
  UI.button(ix + iw - 22, by, 22, "■ СТОП ВСЕХ", function()
    P.modal.confirm("Аварийная остановка", "Остановить все реакторы?", function() R.stopAll() end, "Остановить", true)
  end, { style = "danger" })
end

-- ───────── ME / система ─────────
local function drawSystem(x, y, w, h)
  local me = P.me
  local A = P.mods.autocraft
  UI.panel(x, y, w, h, "СЕТЬ ME")
  local ix, iw = x + 2, w - 4
  local online, txt, col
  if not me.available() then txt, col = "НЕ НАЙДЕНА", C.bad
  elseif me.online == false then txt, col = "НЕТ СВЯЗИ", C.bad
  elseif me.online then txt, col = "ОНЛАЙН", C.ok
  else txt, col = "ПРОВЕРКА", C.warn end
  UI.kv(ix, y + 1, iw, "Статус", txt, col)
  local cp = me.cpus(4)
  if cp.ok and cp.total > 0 then
    UI.text(ix, y + 2, "CPU крафта", C.dim, C.panel)
    UI.textR(ix, y + 2, iw, string.format("%.0f занято из %.0f", cp.busy, cp.total), C.text, C.panel)
    UI.bar(ix, y + 3, iw, cp.busy / cp.total, cp.busy >= cp.total and C.warn or C.acc)
  else
    UI.kv(ix, y + 2, iw, "CPU крафта", "—", C.dim)
  end
  local pw = me.power()
  if pw and pw.max and pw.max > 0 then
    UI.kv(ix, y + 4, iw, "Энергия ME", U.pct((pw.stored or 0) / pw.max), C.text)
  end
  local s = A.summary()
  UI.kv(ix, y + 5, iw, "Автокрафт", string.format("идёт %.0f · ждёт %.0f · ошибок %.0f", s.running, s.want, s.fail), s.fail > 0 and C.warn or C.text)
  local sg = P.mods.singularity.summary()
  UI.kv(ix, y + 6, iw, "Сингулярки", sg.ready > 0 and ("готово " .. sg.ready .. " шт") or "копятся", sg.ready > 0 and C.ok or C.dim)
  UI.toggle(ix, y + h - 3, iw, "Автокрафт", A.isActive(), function() A.setActive(not A.isActive()) end)
  local free, total = U.freeMem()
  UI.kv(ix, y + h - 2, iw, "ОЗУ / кадр", string.format("%.0f%% · %.0fмс", (1 - free / total) * 100, P.state.drawMs or 0), C.dim)
end

-- ───────── что крафтится сейчас ─────────
local function drawCrafting(x, y, w, h)
  local A = P.mods.autocraft
  local list = A.crafting()
  UI.panel(x, y, w, h, "СЕЙЧАС КРАФТИТСЯ", { right = A.isActive() and (A.isPaused() and "пауза" or "авто вкл") or "авто выкл", rcolor = A.isActive() and C.ok or C.warn })
  local ix, iw = x + 2, w - 4
  local cols = { name = math.max(16, iw - 66), bar = 18, cnt = 11, el = 7, eta = 7, st = 10 }
  UI.text(ix, y + 1, U.pad("Предмет", cols.name) .. " " .. U.pad("Прогресс", cols.bar) .. " " .. U.pad("Сделано", cols.cnt) .. " " .. U.pad("Прошло", cols.el, true) .. " " .. U.pad("Осталось", cols.eta + 1, true), C.dim, C.panel)
  UI.hline(ix, y + 2, iw, C.line)
  local row = y + 3
  local maxRows = h - 6
  if #list == 0 then
    UI.textC(ix, row + 1, iw, A.isActive() and "Сейчас ничего не крафтится" or "Автокрафт выключен", C.dim, C.panel)
  end
  for i, it in ipairs(list) do
    if i > maxRows then
      UI.text(ix, row, "… ещё " .. (#list - maxRows), C.dim, C.panel)
      break
    end
    local frac, el, eta, gained, total = A.progress(it)
    frac = frac or 0
    local x0 = ix
    UI.text(x0, row, U.pad(it.label, cols.name), C.bright, C.panel); x0 = x0 + cols.name + 1
    UI.bar(x0, row, cols.bar, frac, it.rt.state == "plan" and C.accdim or C.ok, { label = U.pct(frac) }); x0 = x0 + cols.bar + 1
    UI.text(x0, row, U.pad(U.int(gained) .. "/" .. U.int(total), cols.cnt), C.text, C.panel); x0 = x0 + cols.cnt + 1
    UI.textR(x0, row, cols.el, U.dur(el), C.dim, C.panel); x0 = x0 + cols.el + 1
    UI.textR(x0, row, cols.eta + 1, eta and U.dur(eta) or "…", C.acc, C.panel)
    row = row + 1
  end
  -- недавно завершённые
  local hist = A.history()
  local free = (y + h - 2) - row
  if free >= 3 and #hist > 0 then
    UI.hline(ix, row, iw, C.line)
    UI.text(ix + 1, row, " Недавно завершено ", C.dim, C.panel)
    row = row + 1
    local n = 0
    for i = #hist, 1, -1 do
      if row > y + h - 2 or n >= 5 then break end
      local e = hist[i]
      UI.text(ix, row, U.pad(e.label, cols.name), C.text, C.panel)
      UI.text(ix + cols.name + 1, row, "+" .. U.int(e.amount), C.ok, C.panel)
      UI.textR(ix + iw - 20, row, 20, U.dur(e.dur) .. " назад " .. U.dur(U.now() - e.t), C.dim, C.panel)
      row = row + 1
      n = n + 1
    end
  end
end

local function drawQueue(x, y, w, h)
  local A = P.mods.autocraft
  UI.panel(x, y, w, h, "ОЧЕРЕДЬ И ПРОБЛЕМЫ")
  local ix, iw = x + 2, w - 4
  local row = y + 1
  local last = y + h - 2
  local probs = A.problems()
  if #probs > 0 then
    UI.text(ix, row, "Ошибки (" .. #probs .. ")", C.bad, C.panel); row = row + 1
    for _, it in ipairs(probs) do
      if row > last - 2 then break end
      UI.text(ix, row, U.trunc(it.label, math.floor(iw * 0.5)), C.text, C.panel)
      UI.textR(ix, row, iw, V.reasonText(it), C.bad, C.panel)
      row = row + 1
    end
    row = row + 1
  end
  local waiting = {}
  for _, it in ipairs(A.items()) do
    if it.rt.state == "want" or (A.isActive() == false and it.enabled and it.rt.want) then waiting[#waiting + 1] = it end
  end
  if #waiting > 0 and row <= last then
    UI.text(ix, row, "Ждут очереди (" .. #waiting .. ")", C.warn, C.panel); row = row + 1
    for _, it in ipairs(waiting) do
      if row > last then break end
      UI.text(ix, row, U.trunc(it.label, math.floor(iw * 0.6)), C.text, C.panel)
      UI.textR(ix, row, iw, string.format("%s / %s", U.num(it.rt.have or 0), U.num(A.target(it))), C.dim, C.panel)
      row = row + 1
    end
  end
  if #probs == 0 and #waiting == 0 then
    UI.textC(ix, y + math.floor(h / 2), iw, "всё в порядке", C.ok, C.panel)
  end
end

-- ───────── нижний ряд ─────────
local function drawSing(x, y, w, h)
  local S = P.mods.singularity
  local sm = S.summary()
  UI.panel(x, y, w, h, "СИНГУЛЯРКИ", { right = sm.ready > 0 and ("готово: " .. sm.ready) or nil, rcolor = C.ok })
  local ix, iw = x + 2, w - 4
  -- сначала активные заказы, затем остальные по готовности
  local orders, rest = {}, {}
  for _, e in ipairs(S.view("ready")) do
    local oi = S.orderInfo(e.it)
    if oi then orders[#orders + 1] = e else rest[#rest + 1] = e end
  end
  local row = 0
  for _, e in ipairs(orders) do
    row = row + 1
    if row > h - 2 then break end
    local oi = S.orderInfo(e.it)
    local ry = y + row
    UI.text(ix, ry, U.pad(e.it.name, 14), C.acc, C.panel)
    local label = oi.stage and (({ blocks = "крафтю блоки", singu = "крафтю сингулярку" })[oi.stage] or oi.stage) or "в очереди"
    if oi.frac then
      UI.bar(ix + 15, ry, iw - 15 - 8, oi.frac, oi.stage == "blocks" and C.warn or C.ok, { label = label })
    else
      UI.text(ix + 15, ry, label, oi.err and C.bad or C.warn, C.panel)
    end
    UI.textR(ix + iw - 7, ry, 7, oi.qty .. " шт", C.acc, C.panel)
  end
  for _, e in ipairs(rest) do
    row = row + 1
    if row > h - 2 then break end
    local ry = y + row
    local info = e.info
    UI.text(ix, ry, U.pad(e.it.name, 14), info.can > 0 and C.ok or C.text, C.panel)
    UI.bar(ix + 15, ry, iw - 15 - 8, info.frac, info.can > 0 and C.ok or C.accdim)
    UI.textR(ix + iw - 7, ry, 7, info.can > 0 and ("×" .. info.can) or U.pct(info.frac), info.can > 0 and C.ok or C.dim, C.panel)
  end
end

local function drawRadar(x, y, w, h)
  local Rd = P.mods.radar
  local list = Rd.list()
  UI.panel(x, y, w, h, "РАДАР", { right = Rd.available() and (#list .. " рядом") or "нет датчика", rcolor = #list > 0 and C.bad or C.dim })
  local ix, iw = x + 2, w - 4
  if not Rd.available() then UI.textC(ix, y + 2, iw, "датчик не найден", C.dim, C.panel); return end
  if #list == 0 then UI.textC(ix, y + 2, iw, "чисто", C.ok, C.panel); return end
  for i, p in ipairs(list) do
    if i > h - 2 then break end
    UI.text(ix, y + i, "● " .. U.trunc(p.display, iw - 8), C.bad, C.panel)
    if p.dist then UI.textR(ix, y + i, iw, string.format("%.0fм", p.dist), C.dim, C.panel) end
  end
end

local function drawChat(x, y, w, h)
  local Ch = P.mods.chat
  UI.panel(x, y, w, h, "ЧАТ", { right = Ch.available() and nil or "нет chat_box" })
  local ix, iw = x + 2, w - 4
  local logs = Ch.logs()
  local n = h - 2
  for i = 0, n - 1 do
    local e = logs[#logs - n + 1 + i]
    if e then
      UI.text(ix, y + 1 + i, U.trunc(e.name, 10), C.acc, C.panel)
      UI.text(ix + math.min(11, U.ulen(e.name) + 1), y + 1 + i, U.trunc(e.msg, iw - math.min(11, U.ulen(e.name) + 1)), C.text, C.panel)
    end
  end
end

local LVL = { info = "dim", warn = "warn", crit = "bad" }
local function drawEvents(x, y, w, h)
  UI.panel(x, y, w, h, "СОБЫТИЯ", { right = P.log.counts.crit > 0 and ("аварий: " .. P.log.counts.crit) or nil, rcolor = C.bad })
  local ix, iw = x + 2, w - 4
  local list = P.log.recent(h - 2)
  for i, e in ipairs(list) do
    local ry = y + h - 1 - (#list - i + 1)
    UI.text(ix, ry, string.sub(e.clock, 1, 5), C.dim, C.panel)
    UI.text(ix + 6, ry, U.trunc(e.msg, iw - 6), C[LVL[e.lvl]] or C.text, C.panel)
  end
end

function D.draw(x, y, w, h)
  local topH = 12
  local midH = math.min(17, math.max(9, math.floor(h * 0.36)))
  local botH = h - topH - midH
  local cols = V.split(x, w, { 32, 40, 28 })
  drawCore(cols[1].x, y, cols[1].w, topH)
  drawReactors(cols[2].x, y, cols[2].w, topH)
  drawSystem(cols[3].x, y, cols[3].w, topH)
  local mid = V.split(x, w, { 64, 36 })
  drawCrafting(mid[1].x, y + topH, mid[1].w, midH)
  drawQueue(mid[2].x, y + topH, mid[2].w, midH)
  if botH >= 5 then
    local b = V.split(x, w, { 34, 20, 24, 22 })
    drawSing(b[1].x, y + topH + midH, b[1].w, botH)
    drawRadar(b[2].x, y + topH + midH, b[2].w, botH)
    drawChat(b[3].x, y + topH + midH, b[3].w, botH)
    drawEvents(b[4].x, y + topH + midH, b[4].w, botH)
  end
end

return D
