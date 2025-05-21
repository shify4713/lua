-- main.lua — основной цикл, интеграция, обработка событий, рендер

local ui = require("ui")
local storage = require("storage")
local mecraft = require("mecraft")
local component = require("component")
local event = require("event")
local unicode = require("unicode")
local gpu = component.gpu
local me = component.me_interface

local WIDTH, HEIGHT = 160, 50
local PATH = "/home/BD.txt"

local COLORS = {
  bg = 0x23272e, fg = 0xE6EDF3, border = 0x2866b2, err = 0xFF3C3C,
  ok = 0x7CFC00, warn = 0xFFD700, info = 0x66FFFF,
  select_bg = 0x3A5068, select_fg = 0xF1F1F1,
  btn_bg = 0x2980b9, btn_fg = 0xf7f7f7, btn_act = 0x155a8a,
  btn_border = 0x2980b9, btn_shadow = 0x1d2731,
  tab_on = 0x2980b9, tab_off = 0x23272e, tab_fg = 0xFFFFFF,
  input_bg = 0x1c232b, input_fg = 0xA4FFFA, input_border = 0x2980b9,
  log_bg = 0x242b33, log_ok = 0x7CFC00, log_warn = 0xFFD700, log_err = 0xFF3C3C, log_info = 0x66FFFF,
  log_time = 0x474a4e, log_txt = 0xE6EDF3, search_bg = 0x26324a, search_icon = 0x50B9FF
}

gpu.setResolution(WIDTH, HEIGHT)

local function clamp(val, min, max) return math.max(min, math.min(val, max)) end

local state = {
  tab = 1, tabs = {"Главная", "Изменить", "Логи"},
  data = {}, logs = {}, select = 1, scroll = 1, search = "",
  input = {active=false, value="", prompt="", action=nil, next=nil, params={}},
  go = false, error = nil, filtered = {}, maxscroll = 1,
  redraw = true, hover = {btn=nil, item=nil, tab=nil, search=false},
  logScroll = 1, btns = {}, itemHit = {}, chBtnHit={}, searchHit=nil
}

local function now_msk()
  local utc = os.time(os.date("!*t"))
  local msk = utc + 3*3600
  local t = os.date("*t", msk)
  return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end
local function log(kind, msg)
  table.insert(state.logs, {kind=kind, time=now_msk(), msg=msg})
  if #state.logs>40 then table.remove(state.logs,1) end
  state.redraw=true
end

