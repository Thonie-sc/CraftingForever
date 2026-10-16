-- Route planner: finds the farming loop with the highest yield per hour for a
-- set of selected materials, without standing around waiting for respawns.
--
-- Yield model
--   Gathering nodes spawn through pools: only a share `a` of a zone's spawn
--   points holds a node at any time, and a gathered node reappears `r` seconds
--   later at a random point of its pool. If the loop (lap time `T`) covers a
--   share `f` of the zone's spawn points, a respawn lands on the loop with
--   probability f and we reach it after T/2 on average; otherwise it sits
--   off-route until someone else gathers it (OTHERS seconds). Every spawn
--   point on the loop then yields a / (r + f*T/2 + (1-f)*OTHERS) nodes per
--   second, so tiny loops that let most respawns escape are not overrated.
--   Creatures respawn in place, so a mob yields 1 / max(T, r).
--   T itself is travel time (loop length / speed) plus time spent gathering, so
--   it is solved iteratively.
--
-- Search
--   For each zone we try the whole zone and circular areas of several sizes
--   around its densest spots, estimate the loop length, keep the best
--   candidate, then compute real loops (nearest neighbour, 2-opt when activated)
--   for the most promising zones and rank them by yield per hour.

local CF = CraftingForever

local MERGE_YARDS = 10      -- node spawns closer than this are the same spawn
local MOB_MERGE_YARDS = 30  -- mobs wander, so nearby creature spawns are one stop
local ISOLATED_YARDS = 350  -- points without a neighbour this close are skipped
local RADII = { 600, 1000, 1600 }
local SEEDS = 4
local CANDIDATES = 8        -- zones that get a real tour computed
local OTHERS = 1200         -- seconds until an off-route node is taken by someone else

CF.RUN_SPEED, CF.MOUNT_SPEED = 7, 11.2
local MOUNT_OVERHEAD = 3    -- seconds to dismount/remount per gather
local GATHER_TIME = { mining = 5, herbalism = 4, skinning = 25, fishing = 40 }

local function zoneAllowed(area, opts)
  local z = CF.ZoneInfo(area)
  if not z then return false end
  if opts.hideEnemy and z[6] ~= "C" and z[6] ~= opts.faction then return false end
  if opts.hideHigh and z[4] > opts.level + 5 then return false end
  if opts.zones and not opts.zones[area] then return false end
  return true
end

function CF.IsMounted()
  local m = CF.settings.mounted
  if m == nil then return UnitLevel("player") >= 40 end
  return m
end

-------------------------------------------------------------------------------
-- collecting points
-------------------------------------------------------------------------------

-- point: { x, y (zone %), y = {[mat] = expected units per visit}, mobs = n,
--          r = respawn seconds, g = seconds per gather }
local function getPoint(col, area, x, y, isMob)
  local zone = col.zones[area]
  if not zone then
    zone = { cells = {}, points = {} }
    col.zones[area] = zone
  end
  local z = CF.ZoneInfo(area)
  local size = isMob and MOB_MERGE_YARDS or MERGE_YARDS
  local cx = math.floor(x * z[7] / 100 / size)
  local cy = math.floor(y * z[8] / 100 / size)
  local key = (isMob and -1 or 1) * (cx * 100000 + cy + 1)
  local p = zone.cells[key]
  if not p then
    p = { x = x, y = y, yield = {}, mobs = 0, r = 0, g = 0 }
    zone.cells[key] = p
    table.insert(zone.points, p)
  end
  return p
end

local function addNode(col, area, x, y, mat, a, r, g, cap)
  local p = getPoint(col, area, x, y, false)
  -- fishing pool types are listed on the same spots but only one pool is there
  if cap then p.cap = math.min(p.cap or 1, cap) end
  -- the same spawn point listed twice for a material is still one spawn
  if not p.yield[mat] or a > p.yield[mat] then p.yield[mat] = a end
  if r > p.r then p.r = r end
  if g > p.g then p.g = g end
end

local function collectGather(col, key, opts)
  local m = CF.materials[key]
  local g = GATHER_TIME[m.prof] + (opts.mounted and MOUNT_OVERHEAD or 0)
  for area, list in pairs(m.zones) do
    if zoneAllowed(area, opts) then
      local a, r = list.a or 0.2, list.r or 300
      local cap = m.prof == "fishing" and a or nil
      for i = 1, #list do
        local x, y = CF.Unpack(list[i])
        addNode(col, area, x, y, key, a, r, g, cap)
      end
    end
  end
end

local function collectLearned(col, key, opts)
  local m = CF.materials[key]
  local g = GATHER_TIME[m.prof] + (opts.mounted and MOUNT_OVERHEAD or 0)
  for area, mats in pairs(CF.db.nodes) do
    local list = mats[key]
    if list and zoneAllowed(area, opts) then
      local zd = m.zones and m.zones[area]
      local a, r = zd and zd.a or 0.2, zd and zd.r or 300
      for i = 1, #list do
        addNode(col, area, list[i][1], list[i][2], key, a, r, g)
      end
    end
  end
