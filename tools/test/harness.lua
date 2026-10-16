-- Offline test harness: runs the addon under a stock Lua 5.0 interpreter with a
-- minimal mock of the 1.12 API, then exercises routes, gathering and the UI.
--
--   lua5.0 tools/test/harness.lua        (from the addon folder)

-------------------------------------------------------------------------------
-- mock API
-------------------------------------------------------------------------------

local registry = {}
local frames = {}
local now = 1000

local function newObject(name)
  local o = { _scripts = {}, _shown = true, _w = 100, _h = 100, _events = {}, _level = 1 }
  local methods = {
    SetScript = function(self, k, f) self._scripts[k] = f end,
    GetScript = function(self, k) return self._scripts[k] end,
    RegisterEvent = function(self, e) self._events[e] = true end,
    Show = function(self) self._shown = true if self._scripts.OnShow then this = self self._scripts.OnShow() end end,
    Hide = function(self) self._shown = false end,
    IsVisible = function(self) return self._shown end,
    IsShown = function(self) return self._shown end,
    SetWidth = function(self, w) self._w = w end,
    SetHeight = function(self, h) self._h = h end,
    GetWidth = function(self) return self._w end,
    GetHeight = function(self) return self._h end,
    GetFrameLevel = function(self) return self._level end,
    SetFrameLevel = function(self, l) self._level = l end,
    GetChecked = function(self) return self._checked end,
    SetChecked = function(self, v) self._checked = v end,
    SetText = function(self, t) self._text = t end,
    GetText = function(self) return self._text end,
    GetParent = function(self) return self._parent end,
    GetZoom = function() return 0 end,
    GetCenter = function() return 500, 500 end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function(self) return newObject() end,
    CreateFontString = function(self) return newObject() end,
  }
  setmetatable(o, { __index = function(t, k)
    if methods[k] then return methods[k] end
    return function() end
  end })
  if name then registry[name] = o end
  return o
end

function CreateFrame(kind, name, parent, template)
  local f = newObject(name)
  f._parent = parent
  table.insert(frames, f)
  if name and template == "UICheckButtonTemplate" then newObject(name .. "Text") end
  if name and template == "FauxScrollFrameTemplate" then newObject(name .. "ScrollBar") end
  return f
end

function getglobal(n) return registry[n] or getfenv(0)[n] end

UIParent = newObject("UIParent")
Minimap = newObject("Minimap")
Minimap._w = 140
WorldMapFrame = newObject("WorldMapFrame")
WorldMapFrame._shown = false
WorldMapButton = newObject("WorldMapButton")
WorldMapButton._w, WorldMapButton._h = 1002, 668
GameTooltip = newObject("GameTooltip")
GameTooltip._shown = false
GameTooltipTextLeft1 = newObject("GameTooltipTextLeft1")
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print("[chat] " .. string.gsub(m, "|c%x%x%x%x%x%x%x%x", "")) end }
UISpecialFrames = {}
SlashCmdList = {}

-- player state
local player = { x = 0.42, y = 0.65, map = "Elwynn", level = 12 }
local skills = {
  { "Professions", true, true },
  { "Mining", false, false, 72, 0, 0, 150 },
  { "Skinning", false, false, 40, 0, 0, 75 },
  { "Alchemy", false, false, 112, 0, 0, 150 },
}

function UnitLevel() return player.level end
function UnitFactionGroup() return "Alliance" end
function UnitName() return nil end
function GetTime() return now end
function GetMapInfo() return player.map end
function SetMapToCurrentZone() end
function GetPlayerMapPosition() return player.x, player.y end
function GetCurrentMapContinent() return 2 end
function GetCurrentMapZone() return 1 end
function GetMapZones() return "Elwynn Forest" end
function SetMapZoom() end
function ToggleWorldMap() end
function GetCVar(k) if k == "minimapZoom" then return "0" end return "2" end
function GetItemInfo() return nil end
function GetContainerNumSlots() return 0 end
function GetContainerItemLink() return nil end
function GetContainerItemInfo() return nil end
function GetNumSkillLines() return table.getn(skills) end
function GetSkillLineInfo(i) return unpack(skills[i]) end
function ExpandSkillHeader() end
function CollapseSkillHeader() end
function GetNumTradeSkills() return 0 end
function GetNumCrafts() return 0 end
function GetCursorPosition() return 0, 0 end
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset() return 0 end
function FauxScrollFrame_OnVerticalScroll() end
date = os.date
time = os.time

local loot = {}
function GetNumLootItems() return table.getn(loot) end
function GetLootSlotInfo(i) return "Interface\\Icons\\Test", loot[i], 1 end

local function fire(ev, a1, a2, a3)
  for _, f in ipairs(frames) do
    if f._events[ev] and f._scripts.OnEvent then
      event, arg1, arg2, arg3 = ev, a1, a2, a3
      this = f
      f._scripts.OnEvent()
    end
  end
end

-------------------------------------------------------------------------------
-- load the addon in .toc order
-------------------------------------------------------------------------------

local function check(cond, msg)
  if not cond then error("FAILED: " .. msg, 2) end
  print("ok   " .. msg)
end

for line in io.lines("CraftingForever.toc") do
  if not string.find(line, "^##") and string.find(line, "%S") then
    local path = string.gsub(line, "\\", "/")
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    chunk()
  end
end
check(true, "all files load under Lua 5.0")

fire("ADDON_LOADED", "CraftingForever")
fire("PLAYER_ENTERING_WORLD")
local CF = CraftingForever

check(CF.profs.mining and CF.profs.mining.rank == 72, "professions detected (mining 72)")
check(CF.materials.copper.skill == 1 and CF.materials.tin.skill == 65, "material skills")
check(CF.materials.lightleather ~= nil, "skinning materials registered")

