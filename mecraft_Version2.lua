-- mecraft.lua — автокрафт без ограничений по CPU

local me = require("component").me_interface

local mecraft = {}

function mecraft.request_craft_safe(craftable, count, item_name, log)
  local success = false
  while not success do
    local cpus = me.getCpus()
    local found = false
    for i=1,#cpus do if not cpus[i].busy then found = true; break end end
    if found then
      local ok, msg = pcall(function() return craftable.request(count, false) end)
      if ok then log("ok","Заказано: "..item_name.." x"..count); success = true
      else
        if tostring(msg):find("missing resources") then log("warn","Не хватает для "..item_name); return false
        elseif tostring(msg):find("no recipe") then log("err","Нет рецепта "..item_name); return false
        else log("err","Ошибка: "..tostring(msg)); return false end
      end
    else
      log("info","Ожидание свободного CPU для "..item_name)
      os.sleep(1)
    end
  end
  return true
end

return mecraft