end

local function collectSkinning(col, keys, opts)
  local skill = CF.SkillRank("skinning")
  local g = GATHER_TIME.skinning + (opts.mounted and MOUNT_OVERHEAD or 0)
  for area, mobs in pairs(CraftingForever_SkinDB.spawns) do
    if zoneAllowed(area, opts) then
      for mobId, pts in pairs(mobs) do
        local mob = CraftingForever_SkinDB.mobs[mobId]
        local ok = true
        if skill and CF.SkinningSkillForLevel(mob[2]) > skill then ok = false end
        if opts.hideHigh and mob[2] > opts.level + 3 then ok = false end
        local drops, any = {}, false
        if ok then
          for i = 1, #keys do
            local chance = mob[5][keys[i]]
            if chance then
              drops[keys[i]] = chance / 100
              any = true
            end
          end
        end
        if any then
          for i = 1, #pts do
            local x, y = CF.Unpack(pts[i])
            local p = getPoint(col, area, x, y, true)
            p.mobs = p.mobs + 1
            p.mob = mobId
            for mat, c in pairs(drops) do p.yield[mat] = (p.yield[mat] or 0) + c end
            if (mob[6] or 300) > p.r then p.r = mob[6] or 300 end
            p.g = g
          end
        end
      end
    end
  end
end

-- gather events per visit of a point: one node at most, or every mob there
local function finalizePoint(p)
  if p.mobs > 0 then
    p.events = p.mobs
  else
    local e = 0
    for _, a in pairs(p.yield) do e = e + a end
    local cap = p.cap or 1
    if e > cap then
      for mat, a in pairs(p.yield) do p.yield[mat] = a * cap / e end
      e = cap
    end
    p.events = e
  end
end

-- drops points without any neighbour within ISOLATED_YARDS (bucketed lookup)
local function pruneIsolated(area, points)
  local n = #points
  if n <= 5 then return points end
  local z = CF.ZoneInfo(area)
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
          for j = 1, #b do
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

-------------------------------------------------------------------------------
-- yield model
-------------------------------------------------------------------------------

-- f: share of the zone's spawn points that are on this loop (1 = whole zone).
-- Returns lap seconds, gathers per hour, {[mat] = units per hour}.
function CF.EstimateYield(points, length, speed, f)
  f = f or 1
  local travel = length / speed
  local n = #points
  local T = travel
  local rate = 0
  for _ = 1, 8 do
    rate = 0  -- gathers per second
    local gatherTime = 0
    for i = 1, n do
      local p = points[i]
      local r
      if p.mobs > 0 then
        r = p.events / math.max(T, p.r)
      else
        r = p.events / (p.r + f * T / 2 + (1 - f) * OTHERS)
      end
      rate = rate + r
      gatherTime = gatherTime + r * p.g
    end
    -- gatherTime is gathering seconds per second of looping: T = travel + T * share
    local share = math.min(gatherTime, 0.9)
    T = travel / (1 - share)
  end
  local perMat = {}
  for i = 1, n do
    local p = points[i]
    local visits = p.mobs > 0 and 1 / math.max(T, p.r) or 1 / (p.r + f * T / 2 + (1 - f) * OTHERS)
    for mat, y in pairs(p.yield) do
      perMat[mat] = (perMat[mat] or 0) + y * visits * 3600
    end
  end
  return T, rate * 3600, perMat
end

-- random uniform points: optimal tour ~ 0.7124 * sqrt(n * area), nearest
-- neighbour tours run about 25% longer
local function estimateLength(points)
  local n = #points
  local minX, maxX, minY, maxY = points[1].X, points[1].X, points[1].Y, points[1].Y
  for i = 2, n do
    local p = points[i]
    if p.X < minX then minX = p.X end
    if p.X > maxX then maxX = p.X end
    if p.Y < minY then minY = p.Y end
    if p.Y > maxY then maxY = p.Y end
  end
  local area = math.max((maxX - minX) * (maxY - minY), 1)
  return 0.89 * math.sqrt(n * area) + 2 * math.max(maxX - minX, maxY - minY) / math.sqrt(n)
end

-- score: units per hour of the selected materials, scaled by how many of them
-- the route actually offers (asking for copper + tin prefers routes with both)
local function score(perMat, keys)
  local total, present = 0, 0
  for i = 1, #keys do
    local v = perMat[keys[i]] or 0
    total = total + v
    if v >= 0.5 then present = present + 1 end
  end
  return total * present / #keys, total
end

-------------------------------------------------------------------------------
-- tour solving
-------------------------------------------------------------------------------

