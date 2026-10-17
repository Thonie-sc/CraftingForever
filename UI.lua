-- Main window: shared frame, tabs and the Routes tab.

local CF = CraftingForever

local frame
local tabs, panels = {}, {}
local MAT_ROWS, MAT_ROW_H = 10, 20
local RESULT_ROWS, RESULT_ROW_H = 7, 32

CF.ui = {}

-------------------------------------------------------------------------------
-- widget helpers
-------------------------------------------------------------------------------

function CF.ui.Button(parent, text, width, height)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetWidth(width)
  b:SetHeight(height or 22)
  b:SetText(text)
  return b
end

local checkCount = 0
function CF.ui.Check(parent, text, getter, setter)
  checkCount = checkCount + 1
  local name = "CraftingForeverCheck" .. checkCount
  local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  c:SetWidth(24)
  c:SetHeight(24)
  local label = c.text or c.Text or _G[name .. "Text"]
  if label then label:SetText(text) end
  c:SetScript("OnShow", function(self, button) self:SetChecked(getter()) end)
  c:SetScript("OnClick", function(self, button) setter(self:GetChecked() and true or false) end)
  return c
end

function CF.ui.Text(parent, font, justify)
  local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  t:SetJustifyH(justify or "LEFT")
  return t
end

local function rowHighlight(row)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  hl:SetBlendMode("ADD")
  hl:SetAllPoints(row)
end

local function rowSelected(row)
  local t = row:CreateTexture(nil, "BACKGROUND")
  t:SetColorTexture(1, 0.82, 0, 0.18)
  t:SetAllPoints(row)
  t:Hide()
  return t
end
CF.ui.RowHighlight, CF.ui.RowSelected = rowHighlight, rowSelected

local function scrollFrame(name, parent, rows, rowH, update)
  local s = CreateFrame("ScrollFrame", name, parent, "FauxScrollFrameTemplate")
  s:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, rowH, update) end)
  return s
end
CF.ui.Scroll = scrollFrame

-------------------------------------------------------------------------------
-- main frame and tabs
-------------------------------------------------------------------------------

local function selectTab(name)
  for k, p in pairs(panels) do
    if k == name then p:Show() else p:Hide() end
  end
  for k, t in pairs(tabs) do
    if k == name then t:LockHighlight() else t:UnlockHighlight() end
  end
  CF.ui.currentTab = name
end

local function createMainFrame()
  frame = CreateFrame("Frame", "CraftingForeverFrame", UIParent, "BackdropTemplate")
  frame:SetWidth(620)
  frame:SetHeight(470)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  frame:SetFrameStrata("HIGH")
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self, button) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self, button) self:StopMovingOrSizing() end)
  frame:Hide()
  table.insert(UISpecialFrames, "CraftingForeverFrame")

  local title = CF.ui.Text(frame, "GameFontNormalLarge", "CENTER")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("CraftingForever")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

  local x = 20
  for _, def in ipairs({ { "routes", "Routes" }, { "guide", "Leveling Guide" } }) do
    local key = def[1]
    local t = CF.ui.Button(frame, CF.L[def[2]], 140, 22)
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -40)
    t:SetScript("OnClick", function(self, button) selectTab(key) end)
    tabs[key] = t
    x = x + 144

    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -66)
    p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    p:Hide()
    panels[key] = p
  end

  CF.ui.BuildRoutesPanel(panels.routes)
  CF.ui.BuildGuidePanel(panels.guide)
  selectTab("routes")
end

function CF.ShowMainFrame(tab)
  if not frame then createMainFrame() end
  frame:Show()
  if tab then selectTab(tab) end
end

function CF.ToggleMainFrame()
  if frame and frame:IsVisible() then frame:Hide() else CF.ShowMainFrame() end
end

-------------------------------------------------------------------------------
-- Routes tab
-------------------------------------------------------------------------------

local R = {}  -- routes tab widgets/state
CF.ui.routes = R  -- exposed for the test harness
R.prof = "mining"
R.results = {}

local function selectedKeys()
  local keys = {}
  for i = 1, #CF.PROFESSIONS do
    local list = CF.materialOrder[CF.PROFESSIONS[i]] or {}
    for j = 1, #list do
      if CF.cdb.selected[list[j]] then table.insert(keys, list[j]) end
    end
  end
  return keys
end
CF.SelectedKeys = selectedKeys

