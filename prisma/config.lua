-- PRISMA · config: настройки (глубокое слияние с дефолтами, атомарная запись)
local P = ...
local U = P.util

local C = {}

C.defaults = {
  version = 4,

  ui = {
    theme = "cyan",       -- cyan | green | amber | violet
    w = 160, h = 50,      -- желаемое разрешение (ограничивается видеокартой)
    fps = 3,              -- автообновление экрана (кадров/сек)
    sound = true,         -- сигналы тревоги
    autoRestart = true,   -- перезапуск после сбоя
    tab = "dash",
  },

  modules = {
    reactors = true, core = true, autocraft = true, singularity = true,
    glasses = true, radar = true, chat = true,
  },

  -- ручная привязка устройств (адрес или его начало). Пусто = авто
  devices = { me = "", storage = "", coreGate = "", sensor = "", glasses = "", chat = "" },

  reactors = {
    targetShield = 20,      -- % поля, которое держим
    forceModeTemp = 7500,
    safeModeTemp = 8000,
    tempCrit = 8100,
    initialFlow = 535000,
    manualStep = 10000,
    detectOutMin = 530000,
    detectInMax = 500000,
    interval = 0.5,         -- как часто опрашивать один реактор (сек)
    emergency = true,       -- аварийная остановка
    tempEmergency = 8800,   -- °C
    fieldEmergency = 5,     -- % поля
    fuelWarn = 90,          -- % топлива: предупреждение
    fuelStop = 0,           -- % топлива: авто-стоп (0 = выкл)
    coldBoostStep = 6000,   -- увеличенный шаг разгона на холодном топливе, RF/t
    coldBoostTime = 180,    -- сколько секунд после первого запуска держим ускоренный разгон
  },

  core = {
    auto = true,
    target = 200 * 10 ^ 9,
    maxDiff = 25000,
    step = 10000,
    flowMin = 1000,
    flowMax = 40000000,
    adaptive = true,        -- ускоряться, когда далеко от цели
    interval = 0.4,
  },

  autocraft = {
    enabled = false,
    limit = 6,              -- сколько крафтов одновременно
    scan = 10,              -- как часто обновлять остатки предметов (сек)
    reserveCpus = 0,        -- сколько CPU не занимать (для ручных крафтов)
    defaultKeep = 64,
    defaultBatch = 16,
    cooldown = 30,          -- пауза после ошибки (сек)
    timeout = 900,          -- отменять крафт, если завис (сек)
    sort = "prio",          -- prio | name | state | need
  },

  singularity = {
    scan = 20,              -- обновление остатков (сек)
    sort = "ready",         -- ready | name | progress
    alert = true,           -- писать в журнал, когда можно крафтить
    orderCooldown = 20,      -- пауза после ошибки заказа (сек)
    orderTimeout = 1200,     -- отменять зависший заказ (сек)
  },

  glasses = {
    enabled = true,
    anchor = "TL",          -- TL | TR | BL | BR
    x = 4, y = 4,
    w = 150,                -- ширина панели (в пикселях GUI)
    scale = 0.6,            -- масштаб текста
    alpha = 0.55,           -- прозрачность фона
    screenW = 480, screenH = 270,   -- размер GUI-экрана (нужен для якорей справа/снизу)
    interval = 0.5,
    preset = "normal",
    show = { core = true, reactors = true, craft = true, sing = false, near = true, chat = true },
    maxCraft = 3,
    chatLines = 4,
    chatWidth = 34,
    chatBelow = true,       -- чат под основной панелью
  },

  radar = { ignore = { "LiwMorgan" }, prefixes = {}, alert = true, interval = 1 },

  chat = { maxLines = 60, commands = true },

  me = {
    interval = 0.05,        -- как часто «прокачивать» очередь запросов к ME (сек) — главный регулятор нагрузки на сервер
    batch = 2,               -- сколько запросов из очереди обрабатывать за один проход
    networkLimit = 1500,     -- максимум предметов, которые загружаем при просмотре сети ME (безопасность по памяти)
  },

  clock = {
    mode = "real",           -- real (время сервера) | game (время игрового дня) | uptime (с запуска программы)
    tz = 0,                  -- часовой пояс, часы от UTC
  },
}

local function path() return P.dataDir .. "/config.cfg" end

local function migrate(cfg)
  -- совместимость со старыми версиями PRISMA (до v4)
  if type(cfg.modules) == "table" then
    if cfg.modules.precraft ~= nil and cfg.modules.autocraft == nil then
      cfg.autocraft = cfg.autocraft or {}
      cfg.autocraft.enabled = cfg.modules.precraft and true or false   -- раньше это был «АВТО»
      cfg.modules.autocraft = true
      cfg.modules.precraft = nil
    end
  end
  if type(cfg.glasses) == "table" then
    local g = cfg.glasses
    if g.hudX and g.x == nil then g.x = g.hudX end
    if g.hudY and g.y == nil then g.y = g.hudY end
    g.hudX, g.hudY, g.hudW, g.ar_chat_width = nil, nil, nil, nil
    if g.showReactors ~= nil then
      g.show = g.show or {}
      g.show.reactors = g.showReactors; g.show.core = g.showCore
      g.show.near = g.showRadar; g.show.chat = g.showChat
      g.showReactors, g.showCore, g.showRadar, g.showChat = nil, nil, nil, nil
    end
  end
  cfg.precraft = nil
  return cfg
end

function C.load()
  local t = U.readTable(path()) or U.readTable(P.base .. "/config.cfg")
  local cfg
  if type(t) == "table" then
    cfg = U.fill(migrate(t), C.defaults)
  else
    cfg = U.copy(C.defaults)
  end
  cfg.version = C.defaults.version
  return cfg
end

local pending = false
function C.markDirty() pending = true end

function C.save(cfg)
  pending = false
  return U.writeTable(path(), cfg or P.cfg)
end

function C.flush()
  if pending then C.save(P.cfg) end
end

function C.reset()
  local fresh = U.copy(C.defaults)
  for k in pairs(P.cfg) do P.cfg[k] = nil end
  for k, v in pairs(fresh) do P.cfg[k] = v end
  C.save(P.cfg)
end

return C
