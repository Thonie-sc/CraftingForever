-- Detects the character's professions and skill levels, and caches recipe
-- reagents/difficulty from the trade skill window for the leveling guides.
--
-- WoW: Forever runs the modern engine with Classic Era content, and some legacy
-- globals exist but fail internally there, so every source is optional and
-- called through pcall: the retail profession API, the classic skill list, and
-- C_TradeSkillUI as a last resort.

local CF = CraftingForever

-- skill line IDs (locale independent)
CF.SKILL_LINES = {
  mining = 186, herbalism = 182, skinning = 393, fishing = 356, alchemy = 171,
  blacksmithing = 164, leatherworking = 165, tailoring = 197, engineering = 202,
  enchanting = 333, firstaid = 129, cooking = 185,
}
local LINE_TO_KEY = {}
for key, id in pairs(CF.SKILL_LINES) do LINE_TO_KEY[id] = key end

-- skill line name -> profession key (english plus the client's language)
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
for key, name in pairs(CF.LDB.skills or {}) do
  SKILL_KEYS[name] = key
end

local ENGLISH = {}
for name, key in pairs(SKILL_KEYS) do
  if not string.find(name, "[^%a ]") then ENGLISH[key] = ENGLISH[key] or name end
end
ENGLISH.firstaid = "First Aid"

-- localized profession name for display
function CF.ProfName(key)
  local loc = CF.LDB.skills and CF.LDB.skills[key]
  return loc or ENGLISH[key] or key
end

CF.profs = {}  -- [key] = { rank = n, max = n }

-- retail-style API: GetProfessions() + GetProfessionInfo()
local function fromProfessions(found)
  if not GetProfessions then return false end
  local list = { GetProfessions() }
  local any = false
  for i = 1, 6 do
    local index = list[i]
    if index then
      local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
      local key = (skillLine and LINE_TO_KEY[skillLine]) or (name and SKILL_KEYS[name])
      if key then
        found[key] = { rank = rank, max = maxRank }
        any = true
      end
    end
  end
  return any
end

-- classic skill list: GetNumSkillLines() + GetSkillLineInfo()
local scanning = false
local function fromSkillLines(found)
  if not GetNumSkillLines or not GetSkillLineInfo then return false end
  scanning = true
  -- expand collapsed headers so every skill is visible, then restore them
  local collapsed = {}
  for i = GetNumSkillLines(), 1, -1 do
    local name, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and not isExpanded and ExpandSkillHeader then
      collapsed[name] = true
      ExpandSkillHeader(i)
    end
  end
  local any = false
  for i = 1, GetNumSkillLines() do
    local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
    local key = name and SKILL_KEYS[name]
    if key and not isHeader then
      found[key] = { rank = rank, max = maxRank }
      any = true
    end
  end
  for i = GetNumSkillLines(), 1, -1 do
    local name, isHeader, isExpanded = GetSkillLineInfo(i)
    if isHeader and isExpanded and collapsed[name] and CollapseSkillHeader then
      CollapseSkillHeader(i)
    end
  end
  scanning = false
  return any
end

-- modern trade skill API, per known skill line
local function fromTradeSkillUI(found)
  if not (C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID) then return false end
  local any = false
  for key, line in pairs(CF.SKILL_LINES) do
    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(line)
    if info and info.maxSkillLevel and info.maxSkillLevel > 0 then
      found[key] = { rank = info.skillLevel or 0, max = info.maxSkillLevel }
      any = true
    end
  end
  return any
end

local function try(fn, found)
  local ok, any = pcall(fn, found)
  if not ok then scanning = false end
  return ok and any
end

function CF.ScanProfessions()
  if scanning then return end
  local found = {}
  if not try(fromProfessions, found) and not try(fromSkillLines, found) then
    try(fromTradeSkillUI, found)
  end

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

local function itemIDFromLink(link)
  local id = link and string.match(link, "item:(%d+)")
  return id and tonumber(id)
end

-- classic trade skill API (GetNumTradeSkills & co.)
local function scanLegacyTradeSkills()
  if not GetNumTradeSkills then return false end
  local cache, colors = CF.db.recipes, CF.cdb.recipeColor
  for i = 1, GetNumTradeSkills() do
    local name, kind = GetTradeSkillInfo(i)
    if name and kind ~= "header" and kind ~= "subheader" then
      colors[name] = kind
      local reagents = {}
      for j = 1, GetTradeSkillNumReagents(i) do
        local rname, _, count = GetTradeSkillReagentInfo(i, j)
        local id = GetTradeSkillReagentItemLink and itemIDFromLink(GetTradeSkillReagentItemLink(i, j))
        if rname then table.insert(reagents, { rname, count, id }) end
      end
      if #reagents > 0 then cache[name] = reagents end
    end
  end
  return true
end

-- classic enchanting window (Craft API)
local function scanLegacyCrafts()
  if not GetNumCrafts then return false end
  local cache, colors = CF.db.recipes, CF.cdb.recipeColor
  for i = 1, GetNumCrafts() do
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then
      colors[name] = kind
      local reagents = {}
      for j = 1, GetCraftNumReagents(i) do
        local rname, _, count = GetCraftReagentInfo(i, j)
        local id = GetCraftReagentItemLink and itemIDFromLink(GetCraftReagentItemLink(i, j))
        if rname then table.insert(reagents, { rname, count, id }) end
      end
      if #reagents > 0 then cache[name] = reagents end
    end
  end
  return true
end

local function scan(fn)
  local ok, done = pcall(fn)
  if ok and done then CF.Fire("RECIPES_UPDATED") end
end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE" }) do
  pcall(CF.RegisterEvent, ev, function() scan(scanLegacyTradeSkills) end)
end
for _, ev in ipairs({ "CRAFT_SHOW", "CRAFT_UPDATE" }) do
  pcall(CF.RegisterEvent, ev, function() scan(scanLegacyCrafts) end)
end
