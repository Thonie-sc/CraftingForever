-- Player position and world map zone identification.

local CF = CraftingForever

CF.mapFileToArea = {}
CF.nameToArea = {}
for area, z in pairs(CraftingForever_Zones) do
  CF.mapFileToArea[z[2]] = area
  CF.nameToArea[z[1]] = area
end

-- Area ID of the zone the world map currently displays (nil for continents,
-- cities and instances we have no data for).
function CF.CurrentMapArea()
  if GetMapInfo then
    local mapFile = GetMapInfo()
    if mapFile and CF.mapFileToArea[mapFile] then return CF.mapFileToArea[mapFile] end
  end
  -- fallback for clients without GetMapInfo: english zone names
  local cont, zone = GetCurrentMapContinent(), GetCurrentMapZone()
  if cont and cont > 0 and zone and zone > 0 then
    local names = { GetMapZones(cont) }
    return CF.nameToArea[names[zone]]
  end
  return nil
end

-- Returns area, x, y (zone percent 0-100) or nil when the position is unknown
-- (e.g. the world map is open on another zone, or in an instance).
local lastReset = 0
function CF.PlayerPosition()
  if not WorldMapFrame:IsVisible() then
    local x, y = GetPlayerMapPosition("player")
    -- throttled: in cities/instances there is no zone of ours to switch to
    if ((x == 0 and y == 0) or not CF.CurrentMapArea()) and GetTime() - lastReset > 2 then
      lastReset = GetTime()
      SetMapToCurrentZone()
    end
  end
  local x, y = GetPlayerMapPosition("player")
  if x == 0 and y == 0 then return nil end
  local area = CF.CurrentMapArea()
  if not area then return nil end
  return area, x * 100, y * 100
end

-- Opens the world map on the given zone.
local zoneIndexCache = {}
function CF.ShowZoneOnMap(area)
  local z = CraftingForever_Zones[area]
  if not z then return end
  if not WorldMapFrame:IsVisible() then ToggleWorldMap() end
  local cont = z[3]
  local idx = zoneIndexCache[area]
  if not idx then
    local names = { GetMapZones(cont) }
    for i = 1, table.getn(names) do
      SetMapZoom(cont, i)
      if CF.CurrentMapArea() == area then idx = i break end
    end
    zoneIndexCache[area] = idx
  end
  if idx then SetMapZoom(cont, idx) end
end

CF.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
  if not WorldMapFrame:IsVisible() then SetMapToCurrentZone() end
end)
