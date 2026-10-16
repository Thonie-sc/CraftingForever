-- Detects the character's professions and skill levels, and caches recipe
-- reagents/difficulty from the trade skill windows for the leveling guides.

local CF = CraftingForever

-- english skill line name -> guide key
local SKILL_KEYS = {
  ["Mining"] = "mining",
  ["Herbalism"] = "herbalism",
  ["Skinning"] = "skinning",
  ["Alchemy"] = "alchemy",
  ["Blacksmithing"] = "blacksmithing",
  ["Leatherworking"] = "leatherworking",
  ["Tailoring"] = "tailoring",
  ["Engineering"] = "engineering",
  ["Enchanting"] = "enchanting",
  ["First Aid"] = "firstaid",
  ["Cooking"] = "cooking",
  ["Fishing"] = "fishing",
}

CF.profs = {}  -- [key] = { rank = n, max = n, name = "Mining" }

local scanning = false

function CF.ScanProfessions()
  if scanning then return end
  scanning = true

  -- expand collapsed headers so every skill is visible, then restore them
  local collapsed = {}
  for i = GetNumSkillLines(), 1, -1 do
    local name, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and not isExpanded then
      collapsed[name] = true
      ExpandSkillHeader(i)
    end
  end

  local found = {}
  for i = 1, GetNumSkillLines() do
    local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
    local key = name and SKILL_KEYS[name]
    if key and not isHeader then
      found[key] = { rank = rank, max = maxRank, name = name }
    end
  end

  for i = GetNumSkillLines(), 1, -1 do
    local name, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and isExpanded and collapsed[name] then
      CollapseSkillHeader(i)
    end
  end
  scanning = false

  local changed = false
  for k, v in pairs(found) do
    local old = CF.profs[k]
    if not old or old.rank ~= v.rank or old.max ~= v.max then changed = true end
  end
  for k in pairs(CF.profs) do
    if not found[k] then changed = true end
  end
  CF.profs = found
  if changed then CF.Fire("PROFESSIONS_UPDATED") end
end

function CF.SkillRank(key)
  local p = CF.profs[key]
  return p and p.rank or nil
end

CF.RegisterEvent("PLAYER_ENTERING_WORLD", CF.ScanProfessions)
CF.RegisterEvent("SKILL_LINES_CHANGED", CF.ScanProfessions)
CF.RegisterEvent("CHAT_MSG_SKILL", CF.ScanProfessions)

-------------------------------------------------------------------------------
-- trade skill window scanning (real reagents + current recipe color)
-------------------------------------------------------------------------------

local function scanTradeSkills()
  local cache, colors = CF.db.recipes, CF.cdb.recipeColor
  for i = 1, GetNumTradeSkills() do
    local name, kind = GetTradeSkillInfo(i)
    if name and kind ~= "header" then
      colors[name] = kind
      local reagents = {}
      for j = 1, GetTradeSkillNumReagents(i) do
        local rname, _, count = GetTradeSkillReagentInfo(i, j)
        if rname then table.insert(reagents, { rname, count }) end
      end
      if table.getn(reagents) > 0 then cache[name] = reagents end
    end
  end
  CF.Fire("RECIPES_UPDATED")
end

-- Enchanting uses the separate "Craft" API in 1.12.
local function scanCrafts()
  local cache, colors = CF.db.recipes, CF.cdb.recipeColor
  for i = 1, GetNumCrafts() do
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then
      colors[name] = kind
      local reagents = {}
      for j = 1, GetCraftNumReagents(i) do
        local rname, _, count = GetCraftReagentInfo(i, j)
        if rname then table.insert(reagents, { rname, count }) end
      end
      if table.getn(reagents) > 0 then cache[name] = reagents end
    end
  end
  CF.Fire("RECIPES_UPDATED")
end

CF.RegisterEvent("TRADE_SKILL_SHOW", scanTradeSkills)
CF.RegisterEvent("TRADE_SKILL_UPDATE", scanTradeSkills)
CF.RegisterEvent("CRAFT_SHOW", scanCrafts)
CF.RegisterEvent("CRAFT_UPDATE", scanCrafts)
