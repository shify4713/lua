-- PRISMA CORE Configuration
-- Автоматически сохраняется

local serialization = require("serialization")
local fs = require("filesystem")

local CONFIG_PATH = "/home/prisma/config.cfg"

local defaults = {
  -- GUI
  resolution = {w = 160, h = 50},  -- будет ограничено maxResolution
  theme = "cyber",

  -- Modules (тумблеры)
  modules = {
    reactors   = true,
    core       = true,
    precraft   = true,
    singularity = true,
    glasses    = true,
    radar      = true,
    chat       = true,
  },

  -- Reactors (max 5)
  reactors = {
    targetShield = 20,          -- %
    forceModeTemp = 7500,
    safeModeTemp = 8000,
    tempCrit = 8100,
    initialFlow = 535000,
    manualStep = 10000,
    detectOutMin = 530000,
    detectInMax = 500000,
    list = {},                  -- сохраняются адреса
  },

  -- Energy Core (только 1)
  core = {
    target = 200 * 10^9,        -- 200B RF
    maxDiff = 25000,
    step = 10000,
    flowMin = 1000,
    flowMax = 40000000,
  },

  -- Glasses AR
  glasses = {
    enabled = true,
    hudX = 2,
    hudY = 2,
    hudW = 280,
    showRadar = true,
    showChat = true,
    showCore = true,
    showReactors = true,
    ar_chat_width = 38,
  },

  -- Radar / Sensor
  radar = {
    ignore = {"LiwMorgan"},     -- кого не показывать
    prefixes = {
      -- ["PlayerName"] = "[Tag]",
    },
  },

  -- Chat
  chat = {
    maxLines = 12,
    showInGlasses = true,
  },

  -- Precraft
  precraft = {
    updateInterval = 5,
    dataFile = "/home/prisma/precraft_bd.txt",
  },

  -- Singularity
  singularity = {
    enabled = true,
  },
}

local M = {}

function M.load()
  if not fs.exists(CONFIG_PATH) then
    M.save(defaults)
    return defaults
  end
  local f = io.open(CONFIG_PATH, "r")
  if not f then return defaults end
  local data = f:read("*a")
  f:close()
  local ok, cfg = pcall(serialization.unserialize, data)
  if not ok or type(cfg) ~= "table" then
    return defaults
  end
  -- merge с defaults (на случай новых полей)
  for k, v in pairs(defaults) do
    if cfg[k] == nil then cfg[k] = v end
  end
  return cfg
end

function M.save(cfg)
  local f = io.open(CONFIG_PATH, "w")
  if f then
    f:write(serialization.serialize(cfg))
    f:close()
  end
end

return M
