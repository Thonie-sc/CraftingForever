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

-- Iterates every station of a kind: fn(map, x, y) with x/y in zone percent.
function CF.ForEachStation(kind, fn)
  for map, kinds in pairs(CraftingForever_Stations) do
    local list = kinds[kind]
    if list then
      for i = 1, #list do
        local x, y = CF.Unpack(list[i])
        fn(map, x, y)
      end
    end
  end
end

-- Nearest station of a kind in the player's zone: x, y, yards (or nil).
function CF.NearestStation(kind)
  local map, px, py = CF.PlayerPosition()
  if not map then return nil end
  local stations = CraftingForever_Stations[map]
  local list = stations and stations[kind]
  if not list then return nil end
  local bx, by, best
  for i = 1, #list do
    local x, y = CF.Unpack(list[i])
    local d = CF.Distance(map, px, py, x, y)
    if not best or d < best then bx, by, best = x, y, d end
  end
  return bx, by, best
end

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
      else
        table.insert(parts, string.format(CF.L["%s: none in this zone"], label))
      end
    end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, "  ")
end