local function updateSelectedText()
  local keys = selectedKeys()
  if #keys == 0 then
    R.selectedText:SetText("|cff888888" .. CF.L["Select one or more materials on the left."] .. "|r")
    return
  end
  local names = {}
  for i = 1, #keys do table.insert(names, CF.materials[keys[i]].name) end
  R.selectedText:SetText(CF.L["Selected:"] .. " |cffffffff" .. table.concat(names, ", ") .. "|r")
end

local function updateMatList()
  local list = CF.materialOrder[R.prof] or {}
  local n = #list
  FauxScrollFrame_Update(R.matScroll, n, MAT_ROWS, MAT_ROW_H)
  local offset = FauxScrollFrame_GetOffset(R.matScroll)
  local rank = CF.SkillRank(R.prof)
  for i = 1, MAT_ROWS do
    local row = R.matRows[i]
    local key = list[i + offset]
    if key then
      local m = CF.materials[key]
      row.key = key
      row.icon:SetTexture(CF.MaterialIcon(key))
      row.name:SetText(m.name)
      if rank and m.skill > rank then
        row.skill:SetText("|cffff4040" .. m.skill .. "|r")
      else
        row.skill:SetText(m.skill)
      end
      if CF.cdb.selected[key] then row.check:Show() else row.check:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
  for p, b in pairs(R.profButtons) do
    if p == R.prof then b:LockHighlight() else b:UnlockHighlight() end
  end
  R.profLabel:SetText(CF.ProfName(R.prof) .. (rank and ("  |cffffffff" .. rank .. "|r") or ""))
  updateSelectedText()
end

local function scopeText(r)
  if not r.scope then return CF.L["whole zone"] end
  return string.format(CF.L["around %d, %d (%d yd radius)"], r.scope.x, r.scope.y, r.scope.radius)
end
CF.ui.ScopeText = scopeText

