-- Material registry built from the generated gathering and skinning databases.

local CF = CraftingForever

CF.PROFESSIONS = { "mining", "herbalism", "skinning", "fishing" }
CF.PROF_ICON = {
  mining = "Interface\\Icons\\Trade_Mining",
  herbalism = "Interface\\Icons\\INV_Misc_Flower_02",
  skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
  fishing = "Interface\\Icons\\Trade_Fishing",
}

CF.materials = {}        -- [key] = { key, prof, item, name (localized), nameEN, skill, nodes }
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
  if m.item > 0 then CF.itemToMat[m.item] = key end
  if not CF.materialOrder[m.prof] then CF.materialOrder[m.prof] = {} end
  table.insert(CF.materialOrder[m.prof], key)
end

local objectNames = CF.LDB.objects or {}
for key, d in pairs(CraftingForever_GatherDB) do
  local name
  if d.item > 0 then
    name = CF.ItemNameByID(d.item, d.name)
  else
    name = objectNames[d.name] or d.name  -- itemless fishing pools: the pool's name
  end
  add(key, { prof = d.prof, item = d.item, name = name, nameEN = d.name, skill = d.skill,
             nodes = d.nodes, zones = d.zones })
  for i = 1, #d.nodes do
    CF.nodeNameToMat[string.lower(d.nodes[i])] = key
    if objectNames[d.nodes[i]] then
      CF.nodeNameToMat[string.lower(objectNames[d.nodes[i]])] = key
    end
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
      add(key, { prof = "skinning", item = d.item, name = CF.ItemNameByID(d.item, d.name), nameEN = d.name,
                 skill = minSkill[key] })
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

function CF.MaterialIcon(key)
  local m = CF.materials[key]
  if not m then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  if m.item == 0 then return CF.PROF_ICON[m.prof] end
  return C_Item.GetItemIconByID(m.item) or CF.PROF_ICON[m.prof]
end

-- Number of an item in the player's bags.
function CF.ItemCount(itemID)
  if not itemID then return 0 end
  return C_Item.GetItemCount(itemID) or 0
end
