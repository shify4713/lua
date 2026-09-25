-- PRISMA · НАСТРОЙКИ: страницы со списками параметров (данные → интерфейс)
local P = ...
local U, F, UI, V = P.util, P.fb, P.ui, P.vc
local C = UI.C
local component = require("component")

local S = { id = "set", title = "НАСТР.", scrollId = "set.list" }

local function cfgGet(path)
  local t = P.cfg
  for i = 1, #path do t = t[path[i]] end
  return t
end

local function cfgSet(path, v)
  local t = P.cfg
  for i = 1, #path - 1 do t = t[path[i]] end
  t[path[#path]] = v
  P.config.markDirty()
end

-- ───────── конструкторы строк ─────────
local function Sec(title) return { k = "sec", label = title } end
local function B(label, path, hint, after) return { k = "bool", label = label, path = path, hint = hint, after = after } end
local function N(label, path, min, max, step, o)
  o = o or {}
  return { k = "num", label = label, path = path, min = min, max = max, step = step, big = o.big, fmt = o.fmt, int = o.int, hint = o.hint, after = o.after, dec = o.dec }
end
local function E(label, path, options, hint, after) return { k = "enum", label = label, path = path, options = options, hint = hint, after = after } end
local function Btn(label, fn, hint, style) return { k = "btn", label = label, fn = fn, hint = hint, style = style } end
local function Info(label, fn, color) return { k = "info", label = label, get = fn, color = color } end

local function reinit()
  if P.reinitDevices then P.reinitDevices() end
end

local function tf(dec) return function(v) return string.format("%." .. dec .. "f", v) end end
local unumf = function(v) return U.num(v) end

-- ───────── устройства ─────────
local ROLES = {
  { key = "me", label = "ME-интерфейс", types = { "me_interface", "me_controller", "ae2_interface" } },
  { key = "storage", label = "Накопитель ядра", types = { "draconic_rf_storage" } },
  { key = "coreGate", label = "Выходной шлюз ядра", types = { "flux_gate" } },
  { key = "sensor", label = "Датчик игроков", types = { "sensor", "openperipheral_sensor" } },
  { key = "glasses", label = "Мост очков", types = { "openperipheral_bridge", "glasses_bridge", "terminal_glasses_bridge", "glasses" } },
  { key = "chat", label = "Чат-бокс", types = { "chat_box" } },
}

local function candidates(role)
  local r, used = {}, P.mods.reactor.usedAddrs()
  for _, t in ipairs(role.types) do
    for _, a in ipairs(U.compList(t)) do
      if not (role.key == "coreGate" and used[a]) then r[#r + 1] = { addr = a, type = t } end
    end
  end
  return r
end

local function pickDevice(role)
  local list = candidates(role)
  if #list == 0 then UI.toast("Подходящих устройств не найдено", "warn"); return end
  P.modal.pick({
    title = role.label, items = list, w = 64, h = math.min(20, #list + 10),
    label = function(it) return it.type .. "  " .. it.addr end,
    onPick = function(it)
      P.cfg.devices[role.key] = it.addr
      P.config.markDirty()
      reinit()
      UI.toast(role.label .. ": привязано " .. U.shortAddr(it.addr), "ok")
    end,
  })
end

local function deviceRows()
  local rows = { Sec("Привязка устройств (пусто = автоматически)") }
  for _, role in ipairs(ROLES) do
    rows[#rows + 1] = { k = "device", role = role }
  end
  rows[#rows + 1] = Sec("Найдено в сети компьютера")
  local seen = {}
  for a, t in component.list() do seen[#seen + 1] = { a = a, t = t } end
  table.sort(seen, function(x, y) if x.t ~= y.t then return x.t < y.t end return x.a < y.a end)
  for _, s in ipairs(seen) do
    rows[#rows + 1] = { k = "info", label = s.t, get = function() return s.a end, color = C.dim }
  end
  return rows
end

-- ───────── радар: список игнора ─────────
local function radarRows()
  local rows = {
    Sec("Датчик"),
    B("Сообщать о новых игроках", { "radar", "alert" }, "запись в журнал и сигнал"),
    N("Опрос, сек", { "radar", "interval" }, 0.5, 30, 0.5, { dec = 1, fmt = tf(1) }),
    Sec("Игнорируемые ники"),
  }
  for i, name in ipairs(P.cfg.radar.ignore) do
    rows[#rows + 1] = { k = "ignore", idx = i, name = name }
  end
  rows[#rows + 1] = Btn("+ Добавить ник", function()
    P.modal.input("Игнорировать игрока", { prompt = "Ник", value = "", onOk = function(v) P.mods.radar.addIgnore(v) end })
  end)
  return rows
end

-- ───────── система ─────────
local function systemRows()
  local rows = {
    Sec("Программа"),
    Info("Версия", function() return "PRISMA " .. P.VERSION end),
    Info("Работает", function() return U.dur(U.now() - P.startedAt) end),
    Info("Разрешение", function() local w, h = P.fb.size(); return w .. "×" .. h end),
    Info("ОЗУ занято", function() local f, t = U.freeMem(); return string.format("%.0f%% (%.0f КБ свободно)", (1 - f / t) * 100, f / 1024) end),
    Info("Кадр", function() return string.format("%.0f мс · вывод: %.0f вызовов GPU", P.state.drawMs or 0, P.fb.calls or 0) end),
    Info("ME запросов / ошибок", function() return P.me.calls .. " / " .. P.me.errors end),
    Info("Очередь ME", function() return tostring(P.me.queueSize()) end),
    Sec("Задачи (среднее время, мс)"),
  }
  for _, t in ipairs(P.tasks or {}) do
    rows[#rows + 1] = Info(t.name, function()
      return string.format("%.1f мс%s", t.ms * 1000, t.errs > 0 and ("  ошибок: " .. t.errs) or "")
    end, nil)
  end
  rows[#rows + 1] = Sec("Действия")
  rows[#rows + 1] = Btn("Сохранить всё сейчас", function() P.saveAll(); UI.toast("Сохранено", "ok") end, nil, "ok")
  rows[#rows + 1] = Btn("Сбросить настройки", function()
    P.modal.confirm("Сброс настроек", "Вернуть все настройки по умолчанию?\nСписки предметов и реакторов не затрагиваются.", function()
      P.config.reset(); UI.setTheme(P.cfg.ui.theme); UI.toast("Настройки сброшены", "warn")
    end, "Сбросить", true)
  end, nil, "warn")
  rows[#rows + 1] = Btn("Перезапустить программу", function() P.restart() end)
  rows[#rows + 1] = Btn("Выход в консоль", function()
    P.modal.confirm("Выход", "Закрыть PRISMA?\nАвтоматика реакторов и ядра остановится!", function() P.quit() end, "Выйти", true)
  end, nil, "danger")
  return rows
end

-- ───────── страницы ─────────
local THEME_OPT = { { "cyan", "Голубая" }, { "green", "Зелёная" }, { "amber", "Янтарная" }, { "violet", "Фиолетовая" } }
local CLOCK_OPT = { { "real", "время сервера" }, { "game", "игровые сутки" }, { "uptime", "с запуска программы" } }
local SORT_OPT = { { "prio", "приоритет" }, { "name", "название" }, { "state", "статус" }, { "need", "нехватка" } }
local SSORT_OPT = { { "ready", "готовые" }, { "progress", "прогресс" }, { "name", "название" } }

local PAGES = {
  { id = "general", title = "Общие", rows = function()
    return {
      Sec("Внешний вид"),
      E("Тема", { "ui", "theme" }, THEME_OPT, "цвет акцентов", function(v) UI.setTheme(v) end),
      N("Ширина экрана", { "ui", "w" }, 100, 160, 10, { int = true, hint = "нужно «Применить»" }),
      N("Высота экрана", { "ui", "h" }, 30, 50, 5, { int = true }),
      Btn("Применить разрешение", function() P.applyResolution() end),
      N("Обновление, кадр/с", { "ui", "fps" }, 1, 10, 1, { int = true, hint = "экран перерисовывается только при изменениях" }),
      Sec("Поведение"),
      B("Звуковые сигналы", { "ui", "sound" }, "при авариях и предупреждениях"),
      B("Авто-перезапуск после сбоя", { "ui", "autoRestart" }, "watchdog"),
      Sec("Часы"),
      E("Источник времени", { "clock", "mode" }, CLOCK_OPT, "«время сервера» — самое точное, без интернета"),
      N("Часовой пояс, ч от UTC", { "clock", "tz" }, -12, 14, 1, { int = true }),
      Info("Сейчас показывает", function() return U.clock() end),
      Sec("Сеть ME (главный регулятор нагрузки на сервер)"),
      N("Опрос очереди ME, сек", { "me", "interval" }, 0.05, 5, 0.1, { dec = 2, fmt = tf(2), hint = "меньше = отзывчивее, больше = меньше лагов" }),
      N("Запросов за проход", { "me", "batch" }, 1, 10, 1, { int = true }),
      N("Лимит списка сети ME", { "me", "networkLimit" }, 200, 10000, 100, { int = true, big = 1000, hint = "защита от нехватки памяти при просмотре сети" }),
      Btn("Экономный режим (замедлить всё)", function() P.applyEcoMode() end, "снижает частоту опросов всех модулей разом", "warn"),
      Sec("Модули"),
      B("Реакторы", { "modules", "reactors" }),
      B("Энергоядро", { "modules", "core" }),
      B("Автокрафт (сканирование)", { "modules", "autocraft" }, "«АВТО» включается на вкладке крафта"),
      B("Сингулярки", { "modules", "singularity" }),
      B("Очки (HUD)", { "modules", "glasses" }, nil, function(v) if not v then P.mods.glasses.clear() end end),
      B("Радар", { "modules", "radar" }),
      B("Чат", { "modules", "chat" }),
    }
  end },
  { id = "reactors", title = "Реакторы", rows = function()
    return {
      Sec("Управление"),
      N("Целевое поле, %", { "reactors", "targetShield" }, 5, 50, 1, { int = true, hint = "входной шлюз = расход / (1 − поле)" }),
      N("Начало форс-режима, °C", { "reactors", "forceModeTemp" }, 2000, 9000, 100, { int = true, big = 500 }),
      N("Безопасная темп., °C", { "reactors", "safeModeTemp" }, 2000, 9500, 100, { int = true, big = 500 }),
      N("Критическая темп., °C", { "reactors", "tempCrit" }, 2000, 9800, 100, { int = true, big = 500 }),
      N("Начальный выход, RF/t", { "reactors", "initialFlow" }, 0, 5e7, 5000, { big = 50000, fmt = unumf, int = true }),
      N("Шаг ручной правки, RF/t", { "reactors", "manualStep" }, 1000, 1e6, 1000, { big = 10000, fmt = unumf, int = true }),
      N("Опрос одного реактора, с", { "reactors", "interval" }, 0.25, 5, 0.25, { dec = 2, fmt = tf(2) }),
      Sec("Защита"),
      B("Аварийная остановка", { "reactors", "emergency" }, "авто-стоп при перегреве / падении поля"),
      N("Стоп при температуре, °C", { "reactors", "tempEmergency" }, 3000, 9900, 100, { int = true, big = 500 }),
      N("Стоп при поле ниже, %", { "reactors", "fieldEmergency" }, 1, 30, 1, { int = true }),
      N("Предупреждать по топливу, %", { "reactors", "fuelWarn" }, 50, 99, 1, { int = true }),
      N("Стоп по топливу, % (0=выкл)", { "reactors", "fuelStop" }, 0, 99, 1, { int = true }),
      Sec("Разгон на холодном топливе"),
      N("Шаг разгона, RF/t", { "reactors", "coldBoostStep" }, 1000, 50000, 1000, { int = true, big = 5000, fmt = unumf, hint = "после первого запуска со свежим топливом" }),
      N("Длительность разгона, сек", { "reactors", "coldBoostTime" }, 30, 900, 30, { int = true }),
    }
  end },
  { id = "core", title = "Энергоядро", rows = function()
    return {
      Sec("Регулировка заряда"),
      B("Авто-регулировка", { "core", "auto" }),
      N("Цель заряда, RF", { "core", "target" }, 0, 1e15, 1e9, { big = 1e10, fmt = unumf }),
      N("Окно скорости ±, RF", { "core", "maxDiff" }, 1000, 5e6, 5000, { big = 25000, fmt = unumf, int = true }),
      N("Шаг потока, RF/t", { "core", "step" }, 100, 1e6, 1000, { big = 10000, fmt = unumf, int = true }),
      N("Мин. поток, RF/t", { "core", "flowMin" }, 0, 1e8, 1000, { big = 100000, fmt = unumf, int = true }),
      N("Макс. поток, RF/t", { "core", "flowMax" }, 1000, 2e9, 1e6, { big = 1e7, fmt = unumf, int = true }),
      B("Адаптивный шаг", { "core", "adaptive" }, "ускоряться, когда далеко от цели"),
      N("Опрос, сек", { "core", "interval" }, 0.2, 5, 0.1, { dec = 1, fmt = tf(1) }),
    }
  end },
  { id = "autocraft", title = "Автокрафт", rows = function()
    return {
      Sec("Планировщик"),
      B("Автокрафт включён", { "autocraft", "enabled" }, "то же, что кнопка АВТО", function(v) P.mods.autocraft.setActive(v) end),
      N("Одновременных крафтов", { "autocraft", "limit" }, 1, 32, 1, { int = true }),
      N("Резерв CPU (не занимать)", { "autocraft", "reserveCpus" }, 0, 16, 1, { int = true, hint = "оставить для ручных крафтов" }),
      N("Скан остатков, сек", { "autocraft", "scan" }, 2, 120, 1, { int = true }),
      E("Сортировка таблицы", { "autocraft", "sort" }, SORT_OPT),
      Sec("Значения для новых предметов"),
      N("Держать, шт", { "autocraft", "defaultKeep" }, 1, 1e7, 16, { big = 256, int = true, fmt = unumf }),
      N("Партия, шт", { "autocraft", "defaultBatch" }, 1, 1e6, 4, { big = 64, int = true, fmt = unumf }),
      N("Пауза после ошибки, с", { "autocraft", "cooldown" }, 3, 3600, 5, { big = 30, int = true }),
      N("Тайм-аут крафта, с", { "autocraft", "timeout" }, 30, 86400, 60, { big = 300, int = true }),
    }
  end },
  { id = "sing", title = "Сингулярки", rows = function()
    return {
      Sec("Сингулярки"),
      N("Скан остатков, сек", { "singularity", "scan" }, 5, 300, 5, { int = true }),
      E("Сортировка", { "singularity", "sort" }, SSORT_OPT),
      B("Сообщать в журнал", { "singularity", "alert" }, "когда можно крафтить"),
    }
  end },
  { id = "radar", title = "Радар", rows = radarRows },
  { id = "chat", title = "Чат", rows = function()
    return {
      Sec("Чат"),
      B("Команды !prisma", { "chat", "commands" }, "status / craft / reactors / sing"),
      N("Хранить строк", { "chat", "maxLines" }, 10, 300, 10, { int = true }),
    }
  end },
  { id = "devices", title = "Устройства", rows = deviceRows },
  { id = "system", title = "Система", rows = systemRows },
}

local function page()
  local id = P.state.setPage or "general"
  for _, p in ipairs(PAGES) do if p.id == id then return p end end
  return PAGES[1]
end

-- ───────── отрисовка строки ─────────
local LABEL_W = 36
local CTRL_W = 28

local function drawRow(r, x, y, w)
  if r.k == "sec" then
    UI.text(x, y, "▌ " .. r.label, C.acc, C.panel)
    UI.hline(x + U.ulen(r.label) + 3, y, w - U.ulen(r.label) - 3, C.line)
    return
  end
  local cw = LABEL_W + CTRL_W
  local hx = x + cw + 2
  local hint = r.hint and U.trunc(r.hint, w - cw - 3)
  if r.k == "bool" then
    local v = cfgGet(r.path)
    UI.toggle(x, y, cw, r.label, v, function()
      cfgSet(r.path, not v)
      if r.after then r.after(not v) end
    end)
  elseif r.k == "num" then
    local v = cfgGet(r.path)
    local function set(nv)
      nv = U.clamp(nv, r.min, r.max)
      if r.int then nv = math.floor(nv + 0.5) end
      if r.dec then nv = U.round(nv, r.dec) end
      cfgSet(r.path, nv)
      if r.after then r.after(nv) end
    end
    local disp = r.fmt and r.fmt(v) or tostring(v)
    UI.stepper(x, y, cw, r.label, disp,
      function() set(v - r.step) end,
      function() set(v + r.step) end,
      function()
        P.modal.input(r.label, { prompt = r.label .. " (" .. U.num(r.min) .. " … " .. U.num(r.max) .. ")", numeric = true, value = v, min = r.min, max = r.max, onOk = set })
      end, { vw = 12 })
  elseif r.k == "enum" then
    local v = cfgGet(r.path)
    local label = tostring(v)
    for _, o in ipairs(r.options) do if o[1] == v then label = o[2] end end
    local function step(d)
      local idx = 1
      for i, o in ipairs(r.options) do if o[1] == v then idx = i end end
      local nv = r.options[((idx - 1 + d) % #r.options) + 1][1]
      cfgSet(r.path, nv)
      if r.after then r.after(nv) end
    end
    UI.cycler(x, y, cw, r.label, label, function() step(-1) end, function() step(1) end, { vw = 12 })
  elseif r.k == "btn" then
    UI.button(x, y, 34, r.label, r.fn, { style = r.style or "normal" })
    hx = x + 36
  elseif r.k == "info" then
    UI.text(x, y, U.trunc(r.label, LABEL_W), C.dim, C.panel)
    UI.text(x + LABEL_W + 1, y, U.trunc(r.get(), w - LABEL_W - 2), r.color or C.text, C.panel)
    return
  elseif r.k == "ignore" then
    UI.text(x, y, "● " .. r.name, C.text, C.panel)
    UI.button(x + LABEL_W + 10, y, 5, "×", function() P.mods.radar.removeIgnore(r.idx) end, { style = "danger" })
    return
  elseif r.k == "device" then
    local role = r.role
    local pref = P.cfg.devices[role.key]
    UI.text(x, y, role.label, C.text, C.panel)
    local cur = (pref and pref ~= "") and (U.shortAddr(pref) .. "… вручную") or "авто"
    UI.text(x + LABEL_W - 2, y, U.pad(cur, 20), (pref and pref ~= "") and C.acc or C.dim, C.panel)
    UI.button(x + LABEL_W + 20, y, 14, "Выбрать…", function() pickDevice(role) end)
    UI.button(x + LABEL_W + 35, y, 8, "Авто", function()
      P.cfg.devices[role.key] = ""; P.config.markDirty(); reinit(); UI.toast(role.label .. ": авто", "info")
    end, { disabled = not (pref and pref ~= "") })
    return
  end
  if hint then UI.text(hx, y, hint, C.dim, C.panel) end
end

function S.draw(x, y, w, h)
  local navW = 20
  UI.panel(x, y, navW, h, "РАЗДЕЛЫ")
  local cur = page()
  for i, p in ipairs(PAGES) do
    UI.button(x + 2, y + 1 + (i - 1) * 2, navW - 4, p.title, function()
      P.state.setPage = p.id
      UI.scroll["set.list"] = nil
    end, { active = (p.id == cur.id), style = "ghost" })
  end
  local px, pw = x + navW + 1, w - navW - 1
  UI.panel(px, y, pw, h, string.upper(cur.title))
  local rows = cur.rows()
  local first, last, cw = UI.scrollArea("set.list", px + 1, y + 1, pw - 2, h - 2, #rows)
  for i = first, last do
    drawRow(rows[i], px + 3, y + 1 + (i - first), cw - 4)
  end
end

return S
