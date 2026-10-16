-- Leveling Guide tab and the on-screen guide tracker.

local CF = CraftingForever

local G = {}       -- guide tab widgets/state
local ROWS, ROW_H = 7, 38

local COLOR = {
  optimal = "|cffff8040", medium = "|cffffff00", easy = "|cff40bf40", trivial = "|cff808080",
}

-- guides for professions the character has, in display order
local function knownGuides()
  local list = {}
  for i = 1, table.getn(CF.GUIDE_ORDER) do
    local k = CF.GUIDE_ORDER[i]
    if CF.profs[k] then table.insert(list, k) end
  end
  return list
end
CF.KnownGuides = knownGuides

local function zoneNames(step)
  if not step.zones then return nil end
  local list = step.zones[CF.PlayerFaction()] or {}
  local names = {}
  for i = 1, table.getn(list) do table.insert(names, CF.ZoneName(list[i])) end
  return table.concat(names, ", ")
end

local function matNames(step)
  local names = {}
  for i = 1, table.getn(step.mats) do
    local m = CF.materials[step.mats[i]]
    if m then table.insert(names, m.name) end
  end
  return table.concat(names, ", ")
end

-- crafts still needed in this step for the current rank (rough estimate)
local function craftsLeft(step, rank)
  if rank <= step.from then return step.n end
  if rank >= step.to then return 0 end
  return math.ceil(step.n * (step.to - rank) / (step.to - step.from))
end

local function reagentText(step, crafts)
  local mats, real = CF.StepReagents(step)
  if not mats then
    return "|cff888888" .. CF.L["Reagents unknown - open your profession window once to load them."] .. "|r"
  end
  local parts = {}
  for i = 1, table.getn(mats) do
    local name, per = mats[i][1], mats[i][2]
    local need = per * crafts
    local have = CF.CountInBags(name)
    local color = have >= need and "|cff40ff40" or "|cffffffff"
    table.insert(parts, string.format("%s%s %d/%d|r", color, name, have, need))
  end
  return table.concat(parts, ", ") .. (real and "" or " |cff888888*|r")
end

function CF.FindGuideRoute(step)
  local zones
  local list = step.zones and step.zones[CF.PlayerFaction()]
  if list then
    zones = {}
    for i = 1, table.getn(list) do zones[list[i]] = true end
  end
  for i = 1, table.getn(step.mats) do CF.cdb.selected[step.mats[i]] = true end
  local results = CF.ui.RunRouteSearch(step.mats, zones)
  if table.getn(results) == 0 then
    -- the recommended zones may all be filtered; fall back to everywhere
    results = CF.ui.RunRouteSearch(step.mats)
  end
  if results[1] then
    CF.SetActiveRoute(results[1])
    CF.Print(string.format(CF.L["Route: %s, ~%d gathers/h. Open the world map to see it."],
      CF.ZoneName(results[1].area), math.floor(results[1].perHour + 0.5)))
  else
    CF.Print(CF.L["No route found for this step."])
  end
  CF.ShowMainFrame("routes")
end

-------------------------------------------------------------------------------
-- guide tab
-------------------------------------------------------------------------------