local function updateResults()
  local active = CF.activeRoute
  for i = 1, RESULT_ROWS do
    local row = R.resultRows[i]
    local r = R.results[i]
    if r then
      local z = CF.ZoneInfo(r.area)
      row.r = r
      row.line1:SetText(string.format("%d. |cffffd100%s|r (%d-%d) - %s", i, CF.ZoneName(r.area), z[4], z[5], scopeText(r)))
      local parts = {}
      for j = 1, #r.keys do
        local k = r.keys[j]
        local v = r.perMat[k] or 0
        local color = v >= 0.5 and "ffffff" or "ff4040"
        table.insert(parts, string.format("|cff%s%s %d|r", color, CF.materials[k].name, math.floor(v + 0.5)))
      end
      row.line2:SetText(string.format(CF.L["~%d gathers/h, lap %s, %d stops"], math.floor(r.perHour + 0.5),
        CF.FormatTime(r.lap), #r.points) .. " - " .. table.concat(parts, ", "))
      if active and active.area == r.area and active.keys == r.keys then row.sel:Show() else row.sel:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
  if #R.results == 0 and R.searched then
    R.status:SetText("|cffff8040" .. CF.L["No routes found. Try other materials or untick the zone filters."] .. "|r")
  elseif active then
    R.status:SetText(string.format(CF.L["Active: %s, ~%d gathers/h, lap %s."],
      CF.ZoneName(active.area), math.floor(active.perHour + 0.5), CF.FormatTime(active.lap)))
  else
    R.status:SetText("")
  end
end

function CF.ui.RunRouteSearch(keys, zones)
  R.results = CF.FindRoutes(keys, zones)
  R.searched = true
  if R.resultRows then updateResults() end
  return R.results
end

local function search()
  local keys = selectedKeys()
  if #keys == 0 then
    R.results, R.searched = {}, false
    updateResults()
    R.status:SetText("|cffff8040" .. CF.L["Select at least one material first."] .. "|r")
    return
  end
  CF.ui.RunRouteSearch(keys)
end

-- results belong to the selection they were found for; drop them when it changes
local function selectionChanged()
  R.results, R.searched = {}, false
  updateMatList()
  updateResults()
end

function CF.ui.BuildRoutesPanel(p)
  -- profession filter: icon buttons
  R.profButtons = {}
  for i = 1, #CF.PROFESSIONS do
    local prof = CF.PROFESSIONS[i]
    local b = CreateFrame("Button", nil, p)
    b:SetWidth(22)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 25, 0)
    b:SetNormalTexture(CF.PROF_ICON[prof])
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(b)
    b:SetScript("OnClick", function(self, button)
      R.prof = prof
      _G["CraftingForeverMatScrollScrollBar"]:SetValue(0)
      updateMatList()
    end)
    b:SetScript("OnEnter", function(self, button)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(CF.ProfName(prof))
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self, button) GameTooltip:Hide() end)
    R.profButtons[prof] = b
  end
  R.profLabel = CF.ui.Text(p, "GameFontNormal")
  R.profLabel:SetPoint("TOPLEFT", p, "TOPLEFT", #CF.PROFESSIONS * 25 + 6, -4)

  -- material list
  local listBox = CreateFrame("Frame", nil, p, "BackdropTemplate")
  listBox:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -24)
  listBox:SetWidth(236)
  listBox:SetHeight(MAT_ROWS * MAT_ROW_H + 8)
  listBox:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  listBox:SetBackdropColor(0, 0, 0, 0.5)

  R.matScroll = scrollFrame("CraftingForeverMatScroll", listBox, MAT_ROWS, MAT_ROW_H, updateMatList)
  R.matScroll:SetPoint("TOPLEFT", listBox, "TOPLEFT", 4, -4)
  R.matScroll:SetPoint("BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -26, 4)

  R.matRows = {}
  for i = 1, MAT_ROWS do
    local row = CreateFrame("Button", nil, listBox)
    -- above the scroll frame, which would otherwise swallow the clicks
    row:SetFrameLevel(R.matScroll:GetFrameLevel() + 2)
    row:RegisterForClicks("LeftButtonUp")
    row:SetWidth(206)
    row:SetHeight(MAT_ROW_H)
    row:SetPoint("TOPLEFT", listBox, "TOPLEFT", 5, -4 - (i - 1) * MAT_ROW_H)
    rowHighlight(row)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.check:SetWidth(18)
    row.check:SetHeight(18)
    row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(16)
    row.icon:SetHeight(16)
    row.icon:SetPoint("LEFT", row, "LEFT", 20, 0)
    row.name = CF.ui.Text(row, "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.skill = CF.ui.Text(row, "GameFontNormalSmall", "RIGHT")
    row.skill:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row:SetScript("OnClick", function(self, button)
      local sel = CF.cdb.selected
      if sel[self.key] then sel[self.key] = nil else sel[self.key] = true end
      selectionChanged()
    end)
    row:SetScript("OnEnter", function(self, button)
      local m = CF.materials[self.key]
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(m.name, 1, 1, 1)
      GameTooltip:AddLine(string.format("%s %d", CF.ProfName(m.prof), m.skill), 0.8, 0.8, 0.8)
      if m.nodes then
        local names = {}
        local objects = CF.LDB.objects or {}
        for j = 1, #m.nodes do table.insert(names, objects[m.nodes[j]] or m.nodes[j]) end
        GameTooltip:AddLine(table.concat(names, ", "), 0.6, 0.6, 0.6, 1)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self, button) GameTooltip:Hide() end)
    R.matRows[i] = row
  end

  local clearSel = CF.ui.Button(p, CF.L["Clear selection"], 130, 20)
  clearSel:SetPoint("TOPLEFT", listBox, "BOTTOMLEFT", 0, -4)
  clearSel:SetScript("OnClick", function(self, button)
    CF.cdb.selected = {}
    selectionChanged()
  end)

  -- display options
  local opts = {
    { "Show gathered nodes", "showLearned" },
    { "Show route", "showRoute" },
    { "Minimap icons", "minimapPins" },
    { "Show anvils & forges", "showStations" },
    { "Adventure mode: only used ones", "adventureMode" },
  }
  local prev = clearSel
  for i = 1, #opts do
    local label, setting = opts[i][1], opts[i][2]
    local c = CF.ui.Check(p, CF.L[label],
      function() return CF.settings[setting] end,
      function(v)
        CF.settings[setting] = v
        CF.UpdateWorldMap()
        CF.UpdateMinimap()
      end)
    c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -2 or 4)
    prev = c
  end

  -- right column ------------------------------------------------------------
  local right = CreateFrame("Frame", nil, p)
  right:SetPoint("TOPLEFT", p, "TOPLEFT", 248, 0)
  right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)

  R.selectedText = CF.ui.Text(right, "GameFontNormalSmall")
  R.selectedText:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -2)
  R.selectedText:SetWidth(340)
  R.selectedText:SetHeight(28)
  R.selectedText:SetJustifyV("TOP")

  local find = CF.ui.Button(right, CF.L["Find best routes"], 140, 24)
  find:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -32)
  find:SetScript("OnClick", search)

  local hideHigh = CF.ui.Check(right, CF.L["Hide high-level zones"],
    function() return CF.settings.hideHighZones end,
    function(v) CF.settings.hideHighZones = v end)
  hideHigh:SetPoint("TOPLEFT", find, "TOPRIGHT", 8, 1)
  local hideEnemy = CF.ui.Check(right, CF.L["Hide enemy territory"],
    function() return CF.settings.hideEnemyZones end,
    function(v) CF.settings.hideEnemyZones = v end)
  hideEnemy:SetPoint("TOPLEFT", hideHigh, "BOTTOMLEFT", 0, 6)
  local mounted = CF.ui.Check(right, CF.L["Mounted"],
    function() return CF.IsMounted() end,
    function(v) CF.settings.mounted = v end)
  mounted:SetPoint("TOPLEFT", find, "BOTTOMLEFT", 0, -2)

  R.resultRows = {}
  for i = 1, RESULT_ROWS do
    local row = CreateFrame("Button", nil, right)
    row:SetWidth(348)
    row:SetHeight(RESULT_ROW_H)
    row:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -84 - (i - 1) * (RESULT_ROW_H + 2))
    rowHighlight(row)
    row.sel = rowSelected(row)
    row.line1 = CF.ui.Text(row, "GameFontHighlightSmall")
    row.line1:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
    row.line1:SetWidth(344)
    row.line1:SetHeight(14)
    row.line2 = CF.ui.Text(row, "GameFontDisableSmall")
    row.line2:SetPoint("TOPLEFT", row.line1, "BOTTOMLEFT", 0, -2)
    row.line2:SetWidth(344)
    row.line2:SetHeight(14)
    row:SetScript("OnClick", function(self, button)
      CF.SetActiveRoute(self.r)
      updateResults()
    end)
    row:SetScript("OnDoubleClick", function(self, button)
      CF.SetActiveRoute(self.r)
      CF.ShowZoneOnMap(self.r.area)
    end)
    row:Hide()
    R.resultRows[i] = row
  end

  local showMap = CF.ui.Button(right, CF.L["Show on map"], 116, 22)
  showMap:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 22)
  showMap:SetScript("OnClick", function(self, button)
    if CF.activeRoute then CF.ShowZoneOnMap(CF.activeRoute.area) end
  end)
  local clear = CF.ui.Button(right, CF.L["Clear route"], 116, 22)
  clear:SetPoint("LEFT", showMap, "RIGHT", 6, 0)
  clear:SetScript("OnClick", function(self, button)
    CF.SetActiveRoute(nil)
    updateResults()
  end)

  R.status = CF.ui.Text(right, "GameFontNormalSmall")
  R.status:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
  R.status:SetWidth(350)
  R.status:SetHeight(20)

  p:SetScript("OnShow", function(self, button)
    updateMatList()
    updateResults()
  end)
