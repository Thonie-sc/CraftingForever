-- Anvils and forges: shown on the maps and as "nearest" hints for characters
-- whose professions need them (forges for smelting, anvils for blacksmithing).

local CF = CraftingForever

CF.STATIONS = {
  anvil = { icon = "Interface\\Icons\\Trade_BlackSmithing", label = "Anvil", profs = { blacksmithing = true } },
  forge = { icon = "Interface\\Icons\\Spell_Fire_FlameBlades", label = "Forge", profs = { mining = true, blacksmithing = true } },
}
CF.STATION_ORDER = { "forge", "anvil" }

-- capital cities: they hold anvils and forges, but are no farming zones
CF.CITIES = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }

-- Station kinds the character's professions use (empty when disabled).
function CF.WantedStations()
  local wanted = {}
  if not (CF.settings and CF.settings.showStations) then return wanted end
  for kind, def in pairs(CF.STATIONS) do
    for prof in pairs(def.profs) do
      if CF.profs[prof] then wanted[kind] = true end
    end
  end
  return wanted
end

-------------------------------------------------------------------------------
-- discovered stations
--
-- Every anvil/forge the character uses is remembered per character in
-- CraftingForeverCharDB.stations[map][kind] = { {x, y}, ... }. Adventure mode
-- shows only those; normal mode shows the bundled ones plus any used station
-- that is missing from the bundled data.
-------------------------------------------------------------------------------

local USE_RANGE = 15  -- yards between the player and the station they used

function CF.AdventureMode()
  return CF.settings and CF.settings.adventureMode
end

local function discovered(map, kind)
  local maps = CF.cdb and CF.cdb.stations
  return maps and maps[map] and maps[map][kind] or nil
end

-- Iterates the stations of a kind on one map: fn(map, x, y), x/y in zone percent.
local function eachOnMap(map, kind, fn)
  local used = discovered(map, kind)
  if used then
    for i = 1, #used do fn(map, used[i][1], used[i][2]) end
  end
  if CF.AdventureMode() then return end
  local stations = CraftingForever_Stations[map]
  local list = stations and stations[kind]
  if not list then return end
  for i = 1, #list do
    local x, y = CF.Unpack(list[i])
    -- skip bundled stations already listed as discovered
    local dup = false
    if used then
      for j = 1, #used do
        if CF.Distance(map, x, y, used[j][1], used[j][2]) < 3 then dup = true break end
      end
    end
    if not dup then fn(map, x, y) end
  end
end

function CF.ForEachStation(kind, fn)
  local maps = {}
  for map in pairs(CraftingForever_Stations) do maps[map] = true end
  for map in pairs(CF.cdb and CF.cdb.stations or {}) do maps[map] = true end
  for map in pairs(maps) do eachOnMap(map, kind, fn) end
end

-- Nearest station of a kind in the player's zone: x, y, yards (or nil).
function CF.NearestStation(kind)
  local map, px, py = CF.PlayerPosition()
  if not map then return nil end
  local bx, by, best
  eachOnMap(map, kind, function(_, x, y)
    local d = CF.Distance(map, px, py, x, y)
    if not best or d < best then bx, by, best = x, y, d end
  end)
  return bx, by, best
end

-- Is a bundled station of this kind within reach of the player?
local function bundledInRange(kind)
  local map, px, py = CF.PlayerPosition()
  local stations = map and CraftingForever_Stations[map]
  local list = stations and stations[kind] or {}
  for i = 1, #list do
    local x, y = CF.Unpack(list[i])
    if CF.Distance(map, px, py, x, y) <= USE_RANGE then return true end
  end
  return false
end

-- Remember that the player used a station of this kind right here. Snaps to the
-- bundled station in range; otherwise the player's position is stored, which
-- also fills gaps in the bundled data.
function CF.UseStation(kind)
  local map, px, py = CF.PlayerPosition()
  if not map then return end
  local used = discovered(map, kind)
  if used then
    for i = 1, #used do
      if CF.Distance(map, px, py, used[i][1], used[i][2]) <= USE_RANGE then return end
    end
  end
  local sx, sy, best = px, py, nil
  local stations = CraftingForever_Stations[map]
  local list = stations and stations[kind] or {}
  for i = 1, #list do
    local x, y = CF.Unpack(list[i])
    local d = CF.Distance(map, px, py, x, y)
    if d <= USE_RANGE and (not best or d < best) then sx, sy, best = x, y, d end
  end
  local maps = CF.cdb.stations
  maps[map] = maps[map] or {}
  maps[map][kind] = maps[map][kind] or {}
  table.insert(maps[map][kind], { math.floor(sx * 10 + 0.5) / 10, math.floor(sy * 10 + 0.5) / 10 })
  CF.Print(string.format(CF.L["Discovered: %s in %s (%.1f, %.1f)"], CF.L[CF.STATIONS[kind].label],
    CF.ZoneName(map), sx, sy))
  CF.Fire("STATIONS_UPDATED")
end

-------------------------------------------------------------------------------
-- detecting use: smelting uses a forge, blacksmithing crafts use an anvil
-------------------------------------------------------------------------------

local SMELTING = {
  [2657] = true, [2659] = true, [2658] = true, [3304] = true, [3307] = true, [3308] = true,
  [3569] = true, [10097] = true, [10098] = true, [14891] = true, [16153] = true, [22967] = true,
}

local tradeOpen = false

-- profession of the open trade skill window, if the client tells us
local function openTradeSkill()
  if GetTradeSkillLine then
    local ok, name = pcall(GetTradeSkillLine)
    if ok and name then
      for key in pairs(CF.SKILL_LINES) do
        if CF.ProfName(key) == name then return key end
      end
    end
  end
  if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
    local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if ok and type(info) == "table" then
      local id = info.professionID or info.skillLineID
      for key, line in pairs(CF.SKILL_LINES) do
        if id == line or info.professionName == CF.ProfName(key) then return key end
      end
    end
  end
  return nil
end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE" }) do
  pcall(CF.RegisterEvent, ev, function() tradeOpen = (ev == "TRADE_SKILL_SHOW") end)
end

CF.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit ~= "player" then return end
  if SMELTING[spellID] then
    CF.UseStation("forge")
  elseif tradeOpen and CF.profs.blacksmithing then
    local prof = openTradeSkill()
    -- when the client can't tell which window is open, crafting next to a
    -- known anvil counts
    if prof == "blacksmithing" or (prof == nil and bundledInRange("anvil")) then
      CF.UseStation("anvil")
    end
  end
end)

-- "Forge: 320 yd (42.1, 65.3)" for every wanted station kind, or nil.
function CF.NearestStationsText()
  local wanted = CF.WantedStations()
  local parts = {}
  for _, kind in ipairs(CF.STATION_ORDER) do
    if wanted[kind] then
      local x, y, d = CF.NearestStation(kind)
      local label = CF.L[CF.STATIONS[kind].label]
      if d then
        table.insert(parts, string.format(CF.L["%s: %d yd (%.1f, %.1f)"], label, d, x, y))
      elseif CF.AdventureMode() then
        table.insert(parts, string.format(CF.L["%s: none discovered in this zone"], label))
      else
        table.insert(parts, string.format(CF.L["%s: none in this zone"], label))
      end
    end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, "  ")
end