local function updateSteps()
  local key = G.key
  local g = key and CF.Guides[key]
  if not g then
    G.header:SetText("|cff888888" .. CF.L["No supported profession found on this character. Tick \"All guides\" to browse."] .. "|r")
    G.hint:SetText("")
    for i = 1, ROWS do G.rows[i]:Hide() end
    FauxScrollFrame_Update(G.scroll, 0, ROWS, ROW_H)
    return
  end

  local p = CF.profs[key]
  local rank = p and p.rank or 0
  local _, current = CF.GuideStep(key, rank)
  if p then
    G.header:SetText(string.format("%s  |cffffffff%d / %d|r", CF.ProfName(key), p.rank, p.max))
  else
    G.header:SetText(CF.ProfName(key) .. "  |cff888888" .. CF.L["(not learned)"] .. "|r")
  end
  G.hint:SetText(CF.TrainerHint(key) or "")

  local steps = g.steps
  local n = table.getn(steps)
  FauxScrollFrame_Update(G.scroll, n, ROWS, ROW_H)
  local offset = FauxScrollFrame_GetOffset(G.scroll)
  for i = 1, ROWS do
    local row = G.rows[i]
    local idx = i + offset
    local step = steps[idx]
    if step then
      row.step = step
      local done = p and rank >= step.to
      local range = string.format("%d-%d", step.from, step.to)
      local line1, line2
      if g.kind == "gather" then
        line1 = matNames(step) .. (step.text and ("  |cffaaaaaa" .. CF.T(step.text) .. "|r") or "")
        line2 = zoneNames(step) or ""
        row.route:Show()
      else
        local left = p and craftsLeft(step, rank) or step.n
        local craft = CF.ItemName(step.craft)
        local color = COLOR[CF.cdb.recipeColor[craft] or ""] or "|cffffffff"
        line1 = string.format("%s%s|r x%d", color, craft, left)
        local note = step[CF.PlayerFaction()] or step.text
        if note then line1 = line1 .. "  |cffaaaaaa" .. CF.T(note) .. "|r" end
        line2 = reagentText(step, left)
        row.route:Hide()
      end
      row.range:SetText(done and ("|cff666666" .. range .. "|r") or range)
      row.line1:SetText(done and ("|cff666666" .. line1 .. "|r") or line1)
      row.line2:SetText(line2)
      if idx == current and p then row.sel:Show() else row.sel:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
end

local function updateGuideButtons()
  local list = G.showAll and CF.GUIDE_ORDER or knownGuides()
  if not G.key or not CF.Guides[G.key] or (not G.showAll and not CF.profs[G.key]) then
    G.key = list[1]
  end
  for i = 1, table.getn(G.buttons) do
    local b = G.buttons[i]
    local key = list[i]
    if key then
      b.key = key
      b:SetText(CF.ProfName(key))
      if key == G.key then b:LockHighlight() else b:UnlockHighlight() end
      b:Show()
    else
      b:Hide()
    end
  end
  updateSteps()
end
CF.UpdateGuide = function() if G.rows then updateGuideButtons() end end

function CF.ui.BuildGuidePanel(p)
  G.panel = p
  G.buttons = {}
  for i = 1, table.getn(CF.GUIDE_ORDER) do
    local b = CF.ui.Button(p, "", 92, 20)
    local col = math.mod(i - 1, 5)
    local line = math.floor((i - 1) / 5)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", col * 94, -line * 22)
    b:SetScript("OnClick", function()
      G.key = this.key
      getglobal("CraftingForeverGuideScrollScrollBar"):SetValue(0)
      updateGuideButtons()
    end)
    G.buttons[i] = b
  end

  local all = CF.ui.Check(p, CF.L["All guides"],
    function() return G.showAll end,
    function(v)
      G.showAll = v
      updateGuideButtons()
    end)
  all:SetPoint("TOPLEFT", p, "TOPLEFT", 474, 0)

  G.header = CF.ui.Text(p, "GameFontNormalLarge")
  G.header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -70)
  G.hint = CF.ui.Text(p, "GameFontNormalSmall")
  G.hint:SetPoint("LEFT", G.header, "RIGHT", 12, 0)
  G.hint:SetTextColor(1, 0.4, 0.4)

  local box = CreateFrame("Frame", nil, p)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -92)
  box:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 14)
  box:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  box:SetBackdropColor(0, 0, 0, 0.5)

  G.scroll = CF.ui.Scroll("CraftingForeverGuideScroll", box, ROWS, ROW_H, updateSteps)
  G.scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
  G.scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 4)

  G.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, box)
    row:SetWidth(554)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -5 - (i - 1) * ROW_H)
    row.sel = CF.ui.RowSelected(row)
    row.range = CF.ui.Text(row, "GameFontNormal")
    row.range:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -4)
    row.range:SetWidth(64)
    row.line1 = CF.ui.Text(row, "GameFontHighlightSmall")
    row.line1:SetPoint("TOPLEFT", row, "TOPLEFT", 70, -4)
    row.line1:SetWidth(410)
    row.line1:SetHeight(14)
    row.line2 = CF.ui.Text(row, "GameFontDisableSmall")
    row.line2:SetPoint("TOPLEFT", row.line1, "BOTTOMLEFT", 0, -2)
    row.line2:SetWidth(410)
    row.line2:SetHeight(14)
    row.route = CF.ui.Button(row, CF.L["Find route"], 76, 20)
    row.route:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.route:SetScript("OnClick", function() CF.FindGuideRoute(this:GetParent().step) end)
    G.rows[i] = row
  end

  local foot = CF.ui.Text(p, "GameFontDisableSmall")
  foot:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 2, 0)
  foot:SetText(CF.L["* reagents from the guide; opening your profession window loads the real recipe. Counts are bag totals / needed."])

  p:SetScript("OnShow", updateGuideButtons)