-------------------------------------------------------------------------------
-- routes
-------------------------------------------------------------------------------

local function show(results, label)
  print("  " .. label)
  for i = 1, math.min(5, table.getn(results)) do
    local r = results[i]
    local counts = {}
    for k, v in pairs(r.counts) do table.insert(counts, k .. "=" .. v) end
    print(string.format("    %d. %-22s stops %3d  len %6d yd  %.1f/1k  score %.2f  [%s]", i,
      CF.ZoneName(r.area), table.getn(r.points), r.length, r.density, r.score, table.concat(counts, " ")))
  end
end

local t0 = os.clock()
local res = CF.FindRoutes({ "copper" })
show(res, string.format("copper (level 12 Alliance) - %.3fs", os.clock() - t0))
check(table.getn(res) > 0, "copper routes found")
for i = 1, table.getn(res) do
  local z = CraftingForever_Zones[res[i].area]
  check(z[6] ~= "H", "no horde territory in alliance results: " .. z[1])
end

t0 = os.clock()
res = CF.FindRoutes({ "copper", "tin" })
show(res, string.format("copper + tin - %.3fs", os.clock() - t0))
check(res[1].counts.copper and res[1].counts.tin, "best combined route has both copper and tin")

CF.settings.hideHighZones = false
t0 = os.clock()
res = CF.FindRoutes({ "mithril", "truesilver" })
show(res, string.format("mithril + truesilver (no level filter) - %.3fs", os.clock() - t0))
check(table.getn(res) > 0, "mithril routes")

t0 = os.clock()
res = CF.FindRoutes({ "peacebloom", "silverleaf", "earthroot" })
show(res, string.format("starter herbs - %.3fs", os.clock() - t0))

CF.settings.hideHighZones = true
t0 = os.clock()
res = CF.FindRoutes({ "lightleather" })
show(res, string.format("light leather (skinning 40) - %.3fs", os.clock() - t0))
check(table.getn(res) > 0, "skinning routes")

t0 = os.clock()
local before = res[1].length
CF.SetActiveRoute(res[1])
print(string.format("  2-opt: %d -> %d yd in %.3fs", before, CF.activeRoute.length, os.clock() - t0))
check(CF.activeRoute.length <= before + 0.5, "2-opt does not lengthen the tour")
local seen, n = {}, table.getn(CF.activeRoute.order)
for i = 1, n do seen[CF.activeRoute.order[i]] = true end
check(CF.Count(seen) == table.getn(CF.activeRoute.points), "tour visits every stop once")

-------------------------------------------------------------------------------
-- gathering
-------------------------------------------------------------------------------

GameTooltip._shown = true
GameTooltipTextLeft1._text = "Copper Vein"
fire("SPELLCAST_START", "Mining", 5000)
loot = { "Copper Ore", "Rough Stone" }
now = now + 5
fire("LOOT_OPENED")
check(CF.db.nodes[12] and CF.db.nodes[12].copper and table.getn(CF.db.nodes[12].copper) == 1, "copper vein recorded in Elwynn")

-- same vein again merges
fire("SPELLCAST_START", "Mining", 5000)
now = now + 5
fire("LOOT_OPENED")
check(table.getn(CF.db.nodes[12].copper) == 1 and CF.db.nodes[12].copper[1][3] == 2, "repeat gather merges into one node")

-- unknown tooltip falls back to the loot
GameTooltip._shown = false
player.x = 0.50
fire("SPELLCAST_START", "Herb Gathering", 5000)
loot = { "Silverleaf" }
now = now + 5
fire("LOOT_OPENED")
check(CF.db.nodes[12].silverleaf and table.getn(CF.db.nodes[12].silverleaf) == 1, "herb recorded from loot window")

-- interrupted cast records nothing
fire("SPELLCAST_START", "Mining", 5000)
fire("SPELLCAST_INTERRUPTED")
loot = { "Tin Ore" }
fire("LOOT_OPENED")
check(not CF.db.nodes[12].tin, "interrupted cast ignored")

-- skinning from loot
player.x = 0.30
fire("SPELLCAST_START", "Skinning", 2000)
loot = { "Light Leather", "Ruined Leather Scraps" }
now = now + 3
fire("LOOT_OPENED")
check(CF.db.nodes[12].lightleather and table.getn(CF.db.nodes[12].lightleather) == 1, "skinned mob recorded")

-- learned nodes feed the planner
res = CF.FindRoutes({ "copper" }, { [12] = true })
check(res[1] and res[1].area == 12, "restricted search returns Elwynn only")

-------------------------------------------------------------------------------
-- map layers and UI
-------------------------------------------------------------------------------

WorldMapFrame._shown = true
CF.UpdateWorldMap()
WorldMapFrame._shown = false
CF.UpdateMinimap()
check(true, "world map and minimap layers draw")

CF.ShowMainFrame("routes")
CF.cdb.selected.copper = true
CF.ShowMainFrame("guide")
CF.UpdateGuide()
local step = CF.GuideStep("mining", 72)
check(step and step.from == 65, "mining guide step for 72 is the tin step")
CF.FindGuideRoute(step)
check(CF.activeRoute and CF.activeRoute.counts.tin, "guide 'Find route' activates a tin route")
local astep = CF.GuideStep("alchemy", 112)
check(astep.craft == "Healing Potion", "alchemy step for 112")
CF.ToggleTracker()
CF.ToggleTracker()
SlashCmdList["CRAFTINGFOREVER"]("help")
check(true, "UI builds and updates")

print("\nall tests passed")
