-- PRISMA CORE Singularity Module v3.3
-- Кэш количеств, обновление ME раз в 4 сек

local component = require("component")
local computer = require("computer")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local me
local cache = {}       -- ["id:dmg"] = qty
local lastScan = 0
local SCAN_INTERVAL = 4.0

local items = {
  {name="Железная",   block="minecraft:iron_ore", dmg=0, need=4500, singu="Avaritia:Singularity", sDmg=0},
  {name="Золотая",    block="minecraft:gold_ore", dmg=0, need=2700, singu="Avaritia:Singularity", sDmg=1},
  {name="Алмазная",   block="minecraft:diamond_block", dmg=0, need=600, singu="universalsingularities:universal.vanilla.singularity", sDmg=2},
  {name="Дракониевая",block="DraconicEvolution:draconium", dmg=0, need=600, singu="universalsingularities:universal.draconicEvolution.singularity", sDmg=0},
}

local function key(id, dmg) return tostring(id)..":"..tostring(dmg or 0) end

function M.init(config)
  me = utils.get("me_interface") or utils.get("ae2_interface") or utils.get("me_controller")
  lastScan = 0
  cache = {}
end

function M.getItems() return items end

function M.getQty(id, dmg)
  return cache[key(id, dmg)] or 0
end

-- Вызывать из фона раз в ~4 сек
function M.scan()
  if not me then return false end
  local now = computer.uptime()
  if now - lastScan < SCAN_INTERVAL then return false end
  lastScan = now

  local changed = false
  for _, it in ipairs(items) do
    -- блок
    local k1 = key(it.block, it.dmg)
    local qty1 = 0
    pcall(function()
      local d = me.getItemDetail({id=it.block, dmg=it.dmg})
      if d then
        local st = d.all and d.all() or d
        qty1 = st and (st.qty or st.size or 0) or 0
      end
    end)
    if cache[k1] ~= qty1 then cache[k1]=qty1; changed=true end

    -- сингулярка
    local k2 = key(it.singu, it.sDmg)
    local qty2 = 0
    pcall(function()
      local d = me.getItemDetail({id=it.singu, dmg=it.sDmg})
      if d then
        local st = d.all and d.all() or d
        qty2 = st and (st.qty or st.size or 0) or 0
      end
    end)
    if cache[k2] ~= qty2 then cache[k2]=qty2; changed=true end
  end
  return changed
end

return M