end

-------------------------------------------------------------------------------
-- tracker
-------------------------------------------------------------------------------

local tracker
local TRACK_LINES = 6

local function updateTracker()
  if not tracker or not tracker:IsVisible() then return end
  local list = knownGuides()
  local shown = 0
  for i = 1, table.getn(list) do
    if shown >= TRACK_LINES then break end
    local key = list[i]
    local g, p = CF.Guides[key], CF.profs[key]
    local step = CF.GuideStep(key, p.rank)
    if step and p.rank < 300 then
      shown = shown + 1
      local text
      local hint = CF.TrainerHint(key)
      if hint then
        text = "|cffff6060" .. hint .. "|r"
      elseif g.kind == "gather" then
        text = matNames(step)
        local zones = step.zones and step.zones[CF.PlayerFaction()]
        if zones and zones[1] then text = text .. " - " .. CF.ZoneName(zones[1]) end
      else
        local craft = CF.ItemName(step.craft)
        local color = COLOR[CF.cdb.recipeColor[craft] or ""] or "|cffffffff"
        text = string.format("%s%s|r x%d", color, craft, craftsLeft(step, p.rank))
      end
      local line = tracker.lines[shown]
      line:SetText(string.format("|cffffd100%s %d/%d|r: %s", CF.ProfName(key), p.rank, p.max, text))
      line:Show()
    end
  end
  for i = shown + 1, TRACK_LINES do tracker.lines[i]:Hide() end
  if shown == 0 then
    tracker.lines[1]:SetText("|cff888888" .. CF.L["No profession to level."] .. "|r")
    tracker.lines[1]:Show()
    shown = 1
  end
  tracker:SetHeight(26 + shown * 14)
end

local function createTracker()
  tracker = CreateFrame("Frame", "CraftingForeverTracker", UIParent)
  tracker:SetWidth(330)
  tracker:SetHeight(60)
  tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -220)
  tracker:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  tracker:SetBackdropColor(0, 0, 0, 0.6)
  tracker:EnableMouse(true)
  tracker:SetMovable(true)
  tracker:SetClampedToScreen(true)
  tracker:RegisterForDrag("LeftButton")
  tracker:SetScript("OnDragStart", function() this:StartMoving() end)
  tracker:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  tracker:SetScript("OnMouseUp", function()
    if arg1 == "RightButton" then CF.ShowMainFrame("guide") end
  end)

  local title = CF.ui.Text(tracker, "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", tracker, "TOPLEFT", 8, -6)
  title:SetText("CraftingForever  |cff888888" .. CF.L["(right-click for guide)"] .. "|r")

  tracker.lines = {}
  for i = 1, TRACK_LINES do
    local l = CF.ui.Text(tracker, "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT", tracker, "TOPLEFT", 8, -8 - i * 14)
    l:SetWidth(316)
    l:SetHeight(14)
    tracker.lines[i] = l
  end
  tracker:SetScript("OnShow", updateTracker)
end

function CF.ToggleTracker()
  if not tracker then createTracker() end
  if tracker:IsVisible() then
    tracker:Hide()
    CF.cdb.trackerShown = false
  else
    tracker:Show()
    CF.cdb.trackerShown = true
  end
end

CF.RegisterEvent("PLAYER_ENTERING_WORLD", function()
  if not tracker then
    createTracker()
    if CF.cdb.trackerShown then tracker:Show() else tracker:Hide() end
  end
  updateTracker()
end)

local function refresh()
  updateTracker()
  CF.UpdateGuide()
end
CF.On("PROFESSIONS_UPDATED", refresh)
CF.On("RECIPES_UPDATED", refresh)
CF.RegisterEvent("BAG_UPDATE", function()
  if G.panel and G.panel:IsVisible() then updateSteps() end
end)
