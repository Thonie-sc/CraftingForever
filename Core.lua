-- CraftingForever core: namespace, events, saved variables, helpers.
-- Written for the WoW: Forever client (modern 12.0-based engine, Lua 5.1,
-- Classic Era content). Zones are identified by uiMapID everywhere.

CraftingForever = CraftingForever or {}
local CF = CraftingForever

CF.name = ...
CF.version = "0.3.0"

local HBD = LibStub("HereBeDragons-2.0")
CF.HBD = HBD

local DB_VERSION = 2  -- 1 = the 1.12 build that keyed nodes by areaID

local DEFAULTS = {
  showLearned = true,     -- gathered nodes on the world map
  showRoute = true,       -- active route on the world map
  minimapPins = true,     -- gathered + route nodes on the minimap
  hideHighZones = true,   -- route finder skips zones far above your level
  hideEnemyZones = true,  -- route finder skips the other faction's territory
  pinSize = 14,
  minimapPinSize = 12,
  minimapButtonAngle = 200,
}

-------------------------------------------------------------------------------
-- printing / misc helpers
-------------------------------------------------------------------------------

function CF.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CraftingForever|r: " .. tostring(msg))
end

-- Packed spawn coordinates: floor(x*10)*10000 + floor(y*10), x/y in zone percent.
function CF.Unpack(p)
  local x = math.floor(p / 10000)
  return x / 10, (p - x * 10000) / 10
end

-- Zone width and height in yards. Zones without bundled data (e.g. new Forever
-- zones that only have nodes you gathered yourself) are measured by HereBeDragons.
function CF.ZoneSize(map)
  local z = CraftingForever_Zones[map]
  if z then return z[7], z[8] end
  local w, h = HBD:GetZoneSize(map)
  if w and w > 0 then return w, h end
  return 1000, 1000
end

-- Zone info: { name, areaID, continent, minLevel, maxLevel, faction, width, height }
function CF.ZoneInfo(map)
  local z = CraftingForever_Zones[map]
  if z then return z end
  local w, h = CF.ZoneSize(map)
  return { CF.ZoneName(map), 0, 0, 1, 60, "C", w, h }
end

-- Distance in yards between two points (zone percent) of the given map.
function CF.Distance(map, x1, y1, x2, y2)
  local w, h = CF.ZoneSize(map)
  local dx = (x1 - x2) * w / 100
  local dy = (y1 - y2) * h / 100
  return math.sqrt(dx * dx + dy * dy)
end

function CF.ZoneName(map)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  if info and info.name then return info.name end
  local loc = CF.LDB and CF.LDB.zones and CF.LDB.zones[map]
  if loc then return loc end
  local z = CraftingForever_Zones[map]
  return z and z[1] or ("Zone " .. tostring(map))
end

function CF.Count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function CF.PlayerFaction()
  local f = UnitFactionGroup("player")
  if f == "Horde" then return "H" end
  return "A"
end

-------------------------------------------------------------------------------
-- events: game events and internal messages
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local gameHandlers = {}
local messageHandlers = {}

function CF.RegisterEvent(ev, fn)
  if not gameHandlers[ev] then
    gameHandlers[ev] = {}
    eventFrame:RegisterEvent(ev)
  end
  table.insert(gameHandlers[ev], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = gameHandlers[event]
  if not list then return end
  for i = 1, #list do
    list[i](...)
  end
end)

-- Internal messages, e.g. "PROFESSIONS_UPDATED", "NODES_UPDATED", "ROUTE_CHANGED".
function CF.On(msg, fn)
  if not messageHandlers[msg] then messageHandlers[msg] = {} end
  table.insert(messageHandlers[msg], fn)
end

function CF.Fire(msg, ...)
  local list = messageHandlers[msg]
  if not list then return end
  for i = 1, #list do
    list[i](...)
  end
end

-------------------------------------------------------------------------------
-- saved variables
-------------------------------------------------------------------------------

CF.RegisterEvent("ADDON_LOADED", function(name)
  if name ~= CF.name then return end

  CraftingForeverDB = CraftingForeverDB or {}
  local db = CraftingForeverDB
  if db.version ~= DB_VERSION then
    db.nodes = {}  -- older data used other zone keys
    db.recipes = {}
    db.version = DB_VERSION
  end
  db.nodes = db.nodes or {}       -- [uiMapID][material] = { {x, y, count, time}, ... }
  db.recipes = db.recipes or {}   -- [recipe name] = { {reagent, count, itemID}, ... } from trade skill windows
  db.settings = db.settings or {}
  for k, v in pairs(DEFAULTS) do
    if db.settings[k] == nil then db.settings[k] = v end
  end

  CraftingForeverCharDB = CraftingForeverCharDB or {}
  local cdb = CraftingForeverCharDB
  cdb.selected = cdb.selected or {}   -- [material] = true
  cdb.recipeColor = cdb.recipeColor or {}
  if cdb.trackerShown == nil then cdb.trackerShown = true end

  CF.db = db
  CF.cdb = cdb
  CF.settings = db.settings
  CF.Fire("INIT")
end)

-------------------------------------------------------------------------------
-- slash commands
-------------------------------------------------------------------------------

SLASH_CRAFTINGFOREVER1 = "/cf"
SLASH_CRAFTINGFOREVER2 = "/craftingforever"
SlashCmdList["CRAFTINGFOREVER"] = function(msg)
  local cmd = string.lower(msg or "")
  if cmd == "" or cmd == "show" then
    CF.ToggleMainFrame()
  elseif cmd == "routes" then
    CF.ShowMainFrame("routes")
  elseif cmd == "guide" then
    CF.ShowMainFrame("guide")
  elseif cmd == "tracker" then
    CF.ToggleTracker()
  elseif cmd == "clear" then
    CF.SetActiveRoute(nil)
    CF.Print(CF.L["Route cleared."])
  elseif cmd == "resetnodes" then
    CF.db.nodes = {}
    CF.Fire("NODES_UPDATED")
    CF.Print(CF.L["All gathered nodes have been removed."])
  else
    CF.Print(CF.L["/cf - toggle window, /cf routes, /cf guide, /cf tracker, /cf clear (route), /cf resetnodes"])
  end
end
