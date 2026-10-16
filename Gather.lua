-- Records every node the player gathers (mining, herbalism, skinning, fishing)
-- so it can be marked on the maps and used by the route planner.
--
-- A gathering cast (UNIT_SPELLCAST_START, or CHANNEL_START for fishing)
-- remembers where the player stands; the loot window that follows tells us
-- which material came out of it. Spells and items are matched by ID, so this
-- works in every client language.

local CF = CraftingForever

-- gathering spell IDs (all ranks) -> profession
local GATHER_SPELL_IDS = {
  [2575] = "mining", [2576] = "mining", [3564] = "mining", [10248] = "mining",
  [2366] = "herbalism", [2368] = "herbalism", [3570] = "herbalism", [11993] = "herbalism",
  [8613] = "skinning", [8617] = "skinning", [8618] = "skinning", [10768] = "skinning",
  [7620] = "fishing", [7731] = "fishing", [7732] = "fishing", [18248] = "fishing",
}

-- the same spells by (localized) name, in case the client uses other spell IDs
local gatherSpellNames = {}
local function buildSpellNames()
  for id, prof in pairs(GATHER_SPELL_IDS) do
    local name = C_Spell.GetSpellName(id)
    if name then gatherSpellNames[name] = prof end
  end
  for _, key in ipairs({ "mining", "skinning", "fishing" }) do
    gatherSpellNames[CF.ProfName(key)] = key
  end
end
buildSpellNames()
CF.RegisterEvent("PLAYER_LOGIN", buildSpellNames)

local MERGE_YARDS = { mining = 15, herbalism = 15, skinning = 30, fishing = 25 }

local pending

local function gatherProf(spellID)
  local prof = GATHER_SPELL_IDS[spellID]
  if prof then return prof end
  local name = spellID and C_Spell.GetSpellName(spellID)
  return name and gatherSpellNames[name]
end

local function startGather(unit, castGUID, spellID)
  if unit ~= "player" then return end
  local prof = gatherProf(spellID)
  if not prof then return end
  local map, x, y = CF.PlayerPosition()
  if not map then
    pending = nil
    return
  end
  pending = { prof = prof, map = map, x = x, y = y, time = GetTime(), guid = castGUID }
end

CF.RegisterEvent("UNIT_SPELLCAST_START", startGather)
CF.RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", startGather)

local function cancel(unit, castGUID)
  if unit == "player" and pending and pending.guid == castGUID then pending = nil end
end
CF.RegisterEvent("UNIT_SPELLCAST_FAILED", cancel)
CF.RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", cancel)

local function lootMaterial(slot)
  local link = GetLootSlotLink and GetLootSlotLink(slot)
  local id = link and tonumber(string.match(link, "item:(%d+)"))
  return id and CF.itemToMat[id]
end

CF.RegisterEvent("LOOT_OPENED", function()
  local p = pending
  pending = nil
  -- fishing waits for a bite, so it gets the full channel time
  local timeout = p and p.prof == "fishing" and 35 or 15
  if not p or GetTime() - p.time > timeout then return end

  for slot = 1, GetNumLootItems() do
    local key = lootMaterial(slot)
    if key and CF.materials[key].prof == p.prof then
      CF.RecordNode(p.map, key, p.x, p.y)
      return
    end
  end
end)

function CF.RecordNode(map, key, x, y)
  local nodes = CF.db.nodes
  if not nodes[map] then nodes[map] = {} end
  if not nodes[map][key] then nodes[map][key] = {} end
  local list = nodes[map][key]
  local merge = MERGE_YARDS[CF.materials[key].prof] or 15

  for i = 1, #list do
    local n = list[i]
    if CF.Distance(map, x, y, n[1], n[2]) <= merge then
      n[3] = (n[3] or 1) + 1
      n[4] = time()
      CF.Fire("NODES_UPDATED", map, key)
      return
    end
  end
  table.insert(list, { math.floor(x * 10 + 0.5) / 10, math.floor(y * 10 + 0.5) / 10, 1, time() })
  CF.Fire("NODES_UPDATED", map, key)
end

-- Iterates every learned node of a map: fn(key, node), node = { x, y, count, time }
function CF.ForEachLearned(map, fn)
  local mats = CF.db.nodes[map]
  if not mats then return end
  for key, list in pairs(mats) do
    if CF.materials[key] then
      for i = 1, #list do fn(key, list[i]) end
    end
  end
end
