-- Material registry built from the generated gathering and skinning databases.

local CF = CraftingForever

CF.PROFESSIONS = { "mining", "herbalism", "skinning" }
CF.PROF_LABEL = { mining = "Mining", herbalism = "Herbalism", skinning = "Skinning" }
CF.PROF_ICON = {
  mining = "Interface\\Icons\\Trade_Mining",
  herbalism = "Interface\\Icons\\INV_Misc_Flower_02",
  skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
}

CF.materials = {}        -- [key] = { key, prof, item, name, skill, nodes }
CF.materialOrder = {}    -- [prof] = { key, ... } sorted by skill
CF.nodeNameToMat = {}    -- [lowercase node name] = key
CF.itemToMat = {}        -- [itemID] = key

-- Skinning skill needed for a mob of the given level (1.12 formula).
function CF.SkinningSkillForLevel(level)
  if level <= 10 then return 1 end
  if level <= 20 then return (level - 10) * 10 end
  return level * 5
end

local function add(key, m)
  m.key = key
  CF.materials[key] = m
  CF.itemToMat[m.item] = key
  if not CF.materialOrder[m.prof] then CF.materialOrder[m.prof] = {} end
  table.insert(CF.materialOrder[m.prof], key)
end

for key, d in pairs(CraftingForever_GatherDB) do
  add(key, { prof = d.prof, item = d.item, name = d.name, skill = d.skill, nodes = d.nodes, zones = d.zones })
  for i = 1, table.getn(d.nodes) do
    CF.nodeNameToMat[string.lower(d.nodes[i])] = key
  end
end

-- Skinning materials: required skill is the lowest of the mobs that drop it.
do
  local minSkill = {}
  for _, mob in pairs(CraftingForever_SkinDB.mobs) do
    local req = CF.SkinningSkillForLevel(mob[2])
    for mat in pairs(mob[5]) do
      if not minSkill[mat] or req < minSkill[mat] then minSkill[mat] = req end
    end
  end
  for key, d in pairs(CraftingForever_SkinDB.materials) do
    if minSkill[key] then
      add(key, { prof = "skinning", item = d.item, name = d.name, skill = minSkill[key] })
    end
  end
end

for _, list in pairs(CF.materialOrder) do
  table.sort(list, function(a, b)
    local ma, mb = CF.materials[a], CF.materials[b]
    if ma.skill ~= mb.skill then return ma.skill < mb.skill end
    return ma.name < mb.name
  end)
end

-- Item icons: the client only knows textures of items it has cached, so remember
-- every texture we see (loot window, bags) and fall back to the profession icon.
function CF.MaterialIcon(key)
  local m = CF.materials[key]
  if not m then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  local tex = CF.db and CF.db.icons[m.item]
  if tex then return tex end
  local _, _, _, _, _, _, _, _, itemTex = GetItemInfo(m.item)
  if itemTex then
    if CF.db then CF.db.icons[m.item] = itemTex end
    return itemTex
  end
  return CF.PROF_ICON[m.prof]
end

function CF.ScanBagIcons()
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local _, _, id = string.find(link, "item:(%d+)")
        id = tonumber(id)
        if id and CF.itemToMat[id] then
          local tex = GetContainerItemInfo(bag, slot)
          if tex then CF.db.icons[id] = tex end
        end
      end
    end
  end
end

-- Number of an item (by name) in the player's bags.
function CF.CountInBags(itemName)
  local total = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local link = GetContainerItemLink(bag, slot)
      if link and string.find(link, "[" .. itemName .. "]", 1, true) then
        local _, count = GetContainerItemInfo(bag, slot)
        total = total + (count or 1)
      end
    end
  end
  return total
end

CF.RegisterEvent("PLAYER_ENTERING_WORLD", function() CF.ScanBagIcons() end)
