-- PRISMA · СИНГУЛЯРКИ: прогресс накопления блоков + заказ «скрафтить N»
--   • заказ количества (+1 +3 +5 +10 / своё) — система сама докрафчивает недостающие
--     блоки через ME, а затем запрашивает саму сингулярность
local P = ...
local U, F, UI, V = P.util, P.fb, P.ui, P.vc
local C = UI.C

local S = { id = "sing", title = "СИНГУЛЯРКИ", scrollId = "sing.list" }

local SORTS = { "ready", "progress", "name" }
local SORT_TXT = { ready = "готовые", progress = "прогресс", name = "название" }
local STAGE_TXT = { queue = "в очереди", blocks = "крафтю блоки", singu = "крафтю сингулярку" }

local function st()
  local s = P.state.sing
  if not s then s = { onlyReady = false, sel = nil }; P.state.sing = s end
  return s
end

local function orderCustom(it)
  P.modal.input("Заказать сингулярки: " .. it.name, {
    prompt = "Сколько штук докрафтить", numeric = true, value = 1, min = 1, max = 999, int = true,
    onOk = function(v) if v and v > 0 then P.mods.singularity.order(it, math.floor(v)) end end,
  })
end

local function drawOrderPanel(x, y, w, h)
  local M = P.mods.singularity
  local s = st()
  local it = s.sel
  UI.panel(x, y, w, h, "ЗАКАЗ", { right = "клик по строке — выбрать предмет" })
  local ix, iw = x + 2, w - 4
  if not it then
    UI.textC(ix, y + math.floor(h / 2), iw, "Выберите сингулярку в списке слева", C.dim, C.panel)
    return
  end
  local info = M.info(it)
  local oi = M.orderInfo(it)
  UI.text(ix, y + 1, it.name, C.bright, C.panel)
  UI.kv(ix, y + 2, iw, "На складе блоков", info.known and U.num(info.have) or "…", C.text)
  UI.kv(ix, y + 3, iw, "Нужно на 1 шт", U.num(it.need), C.dim)
  UI.kv(ix, y + 4, iw, "Готовых сингулярностей", U.int(info.sing), info.sing > 0 and C.acc or C.dim)
  UI.bar(ix, y + 5, iw, info.frac, info.can > 0 and C.ok or C.accdim, { label = info.can > 0 and ("можно ×" .. info.can) or U.pct(info.frac) })

  local row = y + 7
  UI.text(ix, row, "Заказать ещё:", C.dim, C.panel)
  local bw = 8
  local bx = ix + 15
  for _, n in ipairs({ 1, 3, 5, 10 }) do
    UI.button(bx, row, bw, "+" .. n, function() M.order(it, n) end, { style = "primary" })
    bx = bx + bw + 1
  end
  UI.button(bx, row, 10, "Своё…", function() orderCustom(it) end)
  row = row + 2

  if oi then
    local qtyTxt = "в заказе: " .. oi.qty .. " шт"
    if oi.stage then
      local stxt = STAGE_TXT[oi.stage] or oi.stage
      UI.text(ix, row, qtyTxt .. " · " .. stxt, C.acc, C.panel)
      row = row + 1
      if oi.frac then
        UI.bar(ix, row, iw, oi.frac, oi.stage == "blocks" and C.warn or C.ok, { label = U.pct(oi.frac) })
        row = row + 1
        UI.kv(ix, row, iw, "Прошло / осталось", U.dur(oi.elapsed) .. " / " .. (oi.eta and U.dur(oi.eta) or "…"), C.text)
        row = row + 1
      end
    elseif oi.err then
      UI.text(ix, row, qtyTxt, C.text, C.panel); row = row + 1
      UI.text(ix, row, "Ошибка: " .. U.trunc(oi.err, iw - 10), C.bad, C.panel); row = row + 1
      if oi.retryAt then UI.text(ix, row, "повтор через " .. U.dur(math.max(0, oi.retryAt - U.now())), C.dim, C.panel); row = row + 1 end
    else
      UI.text(ix, row, qtyTxt .. " · ждёт", C.warn, C.panel); row = row + 1
    end
    UI.button(ix, row + 1, 20, "Отменить заказ", function() M.cancelOrder(it) end, { style = "danger" })
  else
    UI.text(ix, row, "заказов нет", C.dim, C.panel)
  end

  local by = y + h - 2
  UI.button(ix, by, 20, "Изменить рецепт…", function() P.actions.singForm(it) end)
end

