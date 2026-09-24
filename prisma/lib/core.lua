-- PRISMA CORE Energy Core Module (1 ядро)

local component = require("component")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local rf, gate
local cfg
local lastE, filVal = 0, 0

function M.init(config)
  cfg = config.core or {}
  rf = utils.get("draconic_rf_storage")
  gate = utils.get("flux_gate")  -- основной выходной гейт ядра (если несколько — берём первый)
  lastE = rf and rf.getEnergyStored() or 0
  filVal = 0
end

function M.update()
  if not rf or not gate then return end
  local cur = rf.getEnergyStored() or 0
  local flow = 0
  pcall(function() flow = gate.getFlow() or gate.getSignalLowFlow() or 0 end)

  -- EMA фильтрация
  filVal = filVal + ((cur - lastE) - filVal) * 0.25

  local target = cfg.target or (200 * 1e9)
  local maxDiff = cfg.maxDiff or 25000
  local step = cfg.step or 10000

  if cur > target then
    if filVal > -maxDiff then
      pcall(gate.setSignalLowFlow, math.min((cfg.flowMax or 4e7), flow + step))
    end
  else
    if filVal < maxDiff and flow > (cfg.flowMin or 1000) then
      pcall(gate.setSignalLowFlow, math.max(cfg.flowMin or 1000, flow - step))
    end
  end
  lastE = cur
end

function M.getInfo()
  if not rf then return {online = false} end
  local cur = rf.getEnergyStored() or 0
  local max = rf.getMaxEnergyStored() or 1
  local flow = 0
  pcall(function() flow = gate and (gate.getFlow() or gate.getSignalLowFlow()) or 0 end)
  return {
    online = true,
    energy = cur,
    max = max,
    percent = cur / max,
    flow = flow,
    target = cfg.target or 0,
    filtered = filVal
  }
end

function M.setTarget(val)
  if cfg then cfg.target = val end
end

function M.adjustTarget(delta)
  if cfg then cfg.target = math.max(0, (cfg.target or 0) + delta) end
end

return M
