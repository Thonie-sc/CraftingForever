-- Route planner: finds the best farming loops for a set of selected materials.
--
-- Every selected material contributes spawn points (bundled database + nodes the
-- player gathered). Points from all materials are merged per zone, so a zone where
-- copper and tin share spawn points yields one loop that gathers both. Zones are
-- ranked by gatherable nodes per 1000 yards of loop, scaled by how many of the
-- selected materials the zone offers.

local CF = CraftingForever

local MERGE_YARDS = 10      -- node spawns closer than this are the same spawn
local MOB_MERGE_YARDS = 30  -- mobs wander, so nearby creature spawns are one stop
local ISOLATED_YARDS = 350  -- points without a neighbour this close are skipped
local CANDIDATES = 10       -- zones that get a full tour computed
local RUN_SPEED = 7         -- yards/second on foot
local MOUNT_SPEED = 11.2    -- 60% mount

CF.RUN_SPEED, CF.MOUNT_SPEED = RUN_SPEED, MOUNT_SPEED

local function zoneAllowed(area, opts)
  local z = CraftingForever_Zones[area]
  if not z then return false end
  if opts.hideEnemy and z[6] ~= "C" and z[6] ~= opts.faction then return false end
  if opts.hideHigh and z[4] > opts.level + 5 then return false end
  if opts.zones and not opts.zones[area] then return false end
  return true
end

-- zone point collector -------------------------------------------------------

local function newCollector()
  return { zones = {} }
end

local function addPoint(col, area, x, y, w, mat, mob)
  local zone = col.zones[area]
  if not zone then
    zone = { cells = {}, points = {} }
    col.zones[area] = zone
  end
  local z = CraftingForever_Zones[area]
  local size = mob and MOB_MERGE_YARDS or MERGE_YARDS
  local cx = math.floor(x * z[7] / 100 / size)
  local cy = math.floor(y * z[8] / 100 / size)
  -- separate cell namespaces for node and mob grids
  local key = (mob and -1 or 1) * (cx * 100000 + cy + 1)
  local p = zone.cells[key]
  if not p then
    p = { x = x, y = y, w = 0, mats = {} }
    zone.cells[key] = p
    table.insert(zone.points, p)
  end
  -- a spawn point yields one node, so weights do not add up across materials
  if w > p.w then p.w = w end
  p.mats[mat] = true
  if mob then p.mob = mob end
end

local function collectGather(col, key, opts)
  local m = CF.materials[key]
  for area, list in pairs(m.zones) do
    if zoneAllowed(area, opts) then
      for i = 1, table.getn(list) do
        local x, y = CF.Unpack(list[i])
        addPoint(col, area, x, y, 1, key)
      end
    end
  end
end

local function collectLearned(col, key, opts)
  for area, mats in pairs(CF.db.nodes) do
    local list = mats[key]
    if list and zoneAllowed(area, opts) then
      for i = 1, table.getn(list) do
        addPoint(col, area, list[i][1], list[i][2], 1, key)
      end
    end
  end
end

local function collectSkinning(col, keys, opts)
  local skill = CF.SkillRank("skinning")
  for area, mobs in pairs(CraftingForever_SkinDB.spawns) do
    if zoneAllowed(area, opts) then
      for mobId, pts in pairs(mobs) do
        local mob = CraftingForever_SkinDB.mobs[mobId]
        local ok = true
        if skill and CF.SkinningSkillForLevel(mob[2]) > skill then ok = false end
        if opts.hideHigh and mob[2] > opts.level + 3 then ok = false end
        if ok then
          local w, best = 0, nil
          for i = 1, table.getn(keys) do
            local chance = mob[5][keys[i]]
            if chance then
              w = w + chance / 100
              if not best or chance > mob[5][best] then best = keys[i] end
            end
          end
          if w > 0 then
            for i = 1, table.getn(pts) do
              local x, y = CF.Unpack(pts[i])
              addPoint(col, area, x, y, w, best, mobId)
            end
          end
        end
      end
    end
  end
end

-- drops points without any neighbour within ISOLATED_YARDS (bucketed lookup)
local function pruneIsolated(area, points)
  local n = table.getn(points)
  if n <= 5 then return points end
  local z = CraftingForever_Zones[area]
  local buckets = {}
  local function cell(p)
    return math.floor(p.x * z[7] / 100 / ISOLATED_YARDS), math.floor(p.y * z[8] / 100 / ISOLATED_YARDS)
  end
  for i = 1, n do
    local cx, cy = cell(points[i])
    local k = cx * 1000 + cy
    if not buckets[k] then buckets[k] = {} end
    table.insert(buckets[k], points[i])
  end
  local kept = {}
  for i = 1, n do
    local p = points[i]
    local cx, cy = cell(p)
    local found = false
    for dx = -1, 1 do
      for dy = -1, 1 do
        local b = buckets[(cx + dx) * 1000 + cy + dy]
        if b then
          for j = 1, table.getn(b) do
            local q = b[j]
            if q ~= p and CF.Distance(area, p.x, p.y, q.x, q.y) <= ISOLATED_YARDS then
              found = true
              break
            end
          end
        end
        if found then break end
      end
      if found then break end
    end
    if found then table.insert(kept, p) end
  end
  return kept