end

CF.On("PROFESSIONS_UPDATED", function()
  if R.matRows and frame:IsVisible() then updateMatList() end
end)
CF.On("ROUTE_CHANGED", function()
  if R.resultRows then updateResults() end
end)

-------------------------------------------------------------------------------
-- minimap button
-------------------------------------------------------------------------------

local function positionMinimapButton(b)
  local a = math.rad(CF.settings.minimapButtonAngle)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end

CF.On("INIT", function()
  local b = CreateFrame("Button", "CraftingForeverMinimapButton", Minimap)
  b:SetWidth(32)
  b:SetHeight(32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\Trade_Mining")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("CENTER", b, "CENTER", -1, 1)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(54)
  border:SetHeight(54)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

  b:SetScript("OnClick", function(self, button)
    if button == "RightButton" then CF.ToggleTracker() else CF.ToggleMainFrame() end
  end)
  b:SetScript("OnDragStart", function(self, button)
    self:SetScript("OnUpdate", function(self, button)
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      CF.settings.minimapButtonAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      positionMinimapButton(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self, button) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self, button)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("CraftingForever")
    GameTooltip:AddLine(CF.L["Left-click: routes & guides"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(CF.L["Right-click: toggle guide tracker"], 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self, button) GameTooltip:Hide() end)
  positionMinimapButton(b)
end)