-- Returns an ordering (closed loop) of the points and its length in yards.
function CF.SolveTour(area, points, improve)
  local n = #points
  local z = CF.ZoneInfo(area)
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

-------------------------------------------------------------------------------
-- search
-------------------------------------------------------------------------------

-- densest spots of a zone, at least `sep` yards apart
local function densestSeeds(points, sep)
  local buckets = {}
  local size = 300
  for i = 1, #points do
    local p = points[i]
    local k = math.floor(p.X / size) * 1000 + math.floor(p.Y / size)
    buckets[k] = (buckets[k] or 0) + p.events
  end
  local scored = {}
  for i = 1, #points do
    local p = points[i]
    local bx, by = math.floor(p.X / size), math.floor(p.Y / size)
    local s = 0
    for dx = -1, 1 do
      for dy = -1, 1 do s = s + (buckets[(bx + dx) * 1000 + by + dy] or 0) end
    end
    table.insert(scored, { p = p, s = s })
  end
  table.sort(scored, function(a, b) return a.s > b.s end)
  local seeds = {}
  for i = 1, #scored do
    local p = scored[i].p
    local ok = true
    for j = 1, #seeds do
      local q = seeds[j]
      if (p.X - q.X) * (p.X - q.X) + (p.Y - q.Y) * (p.Y - q.Y) < sep * sep then ok = false break end
    end
    if ok then
      table.insert(seeds, p)
      if #seeds >= SEEDS then break end
    end
  end
  return seeds
end

local function bestCandidate(area, points, opts, keys)
  local speed = opts.mounted and CF.MOUNT_SPEED or CF.RUN_SPEED
  local total = #points
  local best

  local function try(subset, scope)
    if #subset < 4 then return end
    local f = #subset / total
    local _, _, perMat = CF.EstimateYield(subset, estimateLength(subset), speed, f)
    local sc = score(perMat, keys)
    if not best or sc > best.score then
      best = { points = subset, scope = scope, score = sc, f = f }
    end
  end

  try(points, nil)
  local seeds = densestSeeds(points, RADII[1])
  for s = 1, #seeds do
    local c = seeds[s]
    for ri = 1, #RADII do
      local rad = RADII[ri]
      local subset = {}
      for i = 1, #points do
        local p = points[i]
        if (p.X - c.X) * (p.X - c.X) + (p.Y - c.Y) * (p.Y - c.Y) <= rad * rad then
          table.insert(subset, p)
        end
      end
      if #subset < #points then
        try(subset, { x = c.x, y = c.y, radius = rad })
      end
    end
  end
  return best
end

function CF.RouteOptions(zones)
  return {
    level = UnitLevel("player"),
    faction = CF.PlayerFaction(),
    hideHigh = CF.settings.hideHighZones,
    hideEnemy = CF.settings.hideEnemyZones,
    mounted = CF.IsMounted(),
    zones = zones,
  }
end

local function evaluate(r)
  local speed = r.mounted and CF.MOUNT_SPEED or CF.RUN_SPEED
  r.lap, r.gathers, r.perMat = CF.EstimateYield(r.points, r.length, speed, r.f)
  r.score, r.perHour = score(r.perMat, r.keys)
  r.counts = {}
  for i = 1, #r.points do
    for mat in pairs(r.points[i].yield) do r.counts[mat] = (r.counts[mat] or 0) + 1 end
  end
end

-- keys: list of material keys. zones: optional set {[area]=true} to restrict to.
-- Returns a list of route results, best first.
function CF.FindRoutes(keys, zones)
  local opts = CF.RouteOptions(zones)
  local col = { zones = {} }
  local skinKeys = {}
  for i = 1, #keys do
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
  if #skinKeys > 0 then collectSkinning(col, skinKeys, opts) end

  local candidates = {}
  for area, zone in pairs(col.zones) do
    local z = CF.ZoneInfo(area)
    local points = pruneIsolated(area, zone.points)
    for i = 1, #points do
      local p = points[i]
      finalizePoint(p)
      p.X, p.Y = p.x * z[7] / 100, p.y * z[8] / 100
    end
    if #points >= 4 then
      local c = bestCandidate(area, points, opts, keys)
      if c then
        c.area = area
        table.insert(candidates, c)
      end
    end
  end
  table.sort(candidates, function(a, b) return a.score > b.score end)

  local results = {}
  for i = 1, math.min(CANDIDATES, #candidates) do
    local r = candidates[i]
    r.order, r.length = CF.SolveTour(r.area, r.points, false)
    r.keys = keys
    r.mounted = opts.mounted
    evaluate(r)
    table.insert(results, r)
  end
  table.sort(results, function(a, b) return a.score > b.score end)
  return results
end

-- Activate a route result (or nil to clear). The tour is optimised once here.
function CF.SetActiveRoute(r)
  if r then
    r.order, r.length = CF.SolveTour(r.area, r.points, true)
    evaluate(r)
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
