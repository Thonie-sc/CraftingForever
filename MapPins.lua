-- World map layer: gathered nodes (material icons) and the active route.

local CF = CraftingForever

local overlay
local pins, dots = {}, {}
local usedPins, usedDots = 0, 0
local MAX_DOTS = 3000
local DOT_SPACING = 7

local function tooltip()
  return WorldMapTooltip or GameTooltip
end

local function pinOnEnter()
  local tt = tooltip()
  tt:SetOwner(this, "ANCHOR_RIGHT")
  local m = CF.materials[this.key]
  tt:AddLine(m and m.name or "?", 1, 1, 1)
  if this.learned then
    local n = this.learned
    tt:AddLine(string.format("Gathered %d time%s", n[3] or 1, (n[3] or 1) == 1 and "" or "s"), 0.8, 0.8, 0.8)
    if n[4] then tt:AddLine("Last: " .. date("%Y-%m-%d %H:%M", n[4]), 0.8, 0.8, 0.8) end
  else
    if this.mob then
      local mob = CraftingForever_SkinDB.mobs[this.mob]
      if mob then tt:AddLine(string.format("%s (level %d-%d)", mob[1], mob[2], mob[3]), 0.8, 0.8, 0.8) end
    end
    if this.index then tt:AddLine("Route stop " .. this.index, 0.5, 0.8, 1) end
  end
  tt:Show()
end

local function pinOnLeave()
  tooltip():Hide()
end

local function getPin()
  usedPins = usedPins + 1
  local pin = pins[usedPins]
  if not pin then
    pin = CreateFrame("Button", nil, overlay)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints(pin)
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin:SetScript("OnEnter", pinOnEnter)
    pin:SetScript("OnLeave", pinOnLeave)
    pins[usedPins] = pin
  end
  pin.learned, pin.mob, pin.index, pin.key = nil, nil, nil, nil
  return pin
end

local function getDot()
  if usedDots >= MAX_DOTS then return nil end
  usedDots = usedDots + 1
  local dot = dots[usedDots]
  if not dot then
    dot = overlay:CreateTexture(nil, "BACKGROUND")
    dot:SetTexture(1, 0.82, 0.1, 0.9)
    dot:SetWidth(3)
    dot:SetHeight(3)
    dots[usedDots] = dot
  end
  return dot
end

local function place(region, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("CENTER", overlay, "TOPLEFT", x / 100 * w, -y / 100 * h)
  region:Show()
end

-- icon key for a route point: first selected material available there
local function pointKey(r, p)
  for i = 1, table.getn(r.keys) do
    if p.mats[r.keys[i]] then return r.keys[i] end
  end
  for k in pairs(p.mats) do return k end
end

local function drawRoute(r, w, h)
  local n = table.getn(r.order)
  for i = 1, n do
    local p = r.points[r.order[i]]
    local q = r.points[r.order[i + 1] or r.order[1]]
    local x1, y1 = p.x / 100 * w, p.y / 100 * h
    local x2, y2 = q.x / 100 * w, q.y / 100 * h
    local dist = math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
    local steps = math.floor(dist / DOT_SPACING)
    for s = 1, steps - 1 do
      local dot = getDot()
      if not dot then break end
      local t = s / steps
      dot:ClearAllPoints()
      dot:SetPoint("CENTER", overlay, "TOPLEFT", x1 + (x2 - x1) * t, -(y1 + (y2 - y1) * t))
      dot:Show()
    end
  end
  local size = math.max(8, CF.settings.pinSize - 4)
  for i = 1, n do
    local p = r.points[r.order[i]]
    local pin = getPin()
    pin.key, pin.mob, pin.index = pointKey(r, p), p.mob, i
    pin.icon:SetTexture(CF.MaterialIcon(pin.key))
    pin:SetAlpha(0.75)
    pin:SetWidth(size)
    pin:SetHeight(size)
    pin:SetFrameLevel(overlay:GetFrameLevel() + 1)
    place(pin, p.x, p.y, w, h)
  end
end

function CF.UpdateWorldMap()
  if not overlay then return end
  for i = 1, usedPins do pins[i]:Hide() end
  for i = 1, usedDots do dots[i]:Hide() end
  usedPins, usedDots = 0, 0
  if not WorldMapFrame:IsVisible() then return end

  local area = CF.CurrentMapArea()
  if not area then return end
  local w, h = overlay:GetWidth(), overlay:GetHeight()

  local r = CF.activeRoute
  if CF.settings.showRoute and r and r.area == area then
    drawRoute(r, w, h)
  end

  if CF.settings.showLearned then
    local size = CF.settings.pinSize
    CF.ForEachLearned(area, function(key, node)
      local pin = getPin()
      pin.key, pin.learned = key, node
      pin.icon:SetTexture(CF.MaterialIcon(key))
      pin:SetAlpha(1)
      pin:SetWidth(size)
      pin:SetHeight(size)
      pin:SetFrameLevel(overlay:GetFrameLevel() + 2)
      place(pin, node[1], node[2], w, h)
    end)
  end
end

CF.On("INIT", function()
  overlay = CreateFrame("Frame", "CraftingForeverMapOverlay", WorldMapButton)
  overlay:SetAllPoints(WorldMapButton)
  overlay:SetFrameLevel(WorldMapButton:GetFrameLevel() + 3)

  local oldOnShow = WorldMapFrame:GetScript("OnShow")
  WorldMapFrame:SetScript("OnShow", function()
    if oldOnShow then oldOnShow() end
    CF.UpdateWorldMap()
  end)
end)

CF.RegisterEvent("WORLD_MAP_UPDATE", function() CF.UpdateWorldMap() end)
CF.On("NODES_UPDATED", function() CF.UpdateWorldMap() end)
CF.On("ROUTE_CHANGED", function() CF.UpdateWorldMap() end)
