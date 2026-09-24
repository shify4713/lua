-- PRISMA CORE Singularity — полный список из Sing,lua (25 шт)
local component = require("component")
local computer = require("computer")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local me, cache, lastScan = nil, {}, 0
local SCAN_INTERVAL = 4.0

local items = {
  {name="Железная",       block="minecraft:iron_ore", dmg=0, need=4500, singu="Avaritia:Singularity", sDmg=0},
  {name="Золотая",        block="minecraft:gold_ore", dmg=0, need=2700, singu="Avaritia:Singularity", sDmg=1},
  {name="Лазуритовая",    block="minecraft:lapis_ore", dmg=0, need=600,  singu="Avaritia:Singularity", sDmg=2},
  {name="Редстоун",       block="minecraft:redstone_ore", dmg=0, need=720,  singu="Avaritia:Singularity", sDmg=3},
  {name="Кварцевая",      block="minecraft:quartz_ore", dmg=0, need=2200, singu="Avaritia:Singularity", sDmg=4},
  {name="Медная",         block="IC2:copperOre", dmg=0, need=4500, singu="Avaritia:Singularity", sDmg=5},
  {name="Оловянная",      block="IC2:tinOre", dmg=0, need=10000,singu="Avaritia:Singularity", sDmg=6},
  {name="Бронзовая",      block="IC2:blockMetal", dmg=2, need=600,  singu="universalsingularities:universal.general.singularity", sDmg=2},
  {name="Свинцовая",      block="ThermalFoundation:Ore", dmg=3, need=9000, singu="Avaritia:Singularity", sDmg=7},
  {name="Серебряная",     block="ThermalFoundation:Ore", dmg=2, need=2700, singu="Avaritia:Singularity", sDmg=8},
  {name="Глиняная",       block="minecraft:clay", dmg=0, need=666,  singu="Avaritia:Singularity", sDmg=10},
  {name="Угольная",       block="minecraft:coal_block", dmg=0, need=600,  singu="universalsingularities:universal.vanilla.singularity", sDmg=0},
  {name="Алмазная",       block="minecraft:diamond_block", dmg=0, need=600,  singu="universalsingularities:universal.vanilla.singularity", sDmg=2},
  {name="Эндериумовая",   block="ThermalFoundation:Storage", dmg=12,need=111,  singu="thermsingul:Thermal Singularity", sDmg=4},
  {name="Инвариумовая",   block="ThermalFoundation:Storage", dmg=8, need=111,  singu="universalsingularities:universal.general.singularity", sDmg=5},
  {name="Наэлектросталь", block="EnderIO:blockIngotStorage", dmg=0, need=111,  singu="universalsingularities:universal.enderIO.singularity", sDmg=1},
  {name="Энергосплав",    block="EnderIO:blockIngotStorage", dmg=1, need=111,  singu="universalsingularities:universal.enderIO.singularity", sDmg=2},
  {name="Тёмная сталь",   block="EnderIO:blockIngotStorage", dmg=6, need=111,  singu="universalsingularities:universal.enderIO.singularity", sDmg=3},
  {name="Пульсирующее",   block="EnderIO:blockIngotStorage", dmg=5, need=111,  singu="universalsingularities:universal.enderIO.singularity", sDmg=4},
  {name="Соулариевая",    block="EnderIO:blockIngotStorage", dmg=7, need=111,  singu="universalsingularities:universal.enderIO.singularity", sDmg=6},
  {name="Вибрирующий",    block="EnderIO:blockIngotStorage", dmg=2, need=111,  singu="universalsingularities:universal.enderIO.singularity", sDmg=7},
  {name="Дракониевая",    block="DraconicEvolution:draconium", dmg=0, need=600,  singu="universalsingularities:universal.draconicEvolution.singularity", sDmg=0},
  {name="Ториевая",       block="mcs_addons:tile.thorium_block", dmg=0, need=111, singu="thermsingul:Thermal Singularity", sDmg=0},
  {name="Обедн. торий",   block="mcs_addons:tile.thorium_imp_block", dmg=0, need=55, singu="universalsingularities:universal.bigReactors.singularity", sDmg=1},
  {name="Обогащ. торий",  block="mcs_addons:tile.thorium_reb_block", dmg=0, need=33, singu="universalsingularities:universal.bigReactors.singularity", sDmg=0},
}

local function key(id,dmg) return tostring(id)..":"..tostring(dmg or 0) end

function M.init(config)
  me = utils.get("me_interface") or utils.get("ae2_interface") or utils.get("me_controller")
  lastScan, cache = 0, {}
end

function M.getItems() return items end
function M.getQty(id,dmg) return cache[key(id,dmg)] or 0 end

function M.scan()
  if not me then return false end
  local now = computer.uptime()
  if now - lastScan < SCAN_INTERVAL then return false end
  lastScan = now
  local changed = false
  for _,it in ipairs(items) do
    for _,pair in ipairs({{it.block,it.dmg},{it.singu,it.sDmg}}) do
      local k = key(pair[1],pair[2])
      local qty = 0
      pcall(function()
        local d = me.getItemDetail({id=pair[1], dmg=pair[2]})
        if d then local st = d.all and d.all() or d; qty = st and (st.qty or st.size or 0) or 0 end
      end)
      if cache[k] ~= qty then cache[k]=qty; changed=true end
    end
  end
  return changed
end

return M
