-- PRISMA · АВТОКРАФТ: таблица предметов, фильтры, настройки, детали
local P = ...
local U, F, UI, V = P.util, P.fb, P.ui, P.vc
local C = UI.C

local K = { id = "craft", title = "АВТОКРАФТ" }

local FILTERS = { "all", "active", "problems", "off" }
local FILTER_TXT = { all = "все", active = "активные", problems = "проблемы", off = "выключенные" }
local SORTS = { "prio", "name", "state", "need" }
local SORT_TXT = { prio = "приоритет", name = "название", state = "статус", need = "нехватка" }

local function st()
  local s = P.state.craft
  if not s then
    s = { filter = "all", sort = P.cfg.autocraft.sort or "prio", query = "" }
    P.state.craft = s
  end
  return s
end

local lastView = {}

local function setSort(v)
  st().sort = v
  P.cfg.autocraft.sort = v
  P.config.markDirty()
end

local function search()
  P.modal.input("Поиск по названию", {
    prompt = "Часть названия или ID (пусто = сбросить)", value = st().query, w = 60,
    onOk = function(v) st().query = U.trim(tostring(v or "")) end,
  })
end

-- ───────── панель управления ─────────
local function drawToolbar(x, y, w, h)
  local A = P.mods.autocraft
  local cfg = P.cfg.autocraft
  local s = A.summary()
  UI.panel(x, y, w, h, "УПРАВЛЕНИЕ", { right = string.format("всего %.0f · идёт %.0f/%.0f · ждёт %.0f · ошибок %.0f · ок %.0f", s.total, s.running, s.limit, s.want, s.fail, s.ok) })
  local ix, iw = x + 2, w - 4
  local on = A.isActive()
  UI.button(ix, y + 1, 18, on and "■ АВТО: ВКЛ" or "▶ АВТО: ВЫКЛ", function() A.setActive(not on) end, { style = on and "ok" or "danger" })
  UI.button(ix + 19, y + 1, 12, A.isPaused() and "Продолжить" or "Пауза", function() A.togglePause() end, { disabled = not on, style = A.isPaused() and "warn" or "normal" })
  UI.button(ix + 32, y + 1, 16, "Скан сейчас", function() A.rescan(); UI.toast("Пересканирую остатки", "info") end)
  UI.button(ix + 49, y + 1, 18, "+ Добавить…", function() P.actions.craftAdd() end, { style = "primary" })
  local cpu = P.me.cpus(4)
  local ctext = cpu.ok and string.format("CPU: занято %.0f из %.0f", cpu.busy, cpu.total) or "CPU: нет данных"
  UI.textR(ix, y + 1, iw, ctext, C.dim, C.panel)
  local cols = V.split(ix, iw, { 1, 1, 1 }, 2)
  UI.stepper(cols[1].x, y + 2, cols[1].w, "Одновременно", cfg.limit,
    function() cfg.limit = math.max(1, cfg.limit - 1); P.config.markDirty() end,
    function() cfg.limit = math.min(32, cfg.limit + 1); P.config.markDirty() end, nil, { vw = 6 })
  UI.stepper(cols[2].x, y + 2, cols[2].w, "Скан, сек", cfg.scan,
    function() cfg.scan = math.max(2, cfg.scan - 1); P.config.markDirty() end,
    function() cfg.scan = math.min(120, cfg.scan + 1); P.config.markDirty() end, nil, { vw = 6 })
  UI.stepper(cols[3].x, y + 2, cols[3].w, "Резерв CPU", cfg.reserveCpus,
    function() cfg.reserveCpus = math.max(0, cfg.reserveCpus - 1); P.config.markDirty() end,
    function() cfg.reserveCpus = math.min(16, cfg.reserveCpus + 1); P.config.markDirty() end, nil, { vw = 6 })
  local s2 = st()
  UI.cycler(cols[1].x, y + 3, cols[1].w, "Фильтр", FILTER_TXT[s2.filter],
    function() s2.filter = V.nextOf(FILTERS, s2.filter, -1) end,
    function() s2.filter = V.nextOf(FILTERS, s2.filter, 1) end, { vw = 12 })
  UI.cycler(cols[2].x, y + 3, cols[2].w, "Сортировка", SORT_TXT[s2.sort] or s2.sort,
    function() setSort(V.nextOf(SORTS, s2.sort, -1)) end,
    function() setSort(V.nextOf(SORTS, s2.sort, 1)) end, { vw = 12 })
  UI.button(cols[3].x, y + 3, cols[3].w, s2.query ~= "" and ("Поиск: " .. U.trunc(s2.query, cols[3].w - 12) .. "  ×") or "Поиск…", function()
    if s2.query ~= "" then s2.query = "" else search() end
  end, { style = s2.query ~= "" and "primary" or "normal" })
