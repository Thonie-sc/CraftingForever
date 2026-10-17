-- Map layers: gathered nodes and active route stops as material icons on the
-- world map and minimap (HereBeDragons-Pins), and the route path drawn as line
-- segments on the world map canvas.

local CF = CraftingForever
local HBDP = LibStub("HereBeDragons-Pins-2.0")

local REF = "CraftingForever"
local worldPool, miniPool = {}, {}
local usedWorld, usedMini = 0, 0

-------------------------------------------------------------------------------
-- icons
-------------------------------------------------------------------------------

local function pinOnEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if self.station then
    GameTooltip:AddLine(CF.L[CF.STATIONS[self.station].label], 1, 1, 1)
    GameTooltip:Show()
    return
  end
  local m = CF.materials[self.key]
  GameTooltip:AddLine(m and m.name or "?", 1, 1, 1)
  if self.learned then
    local n = self.learned
    GameTooltip:AddLine(string.format(CF.L["Gathered %d time(s)"], n[3] or 1), 0.8, 0.8, 0.8)
    if n[4] then GameTooltip:AddLine(CF.L["Last:"] .. " " .. date("%Y-%m-%d %H:%M", n[4]), 0.8, 0.8, 0.8) end
  else
    if self.mob then
      local mob = CraftingForever_SkinDB.mobs[self.mob]
      if mob then
        GameTooltip:AddLine(string.format(CF.L["%s (level %d-%d)"], CF.MobName(self.mob), mob[2], mob[3]), 0.8, 0.8, 0.8)
      end
    end
    if self.index then GameTooltip:AddLine(string.format(CF.L["Route stop %d"], self.index), 0.5, 0.8, 1) end
  end
  GameTooltip:Show()
end

local function newPin()
  local pin = CreateFrame("Button")
  pin.icon = pin:CreateTexture(nil, "ARTWORK")
  pin.icon:SetAllPoints(pin)
  pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  pin:SetScript("OnEnter", pinOnEnter)
  pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return pin
end

local function setupPin(pin, key, size, alpha, learned, mob, index)
  pin.key, pin.learned, pin.mob, pin.index, pin.station = key, learned, mob, index, nil
  pin.icon:SetTexture(CF.MaterialIcon(key))
  pin:SetSize(size, size)
  pin:SetAlpha(alpha)
end

local function worldPin()
  usedWorld = usedWorld + 1
  if not worldPool[usedWorld] then worldPool[usedWorld] = newPin() end
  return worldPool[usedWorld]
end

local function miniPin()
  usedMini = usedMini + 1
  if not miniPool[usedMini] then miniPool[usedMini] = newPin() end
  return miniPool[usedMini]
end

-- icon key for a route point: first selected material available there
local function pointKey(r, p)
  for i = 1, #r.keys do
    if p.yield[r.keys[i]] then return r.keys[i] end
  end
  for k in pairs(p.yield) do return k end
end

local function refreshIcons()
  HBDP:RemoveAllWorldMapIcons(REF)
  HBDP:RemoveAllMinimapIcons(REF)
  usedWorld, usedMini = 0, 0
  local s = CF.settings

  local r = CF.activeRoute
  if r and s.showRoute then
    local size = math.max(8, s.pinSize - 4)
    for i = 1, #r.order do
      local p = r.points[r.order[i]]
      local key = pointKey(r, p)
      local pin = worldPin()
      setupPin(pin, key, size, 0.8, nil, p.mob, i)
      HBDP:AddWorldMapIconMap(REF, pin, r.area, p.x / 100, p.y / 100)
      if s.minimapPins then
        local mpin = miniPin()
        setupPin(mpin, key, s.minimapPinSize - 2, 0.7, nil, p.mob, i)
        HBDP:AddMinimapIconMap(REF, mpin, r.area, p.x / 100, p.y / 100, false, false)
      end
    end
  end

  for kind in pairs(CF.WantedStations()) do
    local def = CF.STATIONS[kind]
    CF.ForEachStation(kind, function(map, x, y)
      local pin = worldPin()
      setupPin(pin, nil, s.pinSize, 1)
      pin.station = kind
      pin.icon:SetTexture(def.icon)
      HBDP:AddWorldMapIconMap(REF, pin, map, x / 100, y / 100)
      if s.minimapPins then
        local mpin = miniPin()
        setupPin(mpin, nil, s.minimapPinSize, 1)
        mpin.station = kind
        mpin.icon:SetTexture(def.icon)
        HBDP:AddMinimapIconMap(REF, mpin, map, x / 100, y / 100, false, false)
      end
    end)
  end

  if s.showLearned then
    for map in pairs(CF.db.nodes) do
      CF.ForEachLearned(map, function(key, node)
        local pin = worldPin()
        setupPin(pin, key, s.pinSize, 1, node)
        HBDP:AddWorldMapIconMap(REF, pin, map, node[1] / 100, node[2] / 100)
        if s.minimapPins then
          local mpin = miniPin()
          setupPin(mpin, key, s.minimapPinSize, 1, node)
          HBDP:AddMinimapIconMap(REF, mpin, map, node[1] / 100, node[2] / 100, false, false)
        end
      end)
    end
  end
end

-------------------------------------------------------------------------------
-- route path on the world map canvas
-------------------------------------------------------------------------------

local pathFrame
local lines = {}

local function drawPath()
  if not pathFrame then return end
  for i = 1, #lines do lines[i]:Hide() end
  local r = CF.activeRoute
  if not (r and CF.settings.showRoute and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == r.area) then
    return
  end
  local canvas = WorldMapFrame:GetCanvas()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local n = #r.order
  for i = 1, n do
    local p = r.points[r.order[i]]
    local q = r.points[r.order[i + 1] or r.order[1]]
    local line = lines[i]
    if not line then
      line = pathFrame:CreateLine(nil, "OVERLAY")
      line:SetColorTexture(1, 0.82, 0.1, 0.85)
      lines[i] = line
    end
    line:SetThickness(math.max(2, w / 500))
    line:SetStartPoint("TOPLEFT", canvas, p.x / 100 * w, -p.y / 100 * h)
    line:SetEndPoint("TOPLEFT", canvas, q.x / 100 * w, -q.y / 100 * h)
    line:Show()
  end
end

function CF.UpdateWorldMap()
  refreshIcons()
  drawPath()
end
CF.UpdateMinimap = CF.UpdateWorldMap

CF.On("INIT", function()
  local canvas = WorldMapFrame:GetCanvas()
  pathFrame = CreateFrame("Frame", nil, canvas)
  pathFrame:SetAllPoints(canvas)
  pathFrame:SetFrameLevel(canvas:GetFrameLevel() + 100)
  WorldMapFrame:HookScript("OnShow", drawPath)
  if WorldMapFrame.OnMapChanged then
    hooksecurefunc(WorldMapFrame, "OnMapChanged", drawPath)
  end
end)

CF.RegisterEvent("PLAYER_ENTERING_WORLD", refreshIcons)
CF.On("NODES_UPDATED", CF.UpdateWorldMap)
CF.On("ROUTE_CHANGED", CF.UpdateWorldMap)
CF.On("PROFESSIONS_UPDATED", CF.UpdateWorldMap)
CF.On("STATIONS_UPDATED", CF.UpdateWorldMap)
