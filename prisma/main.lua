-- ╔══════════════════════════════════════════════════════════╗
-- ║ PRISMA v4.5.1 — центр управления (OpenComputers 1.7.10)  ║
-- ║  реакторы · энергоядро · автокрафт AE2 · сингулярки · HUD ║
-- ╚══════════════════════════════════════════════════════════╝
local component = require("component")
local computer = require("computer")
local event = require("event")
local filesystem = require("filesystem")

local src = ((debug.getinfo(1, "S").source or ""):gsub("^[@=]", ""))
local BASE = src:match("^(.*)/[^/]*$") or "/home/prisma"
if BASE == "" then BASE = "/home/prisma" end

local VERSION = "4.5.1"
local TABS = {
  { id = "dash",  key = "dash" },
  { id = "power", key = "power" },
  { id = "craft", key = "craft" },
  { id = "sing",  key = "sing" },
  { id = "hud",   key = "hud" },
  { id = "log",   key = "log" },
  { id = "set",   key = "settings" },
}

-- ───────────────────────── запуск ─────────────────────────
local function boot()
  local P = { base = BASE, VERSION = VERSION, mods = {}, views = {}, tasks = {} }
  P.startedAt = computer.uptime()
  P.state = { tab = "dash", dirty = true, running = true, lastDraw = 0, drawMs = 0 }
  P.dataDir = os.getenv("PRISMA_DATA") or (BASE .. "/data")

  local function load(rel)
    local f, e = loadfile(BASE .. "/" .. rel)
    if not f then error("не удалось загрузить " .. rel .. ": " .. tostring(e), 0) end
    return f(P)
  end

  P.util = load("lib/util.lua")
  P.util.ensureDir(P.dataDir)
  P.log = load("lib/log.lua")
  P.config = load("config.lua")
  P.cfg = P.config.load()
  P.fb = load("lib/fb.lua")
  P.ui = load("lib/ui.lua")
  P.modal = load("lib/modal.lua")
  P.me = load("lib/me.lua")

  local M = P.mods
  M.reactor = load("lib/reactor.lua")
  M.core = load("lib/core.lua")
  M.autocraft = load("lib/autocraft.lua")
  M.singularity = load("lib/singularity.lua")
  M.radar = load("lib/radar.lua")
  M.chat = load("lib/chat.lua")
  M.glasses = load("lib/glasses.lua")

  P.vc = load("views/common.lua")
  P.actions = load("views/actions.lua")
  for _, t in ipairs(TABS) do P.views[t.id] = load("views/" .. t.key .. ".lua") end

  -- экран
  local okGpu, gpu = pcall(function() return component.gpu end)
  if not okGpu or not gpu then error("видеокарта не найдена", 0) end
  local screen = gpu.getScreen()
  if not screen then
    local s = component.list("screen")()
    if s then gpu.bind(s); screen = s end
  end
  P.screen = screen
  P.gpu = gpu
  pcall(function() gpu.setDepth(gpu.maxDepth()) end)

  local function setupScreen()
    local mw, mh = gpu.maxResolution()
    local W = math.max(50, math.min(P.cfg.ui.w, mw))
    local H = math.max(16, math.min(P.cfg.ui.h, mh))
    gpu.setResolution(W, H)
    gpu.setBackground(0x0F0F0F)
    gpu.setForeground(0xD2D2D2)
    gpu.fill(1, 1, W, H, " ")
    P.fb.init(gpu, W, H)
    P.state.dirty = true
  end
  P.applyResolution = setupScreen
  setupScreen()
  P.ui.setTheme(P.cfg.ui.theme)
  P.state.tab = P.cfg.ui.tab or "dash"
  if not P.views[P.state.tab] then P.state.tab = "dash" end

  -- модули (порядок важен: ядру нужно знать шлюзы реакторов)
  P.me.init()
  M.reactor.init()
  M.core.init()
  M.autocraft.init()
  M.singularity.init()
  M.radar.init()
  M.chat.init()
  M.glasses.init()

  function P.reinitDevices()
    P.me.init(); M.core.init(); M.radar.init(); M.chat.init(); M.glasses.init()
    P.state.dirty = true
  end

  function P.applyEcoMode()
    local c = P.cfg
    c.me.interval = math.max(c.me.interval, 0.5)
    c.core.interval = math.max(c.core.interval, 1)
    c.reactors.interval = math.max(c.reactors.interval, 1)
    c.autocraft.scan = math.max(c.autocraft.scan, 30)
    c.singularity.scan = math.max(c.singularity.scan, 60)
    c.radar.interval = math.max(c.radar.interval, 3)
    c.glasses.interval = math.max(c.glasses.interval, 1)
    c.ui.fps = math.min(c.ui.fps, 2)
    P.config.markDirty()
    P.ui.toast("Экономный режим применён — программа опрашивает устройства реже", "warn")
    P.log.info("PRISMA", "включён экономный режим (сниженная частота опросов)")
  end

  function P.saveAll()
    P.config.save(P.cfg)
    M.autocraft.flush()
    M.singularity.flush()
  end
  -- Короткий отчёт для поиска проблем без скриншотов и переписывания адресов.
  function P.saveDiagnostics()
    local free, total = P.util.freeMem()
    local lines = {
      "PRISMA " .. VERSION,
      "uptime=" .. P.util.dur(P.util.now() - P.startedAt),
      "memory_free=" .. string.format("%.0f/%.0f KB", free / 1024, total / 1024),
      "me=" .. tostring(P.me.available()) .. " online=" .. tostring(P.me.online) .. " error=" .. tostring(P.me.lastErr or "-"),
      "reactors=" .. M.reactor.count() .. " radar=" .. tostring(M.radar.available()) .. " glasses=" .. tostring(M.glasses.available()),
      "components:",
    }
    for addr, kind in component.list() do lines[#lines + 1] = "  " .. tostring(kind) .. " " .. tostring(addr) end
    lines[#lines + 1] = "tasks:"
    for _, t in ipairs(P.tasks or {}) do
      lines[#lines + 1] = string.format("  %s %.2fms errors=%d last=%s", t.name, (t.ms or 0) * 1000, t.errs or 0, t.lastErr or "-")
    end
    local out = P.dataDir .. "/diagnostics.txt"
    local f, err = io.open(out .. ".tmp", "w")
    if not f then return false, err end
    f:write(table.concat(lines, "\n"), "\n"); f:close()
    pcall(filesystem.remove, out)
    local ok, ren = pcall(filesystem.rename, out .. ".tmp", out)
    if not ok or not filesystem.exists(out) then return false, ren or "не удалось переименовать файл" end
    return true, out
  end
  function P.quit() P.state.running = false end
  function P.restart() P.state.running = false; P.state.restart = true end

  local w, h = P.fb.size()
  P.log.info("PRISMA", string.format("запуск v%s · экран %.0f×%.0f", VERSION, w, h))
  if not P.me.available() then P.log.warn("ME", "ME-интерфейс не найден") end
  if not M.core.hasStorage() then P.log.warn("ЯДРО", "накопитель энергии не найден") end
  if M.core.hasStorage() and M.core.info().gateState == "ambiguous" then
    P.log.warn("ЯДРО", "несколько свободных шлюзов — выберите шлюз ядра (вкладка ЭНЕРГИЯ)")
  end
  return P
end

-- ───────────────────────── планировщик ─────────────────────────
local function makeTasks(P)
  local M, cfg = P.mods, P.cfg
  local always = function() return true end
  local list = {
    { name = "реакторы",   every = 0.1,  on = function() return cfg.modules.reactors end,     fn = function(n) M.reactor.update(n) end },
    { name = "ядро",       every = function() return cfg.core.interval end, on = function() return cfg.modules.core end, fn = function(n) M.core.update(n) end },
    { name = "ME-очередь", every = function() return cfg.me.interval end, on = always,        fn = function() P.me.pump(cfg.me.batch) end },
    { name = "автокрафт",  every = 0.5,  on = function() return cfg.modules.autocraft end,    fn = function(n) M.autocraft.update(n) end },
    { name = "сингулярки", every = 1,    on = function() return cfg.modules.singularity end,  fn = function(n) M.singularity.update(n) end },
    { name = "радар",      every = 0.5,  on = function() return cfg.modules.radar end,        fn = function(n) M.radar.update(n) end },
    { name = "очки",       every = 0.25, on = function() return cfg.modules.glasses end,      fn = function(n) M.glasses.update(n) end },
    { name = "интерфейс",  every = 0.1,  on = always,                                        fn = function(n) if P.ui.tick(n) then P.state.dirty = true end end },
    { name = "сохранение", every = 5,    on = always,                                        fn = function() P.config.flush() end },
  }
  for _, t in ipairs(list) do t.next, t.pause, t.ms, t.errs, t.streak = 0, 0, 0, 0, 0 end
  return list
end

local function runTasks(P, now)
  local due = now + 1
  for _, t in ipairs(P.tasks) do
    if now >= t.next and now >= t.pause then
      local every = type(t.every) == "function" and t.every() or t.every
      t.next = now + (every or 0.5)
      if t.on() then
        local c0 = os.clock()
        local ok, err = pcall(t.fn, now)
        t.ms = t.ms * 0.9 + (os.clock() - c0) * 0.1
        if ok then
          t.streak = 0
        else
          t.errs = t.errs + 1
          t.streak = t.streak + 1
          if t.lastErr ~= tostring(err) then
            t.lastErr = tostring(err)
            P.log.warn("СБОЙ", t.name .. ": " .. P.util.trunc(tostring(err):gsub("\n.*", ""), 70))
          end
          if t.streak >= 5 then
            t.pause = now + 30
            t.streak = 0
            P.log.crit("СБОЙ", "задача «" .. t.name .. "» отключена на 30 с")
          end
        end
      end
    end
    local nx = math.max(t.next, t.pause)
    if nx < due then due = nx end
  end
  return due
end

-- ───────────────────────── отрисовка ─────────────────────────
local LED = {
  { m = "reactors",    label = "РЕАКТ" },
  { m = "core",        label = "ЯДРО" },
  { m = "autocraft",   label = "КРАФТ" },
  { m = "singularity", label = "СИНГ" },
  { m = "glasses",     label = "ОЧКИ" },
  { m = "radar",       label = "РАДАР" },
  { m = "chat",        label = "ЧАТ" },
}

local function ledColor(P, m)
  local C = P.ui.C
  local M = P.mods
  if not P.cfg.modules[m] then return C.dim end
  if m == "reactors" then
    if M.reactor.count() == 0 then return C.warn end
    for _, r in ipairs(M.reactor.list()) do if not r.online then return C.bad end end
    return C.ok
  elseif m == "core" then
    if not M.core.hasStorage() then return C.warn end
    return M.core.info().online and C.ok or C.bad
  elseif m == "autocraft" then
    if not P.me.available() or P.me.online == false then return C.bad end
    return M.autocraft.isActive() and C.ok or C.warn
  elseif m == "singularity" then
    if not P.me.available() or P.me.online == false then return C.bad end
    return M.singularity.summary().ready > 0 and C.acc or C.ok
  elseif m == "glasses" then
    return M.glasses.available() and C.ok or C.warn
  elseif m == "radar" then
    if not M.radar.available() then return C.warn end
    return #M.radar.list() > 0 and C.bad or C.ok
  elseif m == "chat" then
    return M.chat.available() and C.ok or C.warn
  end
  return C.text
end

local function toggleModule(P, m, label)
  local function apply()
    P.cfg.modules[m] = not P.cfg.modules[m]
    P.config.markDirty()
    if m == "glasses" and not P.cfg.modules[m] then P.mods.glasses.clear() end
    P.ui.toast(label .. (P.cfg.modules[m] and ": включён" or ": выключен"), P.cfg.modules[m] and "ok" or "warn")
  end
  if m == "reactors" and P.cfg.modules[m] then
    P.modal.confirm("Отключить реакторы", "Автоматика реакторов будет остановлена!\nШлюзы останутся в последнем состоянии.", apply, "Отключить", true)
  else
    apply()
  end
end

local function drawHeader(P, W)
  local F, UI, U = P.fb, P.ui, P.util
  local C = UI.C
  F.rect(1, 1, W, 1, C.panel)
  F.text(2, 1, "◆ PRISMA", C.acc, C.panel)
  F.text(11, 1, "v" .. VERSION, C.dim, C.panel)
  local x = 18
  for _, l in ipairs(LED) do
    local col = ledColor(P, l.m)
    F.text(x, 1, "●", col, C.panel)
    F.text(x + 2, 1, l.label, P.cfg.modules[l.m] and C.text or C.dim, C.panel)
    UI.hitbox(x, 1, U.ulen(l.label) + 3, 1, function() toggleModule(P, l.m, l.label) end)
    x = x + U.ulen(l.label) + 4
  end
  local free, total = U.freeMem()
  local right = string.format("%s · работает %s · ОЗУ %.0f%%", U.clock(), U.dur(U.now() - P.startedAt), (1 - free / total) * 100)
  if W - 1 - U.ulen(right) < x then right = U.clock() end
  if W - 1 - U.ulen(right) >= x then UI.textR(1, 1, W - 1, right, C.dim, C.panel) end
end

local function drawStatus(P, W, H)
  local F, UI, U = P.fb, P.ui, P.util
  local C = UI.C
  F.rect(1, H, W, 1, C.panel)
  local e = P.log.last()
  if e then
    local col = e.lvl == "crit" and C.bad or (e.lvl == "warn" and C.warn or C.dim)
    F.text(2, H, e.clock .. "  " .. U.trunc(e.src .. ": " .. e.msg, W - 50), col, C.panel)
  end
  local tail = string.format("кадр %.0f мс · ME в очереди %.0f · [1-7] вкладки", P.state.drawMs or 0, P.me.queueSize())
  UI.textR(1, H, W - 1, tail, C.dim, C.panel)
end

local function tabList(P)
  local A = P.mods.autocraft
  local list = {}
  local names = { dash = "ДАШБОРД", power = "ЭНЕРГИЯ", craft = "АВТОКРАФТ", sing = "СИНГУЛЯРКИ", hud = "ОЧКИ", log = "ЖУРНАЛ", set = "НАСТРОЙКИ" }
  local logBadge = 0
  local all = P.log.all()
  local seen = P.state.logSeen or 0
  for i = #all, math.max(1, #all - 60), -1 do
    if all[i].n > seen and all[i].lvl ~= "info" then logBadge = logBadge + 1 end
  end
  for i, t in ipairs(TABS) do
    local e = { id = t.id, label = i .. " " .. names[t.id] }
    if t.id == "craft" then
      e.badge = #A.problems(); e.badgeColor = P.ui.C.bad
    elseif t.id == "log" and P.state.tab ~= "log" then
      e.badge = logBadge; e.badgeColor = P.ui.C.warn
    end
    list[#list + 1] = e
  end
  return list
end

local function switchTab(P, id)
  if not P.views[id] then return end
  P.state.tab = id
  P.cfg.ui.tab = id
  P.config.markDirty()
  if id == "log" then P.state.logSeen = P.log.seq end
  P.state.dirty = true
end

local lastDrawErr
local function draw(P)
  local now = P.util.now()
  local c0 = os.clock()
  local F, UI, modal = P.fb, P.ui, P.modal
  local W, H = F.size()
  F.resetClip()
  UI.begin()
  F.clear(UI.C.bg)
  drawHeader(P, W)
  UI.tabs(2, tabList(P), P.state.tab, function(id) switchTab(P, id) end, W)
  if P.state.tab == "log" then P.state.logSeen = P.log.seq end
  local view = P.views[P.state.tab]
  local ok, err = pcall(view.draw, 1, 3, W, H - 3)
  if not ok then
    F.resetClip()
    UI.text(3, 5, "Ошибка отрисовки вкладки: " .. tostring(err):gsub("\n.*", ""), UI.C.bad)
    if lastDrawErr ~= tostring(err) then
      lastDrawErr = tostring(err)
      P.log.warn("ИНТЕРФЕЙС", P.util.trunc(tostring(err):gsub("\n.*", ""), 80))
    end
  end
  F.resetClip()
  drawStatus(P, W, H)
  local ok2, err2 = pcall(modal.draw)
  if not ok2 then modal.closeAll(); P.log.warn("ИНТЕРФЕЙС", "окно: " .. tostring(err2):gsub("\n.*", "")) end
  F.resetClip()
  UI.drawToasts(W, H)
  F.flush()
  P.state.drawMs = (os.clock() - c0) * 1000
  P.state.lastDraw = now
  P.state.dirty = false
end

-- ───────────────────────── события ─────────────────────────
local function handleEvent(P, ev)
  local name = ev[1]
  local UI, modal = P.ui, P.modal
  if name == "touch" then
    if P.screen and ev[2] ~= P.screen then return end
    UI.click(math.floor(ev[3]), math.floor(ev[4]), ev[5])
    P.state.dirty = true
  elseif name == "scroll" then
    if P.screen and ev[2] ~= P.screen then return end
    UI.wheel(math.floor(ev[3]), math.floor(ev[4]), ev[5])
    P.state.dirty = true
  elseif name == "key_down" then
    local char, code = ev[3], ev[4]
    if modal.key(char, code) then return end
    local view = P.views[P.state.tab]
    if view.key and view.key(char, code) then P.state.dirty = true; return end
    if view.scrollId and (code == 200 or code == 208 or code == 201 or code == 209) then
      local d = (code == 200 and -1) or (code == 208 and 1) or (code == 201 and -10) or 10
      UI.scrollBy(view.scrollId, d)
      return
    end
    if char and char >= 49 and char <= 48 + #TABS then
      switchTab(P, TABS[char - 48].id)
    end
  elseif name == "clipboard" then
    modal.paste(tostring(ev[3] or ""))
  elseif name == "chat_message" or name == "chat" then
    if P.cfg.modules.chat then
      -- Обычно: event, address, player, message; некоторые chat_box
      -- посылают event, player, message без адреса.
      local player, message = ev[3], ev[4]
      if message == nil then player, message = ev[2], ev[3] end
      P.mods.chat.onMessage(player, message)
    end
  elseif name == "component_added" or name == "component_removed" then
    P.state.devicesAt = P.util.now() + 1.5
  end
end

-- ───────────────────────── главный цикл ─────────────────────────
local function loop(P)
  local U = P.util
  P.tasks = makeTasks(P)
  local state = P.state
  while state.running do
    local now = U.now()
    local due = runTasks(P, now)
    if state.devicesAt and now >= state.devicesAt then
      state.devicesAt = nil
      P.reinitDevices()
    end
    local fps = math.max(1, P.cfg.ui.fps or 3)
    if state.dirty or now - state.lastDraw >= 1 / fps then
      local ok, err = pcall(draw, P)
      if not ok then
        P.log.warn("ИНТЕРФЕЙС", "кадр: " .. U.trunc(tostring(err):gsub("\n.*", ""), 80))
        state.dirty = false
        state.lastDraw = now
      end
    end
    local wait = math.min(math.max(due - U.now(), 0.02), 0.2)
    if state.dirty then wait = 0.01 end
    local ev = table.pack(event.pull(wait))
    if ev[1] then
      local ok, err = pcall(handleEvent, P, ev)
      if not ok then P.log.warn("ИНТЕРФЕЙС", "событие: " .. U.trunc(tostring(err):gsub("\n.*", ""), 80)) end
      -- быстро разбираем всё, что накопилось (например, серия прокруток)
      local extra = 0
      while extra < 8 do
        local e2 = table.pack(event.pull(0))
        if not e2[1] then break end
        pcall(handleEvent, P, e2)
        extra = extra + 1
      end
    end
  end
end

local function cleanup(P)
  pcall(function() P.saveAll() end)
  pcall(function() P.mods.glasses.clear() end)
  pcall(function()
    local gpu = P.gpu
    local w, h = gpu.getResolution()
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, 1, w, h, " ")
    require("term").clear()
  end)
end

local function main()
  local P = boot()
  local ok, err = xpcall(loop, debug.traceback, P)
  cleanup(P)
  if not ok then error(err, 0) end
  return P.state.restart and "restart" or "exit"
end

-- ───────────────────────── защита от падений ─────────────────────────
local function crashLog(msg)
  pcall(function()
    local f = io.open(BASE .. "/crash.log", "a")
    if f then
      f:write("[" .. tostring(os.date and os.date("%Y-%m-%.0f %H:%M:%S") or "?") .. "] " .. tostring(msg) .. "\n\n")
      f:close()
    end
  end)
end

local restarts = 0
local running = true
while running do
  local ok, res = xpcall(main, debug.traceback)
  if ok then
    if res ~= "restart" then running = false end
  else
    if tostring(res):find("interrupted", 1, true) then
      running = false
    else
      crashLog(res)
      print("PRISMA: сбой — " .. tostring(res):gsub("\n.*", ""))
      restarts = restarts + 1
      if restarts > 5 then
        print("PRISMA: слишком много сбоев подряд, подробности в " .. BASE .. "/crash.log")
        running = false
      else
        print("PRISMA: перезапуск через 3 сек (Ctrl+Alt+C — отмена)")
        local ok2 = pcall(function() event.pull(3) end)
        if not ok2 then running = false end
      end
    end
  end
end