-- === Интерфейс, рисуем всё
local function render()
  gpu.setBackground(COLORS.bg); gpu.setForeground(COLORS.fg)
  gpu.fill(1,1,WIDTH,HEIGHT," ")
  ui.border(1,1,WIDTH,HEIGHT,COLORS.border)
  gpu.set(math.floor(WIDTH/2-10),2,"PreCraft ULTIMATE")
  state.tabHit = ui.tabBar(state.tabs, state.tab, COLORS)
  -- Кнопки
  local y = 44
  local btns = {
    {"Добавить", "add", 7, y, false},
    {"Изменить", "edit", 27, y, false},
    {"Удалить", "del", 47, y, false},
    {(state.go and "⏸ Остановить" or "▶ Запуск"), "toggleGo", 67, y, state.go},
  }
  state.btns = {}
  for i,b in ipairs(btns) do
    local hover = (state.hover.btn == i)
    local pressed = (state.hover.pressed and state.hover.btn == i)
    ui.btn(b[3], b[4], 18, 3, b[1], COLORS, b[5], hover, pressed)
    state.btns[#state.btns+1] = {x1=b[3], x2=b[3]+17, y1=b[4], y2=b[4]+2, action=b[2], idx=i}
  end
  -- Поиск
  local sx,sy = 7,41
  gpu.setBackground(COLORS.search_bg)
  gpu.fill(sx,sy,60,3," ")
  ui.border(sx,sy,60,3,COLORS.btn_border)
  gpu.setForeground(COLORS.search_icon)
  gpu.set(sx+2,sy+1,"⦾")
  gpu.setForeground(COLORS.fg)
  gpu.set(sx+5,sy+1,state.search=="" and "Поиск по названию..." or state.search)
  gpu.setBackground(COLORS.bg)
  state.searchHit = {x1=sx,y1=sy,x2=sx+59,y2=sy+2}
  -- Список
  local filtered, search = {}, unicode.lower(state.search or "")
  for i,v in ipairs(state.data) do
    if search=="" or unicode.lower(v.name or ""):find(search) then table.insert(filtered,v) end
  end
  state.filtered=filtered
  local show = 30
  state.maxscroll = math.max(1, #filtered-show+1)
  state.select = clamp(state.select, 1, #filtered)
  state.scroll = clamp(state.scroll, 1, state.maxscroll)
  state.itemHit = {}
  gpu.setBackground(COLORS.tab_on)
  gpu.setForeground(0xffffff)
  gpu.set(8,7,"Название")
  gpu.set(42,7,"Кол-во")
  gpu.set(56,7,"Крафт")
  gpu.setBackground(COLORS.bg)
  gpu.setForeground(COLORS.fg)
  for i=state.scroll,math.min(#filtered,state.scroll+show-1) do
    local v=filtered[i]; local y=7+(i-state.scroll)+1
    local sel = (i==state.select)
    gpu.setBackground(sel and COLORS.select_bg or COLORS.bg)
    gpu.setForeground(sel and COLORS.select_fg or COLORS.fg)
    gpu.set(8,y,v.name or "")
    gpu.set(42,y,tostring(v.count or ""))
    gpu.set(56,y,tostring(v.craftSize or ""))
    state.itemHit[#state.itemHit+1]={x1=8,x2=72,y=y,idx=i}
  end
  gpu.setBackground(COLORS.bg)
  gpu.setForeground(COLORS.fg)
  -- Логи
  local x0,y0,w0,h0 = 80,6,78,38
  gpu.setBackground(COLORS.log_bg)
  gpu.fill(x0,y0,w0,h0," ")
  ui.border(x0,y0,w0,h0,COLORS.tab_on)
  gpu.setForeground(COLORS.tab_on)
  gpu.set(x0+3,y0," ЛОГИ АВТОКРАФТА ")
  gpu.setForeground(COLORS.fg)
  local logs = state.logs
  local showl = h0-4
  local maxScroll = math.max(1,#logs-showl+1)
  state.logScroll = clamp(state.logScroll, 1, maxScroll)
  for i=state.logScroll,math.min(#logs,state.logScroll+showl-1) do
    local lg = logs[i]
    local y = y0+1+(i-state.logScroll)
    local col = lg.kind=="ok" and COLORS.log_ok or lg.kind=="warn" and COLORS.log_warn or lg.kind=="err" and COLORS.log_err or lg.kind=="info" and COLORS.log_info or COLORS.log_txt
    gpu.setForeground(COLORS.log_time)
    gpu.set(x0+2, y, "["..lg.time.."] ")
    gpu.setForeground(col)
    gpu.set(x0+12, y, lg.msg)
  end
  gpu.setBackground(COLORS.bg)
  gpu.setForeground(COLORS.fg)
  -- Модальное окно
  if state.input.active then
    ui.inputModal(WIDTH, HEIGHT, COLORS, state.input.prompt, state.input.value)
  end
  -- Ошибки
  if state.error then
    gpu.setForeground(COLORS.err)
    gpu.set(6,HEIGHT-1,"Ошибка: "..tostring(state.error))
    gpu.setForeground(COLORS.fg)
  end
end

local function askInput(prompt, action, default, nextFunc, params)
  state.input={active=true,value=default or "",prompt=prompt,action=action,next=nextFunc or nil,params=params or {}}
  state.redraw=true
end
local function resetInput() state.input={active=false,value="",prompt="",action=nil, next=nil, params={}} end

local function commitInput()
  if state.input.action == "add_name" then
    askInput("Сколько поддерживать в наличии?", "add_count", "1", nil, {name=state.input.value})
  elseif state.input.action == "add_count" then
    askInput("Максимальный размер крафта?", "add_craft", "1", nil, {name=state.input.params.name, count=tonumber(state.input.value)})
  elseif state.input.action == "add_craft" then
    local item = me.getStackInSlot(1)
    if not item then
      state.error = "Положите предмет в 1-й слот ME-интерфейса!"
      resetInput(); state.redraw=true; return
    end
    table.insert(state.data, {
      name = state.input.params.name,
      id = item.id,
      dmg = item.dmg,
      count = state.input.params.count,
      craftSize = tonumber(state.input.value)
    })
    storage.save(PATH, state.data)
    log("ok","Добавлен: "..state.input.params.name)
    resetInput()
    state.redraw=true
  elseif state.input.action == "edit_name" then
    local v = state.filtered[state.select]
    if v then v.name = state.input.value end
    storage.save(PATH, state.data)
    log("info","Имя изменено")
    resetInput(); state.redraw=true
  elseif state.input.action == "edit_count" then
    local v = state.filtered[state.select]
    if v then v.count = tonumber(state.input.value) end
    storage.save(PATH, state.data)
    log("info","Кол-во изменено")
    resetInput(); state.redraw=true
  elseif state.input.action == "edit_craft" then
    local v = state.filtered[state.select]
    if v then v.craftSize = tonumber(state.input.value) end
    storage.save(PATH, state.data)
    log("info","Размер крафта изменён")
    resetInput(); state.redraw=true
  elseif state.input.action == "search" then
    state.search=state.input.value
    resetInput(); state.redraw=true
  end
end

local function handleKeyDown(_,_,char,code,playerName)
  -- БОЛЬШЕ НЕТ ПРОВЕРКИ НА АДМИНА!
  if state.input.active then
    if code==13 then commitInput()
    elseif code==8 then
      if #state.input.value>0 then
        state.input.value=unicode.sub(state.input.value,1,unicode.len(state.input.value)-1)
      end
    elseif code==27 then resetInput(); state.redraw=true
    elseif char and type(char)=="string" and unicode.len(state.input.value)<48 then
      state.input.value=state.input.value..char
    end
    state.redraw=true
  end
end

local function hoverUpdate(x, y)
  state.hover = {btn=nil, item=nil, tab=nil, search=false}
  for i,b in ipairs(state.btns) do
    if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then state.hover.btn=i; break end
  end
  for _,t in ipairs(state.tabHit or {}) do
    if y==t.y and x>=t.x1 and x<=t.x2 then state.hover.tab=t.idx; break end
  end
  if state.searchHit and x>=state.searchHit.x1 and x<=state.searchHit.x2 and y>=state.searchHit.y1 and y<=state.searchHit.y2 then
    state.hover.search=true
  end
end

local function handleTouch(_,_,x,y,_,playerName)
  hoverUpdate(x,y)
  for _,t in ipairs(state.tabHit or {}) do
    if y==t.y and x>=t.x1 and x<=t.x2 then state.tab=t.idx; state.redraw=true; return end
  end
  if state.tab==1 and state.searchHit and x>=state.searchHit.x1 and x<=state.searchHit.x2 and y>=state.searchHit.y1 and y<=state.searchHit.y2 then
    askInput("Поиск:","search",state.search)
    return
  end
  if state.tab==1 and state.btns then
    for _,b in ipairs(state.btns) do
      if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then
        state.hover.btn=b.idx; state.hover.pressed=true; state.redraw=true
        os.sleep(0.08)
        state.hover.pressed=false
        if b.action=="add" then
          askInput("Имя предмета:","add_name","")
        elseif b.action=="edit" and state.filtered[state.select] then
          state.tab=2; state.redraw=true
        elseif b.action=="del" and state.filtered[state.select] then
          table.remove(state.data,state.select)
          storage.save(PATH, state.data)
          log("warn","Удалён предмет")
          state.redraw=true
        elseif b.action=="toggleGo" then
          state.go=not state.go; log("info","Режим: "..(state.go and "GO" or "STOP"))
          state.redraw=true
        end
        return
      end
    end
  end
  if state.tab==1 and state.itemHit then
    for _,b in ipairs(state.itemHit) do
      if x>=b.x1 and x<=b.x2 and y==b.y then state.select=b.idx; state.redraw=true; return end
    end
  end
  -- Редактирование
  if state.tab==2 then
    local v = state.filtered[state.select]
    if not v then return end
    local x, y, w, h = 84, 13, 65, 14
    local cx = x+3; local cy = y+9
    if x<=x and y<=y and x<=x+w and y<=y+h then
      if x>=cx and x<=cx+19 and y==cy then askInput("Новое имя:","edit_name",v.name)
      elseif x>=cx+22 and x<=cx+41 and y==cy then askInput("Новое количество:","edit_count",tostring(v.count))
      elseif x>=cx+44 and x<=cx+63 and y==cy then askInput("Новый размер крафта:","edit_craft",tostring(v.craftSize))
      elseif x>=cx+60 and y==cy then state.tab=1; state.redraw=true end
    end
  end
end

local function handleScroll(_,_,x,y,dir,playerName)
  if state.input.active then return end
  if state.tab==1 and state.maxscroll>1 then
    if dir==1 and state.scroll>1 then state.scroll=state.scroll-1; state.redraw=true
    elseif dir==-1 and state.scroll<state.maxscroll then state.scroll=state.scroll+1; state.redraw=true end
  elseif state.tab==3 or (state.tab==1 or state.tab==2) then
    local logs = state.logs
    local show = 38-4
    local maxScroll = math.max(1,#logs-show+1)
    if dir==1 and state.logScroll>1 then state.logScroll=state.logScroll-1; state.redraw=true
    elseif dir==-1 and state.logScroll<maxScroll then state.logScroll=state.logScroll+1; state.redraw=true end
  end
end

local function checkCraft()
  if not state.go then return end
  for i=1,#state.data do
    local v = state.data[i]
    local itemsMe = me.getItemDetail({id=v.id,dmg=v.dmg})
    local qty = itemsMe and itemsMe.basic().qty or 0
    local needAll = (v.count or 0)-qty
    if needAll>0 then
      local craftables = me.getCraftables({name=v.id,damage=v.dmg})
      if craftables.n and craftables.n>=1 then
        local count = math.min(needAll,v.craftSize or needAll)
        mecraft.request_craft_safe(craftables[1], count, v.name or "?", log)
        os.sleep(0.1)
      else
        log("err","Нет рецепта "..(v.name or "?"))
      end
    end
  end
end

local function mainloop()
  state.data = storage.load(PATH)
  event.listen("touch",handleTouch)
  event.listen("key_down",handleKeyDown)
  event.listen("scroll",handleScroll)
  local lastCheck = os.clock()
  while true do
    if state.redraw then render(); state.redraw=false end
    os.sleep(0.02)
    if state.go and os.clock()-lastCheck>6 then checkCraft(); lastCheck=os.clock() end
  end
end

local ok,err=pcall(mainloop)
if not ok then
  gpu.setBackground(COLORS.bg)
  gpu.setForeground(COLORS.err)
  gpu.set(2,HEIGHT-1,"Ошибка: "..tostring(err))
end
