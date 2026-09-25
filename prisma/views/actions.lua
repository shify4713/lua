-- PRISMA · сценарии с окнами: добавление реакторов, предметов автокрафта, редактирование
local P = ...
local U, UI = P.util, P.ui

local X = {}

local function modal() return P.modal end

-- ───────── реакторы ─────────
function X.addReactor()
  local R = P.mods.reactor
  if R.count() >= R.max() then UI.toast("Максимум " .. R.max() .. " реакторов", "warn"); return end
  modal().menu("Добавить реактор", {
    { label = "Авто: свободный реактор + 2 шлюза", style = "primary", fn = function()
      local ok, err = R.addAuto()
      UI.toast(ok and "Реактор добавлен" or err, ok and "ok" or "bad")
    end },
    { label = "Вручную: выбрать реактор и шлюзы", fn = X.addReactorManual },
  }, 50)
end

function X.addReactorManual()
  local R = P.mods.reactor
  local reactors, gates = R.free()
  if #reactors == 0 then UI.toast("Свободных реакторов нет", "warn"); return end
  if #gates < 2 then UI.toast("Нужно минимум 2 свободных flux_gate", "warn"); return end
  local ritems = {}
  for _, a in ipairs(reactors) do ritems[#ritems + 1] = { addr = a } end
  local function gateLabel(g) return U.shortAddr(g.addr) .. "…  поток " .. U.num(g.flow or 0) end
  modal().pick({
    title = "1/3 · Реактор", items = ritems, w = 56, h = 14,
    label = function(it) return "draconic_reactor " .. U.shortAddr(it.addr) .. "…" end,
    onPick = function(r)
      modal().pick({
        title = "2/3 · ВХОДНОЙ шлюз (в реактор, щит)", items = gates, w = 56, h = 16, label = gateLabel,
        onPick = function(gin)
          local rest = {}
          for _, g in ipairs(gates) do if g.addr ~= gin.addr then rest[#rest + 1] = g end end
          modal().pick({
            title = "3/3 · ВЫХОДНОЙ шлюз (из реактора)", items = rest, w = 56, h = 16, label = gateLabel,
            onPick = function(gout)
              local ok, err = R.addManual(r.addr, gin.addr, gout.addr)
              UI.toast(ok and "Реактор добавлен" or err, ok and "ok" or "bad")
            end,
          })
        end,
      })
    end,
  })
end

-- ───────── автокрафт ─────────
local function craftFields()
  local c = P.cfg.autocraft
  return {
    { key = "label",    label = "Название",         kind = "text" },
    { key = "keep",     label = "Держать, шт",      kind = "num", min = 1, int = true, step = 8, big = 64 },
    { key = "batch",    label = "Партия за заказ",  kind = "num", min = 1, int = true, step = 4, big = 32 },
    { key = "trigger",  label = "Начать при, % цели", kind = "num", min = 1, max = 100, int = true, step = 5, big = 25 },
    { key = "prio",     label = "Приоритет (1–9)",  kind = "num", min = 1, max = 9, int = true, step = 1 },
    { key = "cooldown", label = "Пауза после ошибки, с", kind = "num", min = 3, max = 3600, int = true, step = 5, big = 30 },
    { key = "timeout",  label = "Тайм-аут крафта, с", kind = "num", min = 30, max = 86400, int = true, step = 60, big = 300 },
    { key = "enabled",  label = "Включён",          kind = "bool" },
    { key = "once",     label = "Разовый (сделать N и стоп)", kind = "bool" },
    { key = "note",     label = "Заметка",          kind = "text" },
  }
end

function X.craftEdit(it)
  local c = P.cfg.autocraft
  modal().form({
    title = "Предмет: " .. U.trunc(it.label, 36),
    fields = craftFields(), w = 70,
    note = it.name .. ":" .. it.damage,
    values = {
      label = it.label, keep = it.keep, batch = it.batch, trigger = it.trigger, prio = it.prio,
      cooldown = it.cooldown or c.cooldown, timeout = it.timeout or c.timeout,
      enabled = it.enabled, once = it.once or false, note = it.note or "",
    },
    onOk = function(v)
      P.mods.autocraft.apply(it, v)
      UI.toast("Сохранено: " .. it.label, "ok")
    end,
    extra = {
      { label = "Удалить", style = "danger", fn = function()
        modal().confirm("Удалить предмет", "Убрать «" .. it.label .. "» из автокрафта?", function()
          P.mods.autocraft.remove(it)
          P.state.sel = nil
        end, "Удалить", true)
      end },
    },
  })
end

local function craftNew(spec)
  local c = P.cfg.autocraft
  modal().form({
    title = "Новый предмет автокрафта", fields = craftFields(), w = 70,
    note = spec.name .. ":" .. (spec.damage or 0),
    values = {
      label = spec.label or spec.name, keep = c.defaultKeep, batch = c.defaultBatch, trigger = 100, prio = 5,
      cooldown = c.cooldown, timeout = c.timeout, enabled = true, once = false, note = "",
    },
    okLabel = "Добавить",
    onOk = function(v)
      local it, err = P.mods.autocraft.add({ name = spec.name, damage = spec.damage, label = v.label, keep = v.keep, batch = v.batch })
      if not it then UI.toast(err, "bad"); return end
      P.mods.autocraft.apply(it, v)
      P.state.sel = it
      UI.toast("Добавлено: " .. it.label, "ok")
    end,
  })
end

function X.craftFromNetwork()
  local me = P.me
  if not me.available() then UI.toast("ME-интерфейс не найден", "bad"); return end
  modal().confirm(
    "Просмотр сети ME",
    "На больших ME-сетях (десятки тысяч предметов) список может не поместиться\nв память компьютера, и программа перезапустится.\nПоказаны будут первые " .. (P.cfg.me.networkLimit or 1500) .. " предметов (лимит меняется в Настройках).\n\nЕсли не хватает памяти — используйте «Вручную (ID + damage)».",
    function() X.craftFromNetworkGo() end, "Продолжить"
  )
end

function X.craftFromNetworkGo()
  local me = P.me
  local all, err = me.listNetwork()
  if not all then UI.toast("ME: " .. tostring(err), "bad"); return end
  local craftOnly = false
  modal().pick({
    title = "Предмет из сети ME", w = 90, h = 36,
    items = function()
      if not craftOnly then return all end
      local r = {}
      for _, it in ipairs(all) do if it.craft then r[#r + 1] = it end end
      return r
    end,
    label = function(it) return (it.craft and "★ " or "  ") .. it.label end,
    sub = function(it) return U.int(it.size) .. " шт · " .. it.name .. ":" .. it.damage end,
    empty = "Ничего не найдено (в сети хранятся только предметы, которые уже есть)",
    onPick = craftNew,
    extra = {
      { label = "Только с рецептом", refresh = true, fn = function() craftOnly = not craftOnly end },
      { label = "Обновить список", refresh = true, fn = function() all = me.listNetwork() or all end },
    },
  })
end

function X.craftManual()
  modal().form({
    title = "Предмет вручную", w = 66, okLabel = "Далее",
    fields = {
      { key = "name", label = "ID (mod:item)", kind = "text" },
      { key = "damage", label = "Damage (мета)", kind = "num", int = true, min = 0, step = 1 },
      { key = "label", label = "Название", kind = "text" },
    },
    values = { name = "", damage = 0, label = "" },
    validate = function(v) if U.trim(v.name) == "" then return "Укажите ID предмета" end end,
    onOk = function(v) craftNew({ name = U.trim(v.name), damage = v.damage, label = v.label ~= "" and v.label or U.trim(v.name) }) end,
  })
end

function X.craftFromSlot()
  local it, err = P.mods.autocraft.importSlot()
  if it then
    P.state.sel = it
    UI.toast("Импортировано: " .. it.label, "ok")
  else
    UI.toast(err or "не удалось", "warn")
  end
end

function X.craftAdd()
  modal().menu("Добавить предмет в автокрафт", {
    { label = "Из сети ME (поиск по названию)", style = "primary", fn = X.craftFromNetwork },
    { label = "Вручную (ID + damage)", fn = X.craftManual },
    { label = "Из конфиг-слота ME-интерфейса", fn = X.craftFromSlot },
  }, 50)
end

-- ───────── сингулярки ─────────
function X.singForm(it)
  local S = P.mods.singularity
  local isNew = (it == nil)
  local v = isNew and { name = "", block = "", dmg = 0, need = 1000, singu = "Avaritia:Singularity", sDmg = 0 }
    or { name = it.name, block = it.block, dmg = it.dmg, need = it.need, singu = it.singu, sDmg = it.sDmg }
  modal().form({
    title = isNew and "Новая сингулярка" or ("Сингулярка: " .. it.name), w = 70,
    okLabel = isNew and "Добавить" or "Сохранить",
    fields = {
      { key = "name", label = "Название", kind = "text" },
      { key = "block", label = "Блок (ID)", kind = "text" },
      { key = "dmg", label = "Блок damage", kind = "num", int = true, min = 0, step = 1 },
      { key = "need", label = "Блоков на 1 шт", kind = "num", int = true, min = 1, step = 100, big = 1000 },
      { key = "singu", label = "Сингулярность (ID)", kind = "text" },
      { key = "sDmg", label = "Сингул. damage", kind = "num", int = true, min = 0, step = 1 },
    },
    values = v,
    validate = function(x) if U.trim(x.name) == "" or U.trim(x.block) == "" then return "Название и ID блока обязательны" end end,
    onOk = function(x)
      if isNew then S.add(x) else S.apply(it, x) end
      UI.toast("Сохранено", "ok")
    end,
    extra = (not isNew) and { { label = "Удалить", style = "danger", fn = function() S.remove(it) end } } or nil,
  })
end

return X
