-- PRISMA CORE Singularity Module (интеграция Sing,lua)
-- Карточки + фоновое обновление количеств

local component = require("component")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local me
local active = false

-- Список из твоего Sing,lua (сокращённый для начала, полный можно расширить)
local items = {
  {name = "Железная", block = "minecraft:iron_ore", dmg = 0, need = 4500, singu = "Avaritia:Singularity", sDmg = 0},
  {name = "Золотая", block = "minecraft:gold_ore", dmg = 0, need = 2700, singu = "Avaritia:Singularity", sDmg = 1},
  {name = "Алмазная", block = "minecraft:diamond_block", dmg = 0, need = 600, singu = "universalsingularities:universal.vanilla.singularity", sDmg = 2},
  {name = "Дракониевая", block = "DraconicEvolution:draconium", dmg = 0, need = 600, singu = "universalsingularities:universal.draconicEvolution.singularity", sDmg = 0},
}

function M.init(config)
  me = utils.get("me_interface") or utils.get("ae2_interface")
end

function M.setActive(v) active = v end
function M.isActive() return active end

function M.getItems()
  return items
end

function M.getQty(id, dmg)
  if not me then return 0 end
  local ok, data = pcall(function() return me.getItemDetail({id = id, dmg = dmg}) end)
  if ok and data then
    local st = data.all and data.all() or data
    return st and (st.qty or st.size or 0) or 0
  end
  return 0
end

return M