end

-- tour solving ----------------------------------------------------------------

-- Returns an ordering (closed loop) of the points and its length in yards.
function CF.SolveTour(area, points, improve)
  local n = table.getn(points)
  local z = CraftingForever_Zones[area]
  local X, Y = {}, {}
  for i = 1, n do
    X[i] = points[i].x * z[7] / 100
    Y[i] = points[i].y * z[8] / 100
  end
  local function d(a, b)
    local dx, dy = X[a] - X[b], Y[a] - Y[b]
    return math.sqrt(dx * dx + dy * dy)
  end
  if n == 0 then return {}, 0 end

  -- nearest neighbour, starting from the westernmost point
  local start = 1
  for i = 2, n do if X[i] < X[start] then start = i end end
  local order, used = { start }, { [start] = true }
  local cur = start
  for _ = 2, n do
    local best, bestD = nil, nil
    for j = 1, n do
      if not used[j] then
        local dj = d(cur, j)
        if not bestD or dj < bestD then best, bestD = j, dj end
      end
    end
    used[best] = true
    table.insert(order, best)
    cur = best
  end

  -- 2-opt improvement
  if improve and n > 3 then
    local passes = 0
    local improved = true
    while improved and passes < 6 do
      improved = false
      passes = passes + 1
      for i = 1, n - 2 do
        for j = i + 2, n do
          if not (i == 1 and j == n) then
            local a, b, c = order[i], order[i + 1], order[j]
            local e = order[j + 1] or order[1]
            if d(a, c) + d(b, e) < d(a, b) + d(c, e) - 0.01 then
              local lo, hi = i + 1, j
              while lo < hi do
                order[lo], order[hi] = order[hi], order[lo]
                lo, hi = lo + 1, hi - 1
              end
              improved = true
            end
          end
        end
      end
    end
  end

  local len = 0
  for i = 1, n do
    len = len + d(order[i], order[i + 1] or order[1])
  end
  return order, len
end

-- public API ------------------------------------------------------------------

function CF.RouteOptions(zones)
  return {
    level = UnitLevel("player"),
    faction = CF.PlayerFaction(),
    hideHigh = CF.settings.hideHighZones,
    hideEnemy = CF.settings.hideEnemyZones,
    zones = zones,
  }
end

-- keys: list of material keys. zones: optional set {[area]=true} to restrict to.
-- Returns a list of route results, best first.
function CF.FindRoutes(keys, zones)
  local opts = CF.RouteOptions(zones)
  local col = newCollector()
  local skinKeys = {}
  for i = 1, table.getn(keys) do
    local m = CF.materials[keys[i]]
    if m then
      if m.prof == "skinning" then
        table.insert(skinKeys, keys[i])
      else
        collectGather(col, keys[i], opts)
        collectLearned(col, keys[i], opts)
      end
    end
  end
  if table.getn(skinKeys) > 0 then collectSkinning(col, skinKeys, opts) end

  local nkeys = table.getn(keys)
  local candidates = {}
  for area, zone in pairs(col.zones) do
    local points = pruneIsolated(area, zone.points)
    if table.getn(points) >= 3 then
      local weight, counts = 0, {}
      for i = 1, table.getn(points) do
        weight = weight + points[i].w
        for mat in pairs(points[i].mats) do counts[mat] = (counts[mat] or 0) + 1 end
      end
      local coverage = CF.Count(counts) / nkeys
      table.insert(candidates, {
        area = area, points = points, weight = weight, counts = counts,
        coverage = coverage, pre = weight * coverage,
      })
    end
  end
  table.sort(candidates, function(a, b) return a.pre > b.pre end)

  local results = {}
  for i = 1, math.min(CANDIDATES, table.getn(candidates)) do
    local r = candidates[i]
    r.order, r.length = CF.SolveTour(r.area, r.points, false)
    r.density = r.weight / math.max(r.length, 1) * 1000
    -- small loops with only a few nodes respawn too slowly to farm
    r.score = r.density * r.coverage * math.min(1, r.weight / 30)
    r.keys = keys
    table.insert(results, r)
  end
  table.sort(results, function(a, b) return a.score > b.score end)
  return results
end

-- Activate a route result (or nil to clear). The tour is optimised once here.
function CF.SetActiveRoute(r)
  if r then
    r.order, r.length = CF.SolveTour(r.area, r.points, true)
    r.density = r.weight / math.max(r.length, 1) * 1000
    CF.cdb.activeRoute = { area = r.area, keys = r.keys }
  else
    CF.cdb.activeRoute = nil
  end
  CF.activeRoute = r
  CF.Fire("ROUTE_CHANGED")
end

-- restore the route of the last session
CF.On("INIT", function()
  local saved = CF.cdb.activeRoute
  if not saved or not saved.keys then return end
  CF.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if CF.activeRoute or not CF.cdb.activeRoute then return end
    local results = CF.FindRoutes(saved.keys, { [saved.area] = true })
    if results[1] then CF.SetActiveRoute(results[1]) end
  end)
end)

function CF.FormatTime(seconds)
  local m = math.floor(seconds / 60)
  local s = math.floor(seconds - m * 60)
  return string.format("%d:%02d", m, s)
end