function S.draw(x, y, w, h)
  local M = P.mods.singularity
  local cfg = P.cfg.singularity
  local sm = M.summary()
  local s = st()

  UI.panel(x, y, w, 4, "УПРАВЛЕНИЕ", { right = string.format("готово %.0f шт (%.0f видов) · на складе %s сингулярностей", sm.ready, sm.kinds, U.int(sm.singles)) })
  local ix, iw = x + 2, w - 4
  UI.button(ix, y + 1, 14, "Обновить", function() M.rescan(); UI.toast("Пересканирую…", "info") end)
  UI.button(ix + 15, y + 1, 18, "+ Добавить", function() P.actions.singForm(nil) end, { style = "primary" })
  UI.button(ix + 34, y + 1, 22, "Список по умолчанию", function()
    P.modal.confirm("Сбросить список", "Заменить весь список стандартным набором?\nВаши изменения пропадут.", function() M.resetDefaults() end, "Сбросить", true)
  end, { style = "warn" })
  UI.cycler(ix + iw - 62, y + 1, 32, "Сортировка", SORT_TXT[cfg.sort] or cfg.sort,
    function() cfg.sort = V.nextOf(SORTS, cfg.sort, -1); P.config.markDirty() end,
    function() cfg.sort = V.nextOf(SORTS, cfg.sort, 1); P.config.markDirty() end, { vw = 10 })
  UI.toggle(ix + iw - 28, y + 1, 28, "Только готовые", s.onlyReady, function() s.onlyReady = not s.onlyReady end)
  UI.toggle(ix, y + 2, 30, "Сообщать в журнал", cfg.alert, function() cfg.alert = not cfg.alert; P.config.markDirty() end)
  UI.stepper(ix + 34, y + 2, 32, "Скан, сек", cfg.scan,
    function() cfg.scan = math.max(5, cfg.scan - 5); P.config.markDirty() end,
    function() cfg.scan = math.min(300, cfg.scan + 5); P.config.markDirty() end, nil, { vw = 6 })

  local ty, th = y + 4, h - 4
  local cols = V.split(x, w, { 66, 34 })
  local lx, lw = cols[1].x, cols[1].w
  UI.panel(lx, ty, lw, th, "ПРОГРЕСС", { right = "клик по строке — выбрать" })
  local all = M.view(cfg.sort)
  local view = {}
  for _, e in ipairs(all) do if not s.onlyReady or e.info.can > 0 then view[#view + 1] = e end end
  local rows = th - 4
  local first, last, cw = UI.scrollArea("sing.list", lx + 1, ty + 3, lw - 2, rows, #view)
  local c = { idx = 3, need = 8, have = 10, bar = 20, can = 7, ord = 10 }
  local fixed = c.idx + c.need + c.have + c.bar + c.can + c.ord + 7
  c.name = math.max(12, cw - 2 - fixed)
  local xs, cx = {}, lx + 2
  for _, k in ipairs({ "idx", "name", "need", "have", "bar", "can", "ord" }) do xs[k] = cx; cx = cx + c[k] + 1 end
  local function head(k, t, right) UI.text(xs[k], ty + 1, U.pad(t, c[k], right), C.dim, C.panel) end
  head("idx", "#", true); head("name", "Сингулярка"); head("need", "Надо", true); head("have", "Блоков", true)
  head("bar", "Прогресс"); head("can", "Можно", true); head("ord", "Заказ", true)
  UI.hline(lx + 2, ty + 2, lw - 4, C.line)
  if #view == 0 then UI.textC(lx + 1, ty + 5, lw - 2, s.onlyReady and "Готовых пока нет" or "Список пуст", C.dim, C.panel) end
  for i = first, last do
    local e = view[i]
    local it, info = e.it, e.info
    local ry = ty + 3 + (i - first)
    local sel = (s.sel == it)
    local bg = sel and C.accbg or ((i % 2 == 0) and 0x171717 or C.panel)
    F.rect(lx + 1, ry, cw, 1, bg)
    local ready = info.can > 0
    UI.text(xs.idx, ry, U.pad(tostring(i), c.idx, true), C.dim, bg)
    UI.text(xs.name, ry, U.pad(it.name, c.name), sel and C.bright or (ready and C.ok or C.text), bg)
    UI.text(xs.need, ry, U.pad(U.num(it.need), c.need, true), C.dim, bg)
    UI.text(xs.have, ry, U.pad(info.known and U.num(info.have) or "…", c.have, true), C.text, bg)
    UI.bar(xs.bar, ry, c.bar, info.frac, ready and C.ok or C.accdim, { label = ready and ("×" .. info.can) or U.pct(info.frac) })
    UI.text(xs.can, ry, U.pad(ready and tostring(info.can) or "—", c.can, true), ready and C.ok or C.dim, bg)
    local oi = M.orderInfo(it)
    local ordTxt = oi and ((oi.err and "ошибка") or (oi.stage and (STAGE_TXT[oi.stage] or oi.stage)) or (oi.qty .. " шт")) or "—"
    UI.text(xs.ord, ry, U.pad(ordTxt, c.ord), oi and (oi.err and C.bad or C.acc) or C.dim, bg)
    UI.hitbox(lx + 1, ry, cw, 1, function() s.sel = it end)
  end

  drawOrderPanel(cols[2].x, ty, cols[2].w, th)
end

return S
