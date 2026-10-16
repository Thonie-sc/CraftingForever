-- Player position and world map helpers (HereBeDragons does the map math).

local CF = CraftingForever
local HBD = CF.HBD

-- Returns uiMapID, x, y (zone percent 0-100) or nil when the position is unknown
-- (instances, loading screens).
function CF.PlayerPosition()
  local x, y, map = HBD:GetPlayerZonePosition()
  if not x or not map then return nil end
  return map, x * 100, y * 100
end

-- Opens the world map on the given zone.
function CF.ShowZoneOnMap(map)
  if OpenWorldMap then
    OpenWorldMap(map)
  else
    if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
    WorldMapFrame:SetMapID(map)
  end
end

-- uiMapID the world map currently shows, or nil when it is closed.
function CF.CurrentMapArea()
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return nil end
  return WorldMapFrame:GetMapID()
end
