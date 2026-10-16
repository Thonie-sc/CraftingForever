-- Minimap layer: gathered nodes and active route stops near the player.

local CF = CraftingForever

-- minimap diameter in yards per zoom level (1.12 does not rotate the minimap)
local DIAMETER = {
  outdoor = { [0] = 466 + 2 / 3, [1] = 400, [2] = 333 + 1 / 3, [3] = 266 + 2 / 3, [4] = 200, [5] = 133 + 1 / 3 },
  indoor = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
}

local pins = {}
local indoors = false
local detecting = false
local elapsed = 0
local lastArea, lastX, lastY, lastZoom

-- The client stores separate zoom CVars for indoors and outdoors; whichever one
-- follows a zoom change tells us where we are.
local function detectIndoors()
  local zoom = Minimap:GetZoom()
  local outZoom = tonumber(GetCVar("minimapZoom"))
  local inZoom = tonumber(GetCVar("minimapInsideZoom"))
  if outZoom ~= inZoom then
    indoors = (inZoom == zoom)
    return
  end
  if detecting then return end
  detecting = true  -- SetZoom fires MINIMAP_UPDATE_ZOOM again
  if zoom < 2 then Minimap:SetZoom(zoom + 1) else Minimap:SetZoom(zoom - 1) end
  indoors = tonumber(GetCVar("minimapZoom")) ~= Minimap:GetZoom()
  Minimap:SetZoom(zoom)
  detecting = false
end

local function pinOnEnter()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  local m = CF.materials[this.key]
  GameTooltip:AddLine(m and m.name or "?", 1, 1, 1)
  if this.route then GameTooltip:AddLine("Route stop", 0.5, 0.8, 1) end
  GameTooltip:Show()
end

local function getPin(i)
  local pin = pins[i]
  if not pin then
    pin = CreateFrame("Frame", nil, Minimap)
    pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints(pin)
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", pinOnEnter)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pins[i] = pin
  end
  return pin
end

local function routeKey(r, p)
  for i = 1, table.getn(r.keys) do
    if p.mats[r.keys[i]] then return r.keys[i] end
  end
  for k in pairs(p.mats) do return k end
end

local function update(force)
  local used = 0
  local area, px, py = CF.PlayerPosition()
  local zoom = Minimap:GetZoom()
  if not force and area == lastArea and px == lastX and py == lastY and zoom == lastZoom then return end
  lastArea, lastX, lastY, lastZoom = area, px, py, zoom

  if area and CF.settings.minimapPins then
    local z = CraftingForever_Zones[area]
    local diameter = (indoors and DIAMETER.indoor or DIAMETER.outdoor)[zoom] or 466
    local radius = Minimap:GetWidth() / 2
    local scale = Minimap:GetWidth() / diameter   -- pixels per yard
    local maxYards = diameter / 2

    local function show(key, x, y, size, alpha, isRoute)
      local dx = (x - px) * z[7] / 100
      local dy = (y - py) * z[8] / 100
      if math.abs(dx) > maxYards or math.abs(dy) > maxYards then return end
      local ox, oy = dx * scale, dy * scale
      if ox * ox + oy * oy > (radius - size / 2) * (radius - size / 2) then return end
      used = used + 1
      local pin = getPin(used)
      pin.key, pin.route = key, isRoute
      pin.icon:SetTexture(CF.MaterialIcon(key))
      pin:SetWidth(size)
      pin:SetHeight(size)
      pin:SetAlpha(alpha)
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", Minimap, "CENTER", ox, -oy)
      pin:Show()
    end

    local size = CF.settings.minimapPinSize
    local r = CF.activeRoute
    if r and r.area == area and CF.settings.showRoute then
      for i = 1, table.getn(r.points) do
        local p = r.points[i]
        show(routeKey(r, p), p.x, p.y, size - 2, 0.7, true)
      end
    end
    if CF.settings.showLearned then
      CF.ForEachLearned(area, function(key, node)
        show(key, node[1], node[2], size, 1, false)
      end)
    end
  end

  for i = used + 1, table.getn(pins) do pins[i]:Hide() end
end

CF.UpdateMinimap = function() update(true) end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
  elapsed = elapsed + arg1
  if elapsed < 0.1 then return end
  elapsed = 0
  if CF.settings then update(false) end
end)

CF.RegisterEvent("MINIMAP_UPDATE_ZOOM", function()
  detectIndoors()
  update(true)
end)
CF.RegisterEvent("PLAYER_ENTERING_WORLD", function()
  detectIndoors()
  update(true)
end)
CF.RegisterEvent("ZONE_CHANGED", detectIndoors)
CF.RegisterEvent("ZONE_CHANGED_INDOORS", detectIndoors)
CF.RegisterEvent("ZONE_CHANGED_NEW_AREA", detectIndoors)
CF.On("NODES_UPDATED", CF.UpdateMinimap)
CF.On("ROUTE_CHANGED", CF.UpdateMinimap)
