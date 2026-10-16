-- Records every node the player gathers (mining, herbalism, skinning) so it can
-- be marked on the maps and used by the route planner.
--
-- A gathering cast (SPELLCAST_START) remembers where the player stands and what
-- the mouse is over; the loot window that follows tells us what came out of it.

local CF = CraftingForever

local GATHER_SPELLS = {
  ["Mining"] = "mining",
  ["Herb Gathering"] = "herbalism",
  ["Skinning"] = "skinning",
}

local MERGE_YARDS = { mining = 15, herbalism = 15, skinning = 30 }

CF.itemNameToMat = {}
for key, m in pairs(CF.materials) do
  CF.itemNameToMat[m.name] = key
end

local pending

local function tooltipTitle()
  if GameTooltip:IsVisible() and GameTooltipTextLeft1 then
    return GameTooltipTextLeft1:GetText()
  end
end

CF.RegisterEvent("SPELLCAST_START", function(spell)
  local prof = GATHER_SPELLS[spell]
  if not prof then return end
  local area, x, y = CF.PlayerPosition()
  if not area then
    pending = nil
    return
  end
  pending = {
    prof = prof, area = area, x = x, y = y, time = GetTime(),
    title = tooltipTitle() or UnitName("mouseover"),
  }
end)

local function cancel() pending = nil end
CF.RegisterEvent("SPELLCAST_FAILED", cancel)
CF.RegisterEvent("SPELLCAST_INTERRUPTED", cancel)

CF.RegisterEvent("LOOT_OPENED", function()
  local p = pending
  pending = nil
  if not p or GetTime() - p.time > 15 then return end

  local key = p.title and CF.nodeNameToMat[string.lower(p.title)]
  for slot = 1, GetNumLootItems() do
    local tex, name = GetLootSlotInfo(slot)
    local mat = name and CF.itemNameToMat[name]
    if mat then
      if tex then CF.db.icons[CF.materials[mat].item] = tex end
      if not key and CF.materials[mat].prof == p.prof then key = mat end
    end
  end
  if key and CF.materials[key].prof == p.prof then
    CF.RecordNode(p.area, key, p.x, p.y)
  end
end)

function CF.RecordNode(area, key, x, y)
  local nodes = CF.db.nodes
  if not nodes[area] then nodes[area] = {} end
  if not nodes[area][key] then nodes[area][key] = {} end
  local list = nodes[area][key]
  local merge = MERGE_YARDS[CF.materials[key].prof] or 15

  for i = 1, table.getn(list) do
    local n = list[i]
    if CF.Distance(area, x, y, n[1], n[2]) <= merge then
      n[3] = (n[3] or 1) + 1
      n[4] = time()
      CF.Fire("NODES_UPDATED", area, key)
      return
    end
  end
  table.insert(list, { math.floor(x * 10 + 0.5) / 10, math.floor(y * 10 + 0.5) / 10, 1, time() })
  CF.Fire("NODES_UPDATED", area, key)
end

-- Iterates every learned node of an area: fn(key, node), node = { x, y, count, time }
function CF.ForEachLearned(area, fn)
  local mats = CF.db.nodes[area]
  if not mats then return end
  for key, list in pairs(mats) do
    if CF.materials[key] then
      for i = 1, table.getn(list) do fn(key, list[i]) end
    end
  end
end