end

-- ───────── таблица ─────────
local function drawTable(x, y, w, h)
  local A = P.mods.autocraft
  local s = st()
  local view = A.view(s.sort, s.filter, s.query)
  lastView = view
  UI.panel(x, y, w, h, "ПРЕДМЕТЫ", { right = #view .. " из " .. A.count() })
  local ix, iw = x + 1, w - 2
  local rows = h - 4
  local first, last, cw = UI.scrollArea("craft.list", ix, y + 3, iw, rows, #view)
  -- колонки
  local c = { idx = 3, on = 3, have = 9, goal = 9, batch = 6, prio = 3, st = 12, bar = 17, tm = 8 }
  local fixed = c.idx + c.on + c.have + c.goal + c.batch + c.prio + c.st + c.bar + c.tm + 9
  c.name = math.max(12, cw - 2 - fixed)
  local function colx()
    local xs, cx = {}, ix + 1
    for _, k in ipairs({ "idx", "on", "name", "have", "goal", "batch", "prio", "st", "bar", "tm" }) do xs[k] = cx; cx = cx + c[k] + 1 end
    return xs
  end
  local xs = colx()
  local function head(key, label, sortKey, right)
    local t = U.pad(label, c[key], right)
    local active = sortKey and s.sort == sortKey
    UI.text(xs[key], y + 1, t, active and C.acc or C.dim, C.panel)
    if sortKey then UI.hitbox(xs[key], y + 1, c[key], 1, function() setSort(sortKey) end) end
  end
  head("idx", "#", nil, true); head("on", "вкл"); head("name", "Предмет", "name")
  head("have", "Есть", "need", true); head("goal", "Цель", nil, true); head("batch", "Парт.", nil, true)
  head("prio", "Пр", "prio", true); head("st", "Статус", "state"); head("bar", "Прогресс"); head("tm", "Время", nil, true)
  UI.hline(ix + 1, y + 2, iw - 2, C.line)

  if #view == 0 then
    UI.textC(ix, y + 5, iw, A.count() == 0 and "Список пуст — нажмите «+ Добавить…»" or "Нет предметов под фильтр", C.dim, C.panel)
  end
  for i = first, last do
    local it = view[i]
    local rt = it.rt
    local ry = y + 3 + (i - first)
    local sel = (P.state.sel == it)
    local bg = sel and C.accbg or ((i % 2 == 0) and 0x171717 or C.panel)
    F.rect(ix, ry, cw, 1, bg)
    UI.text(xs.idx, ry, U.pad(tostring(i), c.idx, true), C.dim, bg)
    UI.text(xs.on, ry, it.enabled and " ● " or " ○ ", it.enabled and C.ok or C.dim, bg)
    UI.hitbox(xs.on, ry, c.on, 1, function() it.enabled = not it.enabled; A.markDirty() end)
    UI.text(xs.name, ry, U.pad(it.label .. (it.once and " ·1×" or ""), c.name), sel and C.bright or C.text, bg)
    local tgt = A.target(it)
    local have = rt.have
    UI.text(xs.have, ry, U.pad(have and U.num(have) or "…", c.have, true), (have and have >= tgt) and C.ok or C.warn, bg)
    UI.text(xs.goal, ry, U.pad(U.num(tgt), c.goal, true), C.text, bg)
    UI.text(xs.batch, ry, U.pad(U.num(it.batch), c.batch, true), C.dim, bg)
    UI.text(xs.prio, ry, U.pad(tostring(it.prio), c.prio, true), it.prio >= 7 and C.warn or C.dim, bg)
    local stt, stc = V.stateText(it.enabled and rt.state or "off")
    UI.text(xs.st, ry, U.pad(stt, c.st), stc, bg)
    local frac, el, eta = A.progress(it)
    if frac then
      UI.bar(xs.bar, ry, c.bar, frac, C.ok, { label = U.pct(frac) })
      UI.textR(xs.tm, ry, c.tm, U.dur(el), C.text, bg)
    else
      if have and have < tgt then UI.text(xs.bar, ry, U.pad("нужно " .. U.num(tgt - have), c.bar), C.dim, bg) end
      UI.textR(xs.tm, ry, c.tm, rt.dur and U.dur(rt.dur) or "", C.dim, bg)
    end
    UI.hitbox(ix, ry, cw, 1, function()
      if P.state.sel == it then P.actions.craftEdit(it) else P.state.sel = it end
    end)
  end
end

-- ───────── детали ─────────
local function drawDetail(x, y, w, h)
  local A = P.mods.autocraft
  local it = P.state.sel
  local found = false
  for _, x2 in ipairs(A.items()) do if x2 == it then found = true end end
  if not found then it = nil; P.state.sel = nil end
  UI.panel(x, y, w, h, it and ("ВЫБРАНО: " .. U.trunc(it.label, 40)) or "ДЕТАЛИ")
  local ix, iw = x + 2, w - 4
  if not it then
    UI.textC(ix, y + math.floor(h / 2), iw, "Выберите предмет в таблице (повторный клик — редактирование)", C.dim, C.panel)
    return
  end
  local rt = it.rt
  local cfg = P.cfg.autocraft
  local stt, stc = V.stateText(it.enabled and rt.state or "off")
  local half = math.floor(iw / 2)
  UI.kv(ix, y + 1, half - 2, "ID", it.name .. ":" .. it.damage, C.dim)
  UI.kv(ix, y + 2, half - 2, "Состояние", stt .. (V.reasonText(it) ~= "" and (" · " .. V.reasonText(it)) or ""), stc)
  UI.kv(ix, y + 3, half - 2, "Держать / партия", string.format("%s / %s", U.int(it.keep), U.int(it.batch)), C.text)
  UI.kv(ix, y + 4, half - 2, "Порог запуска", it.trigger .. "% цели", C.text)
  local rx = ix + half + 1
  UI.kv(rx, y + 1, half - 1, "Изготовлено всего", U.int(it.total) .. " шт", C.ok)
  UI.kv(rx, y + 2, half - 1, "Заказов", tostring(it.runs), C.text)
  UI.kv(rx, y + 3, half - 1, "Пауза / тайм-аут", string.format("%.0fс / %s", it.cooldown or cfg.cooldown, U.dur(it.timeout or cfg.timeout)), C.text)
  UI.kv(rx, y + 4, half - 1, "Заметка", it.note ~= "" and it.note or "—", C.dim)
  local by = y + h - 2
  local bx = ix
  local function btn(label, fn, o)
    local bw = U.ulen(label) + 4
    UI.button(bx, by, bw, label, fn, o)
    bx = bx + bw + 1
  end
  btn("Изменить", function() P.actions.craftEdit(it) end, { style = "primary" })
  btn(it.enabled and "Выключить" or "Включить", function() it.enabled = not it.enabled; A.markDirty() end)
  btn("Заказать сейчас", function()
    if not A.isActive() then UI.toast("Сначала включите АВТО", "warn"); return end
    rt.nextTry, rt.cool, rt.nextScan = 0, 0, 0
    UI.toast("Проверяю и заказываю: " .. it.label, "info")
  end, { disabled = rt.req ~= nil })
  btn("Отменить крафт", function() A.cancel(it) end, { disabled = rt.req == nil, style = "warn" })
  btn("Удалить", function()
    P.modal.confirm("Удалить предмет", "Убрать «" .. it.label .. "» из автокрафта?", function() A.remove(it); P.state.sel = nil end, "Удалить", true)
  end, { style = "danger" })
end

function K.draw(x, y, w, h)
  local tbH = 6
  local detH = h >= 30 and 8 or 0
  drawToolbar(x, y, w, tbH)
  drawTable(x, y + tbH, w, h - tbH - detH)
  if detH > 0 then drawDetail(x, y + h - detH, w, detH) end
end

-- клавиши: стрелки двигают выбор
function K.key(char, code)
  if code ~= 200 and code ~= 208 and code ~= 201 and code ~= 209 then return false end
  local view = lastView
  if #view == 0 then return true end
  local idx = 0
  for i, it in ipairs(view) do if it == P.state.sel then idx = i end end
  local d = (code == 200 and -1) or (code == 208 and 1) or (code == 201 and -10) or 10
  idx = U.clamp(idx + d, 1, #view)
  P.state.sel = view[idx]
  UI.scrollTo("craft.list", idx)
  return true
end

return K
