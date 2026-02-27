-- HKDToasts_Config.lua
-- Config UI + Slash commands (improved: header-drag only, scroll, docked reminders, flat edits)

local HKDT = _G.HKDT
if not HKDT then return end

local DEFAULTS     = HKDT.DEFAULTS
local CopyDefaults = HKDT.CopyDefaults
local Enqueue      = HKDT.Enqueue

local function DB() return HKDT.DB end

local C_ACCENT = HKDT.C_ACCENT or ""
local C_RESET  = HKDT.C_RESET  or ""
local C_MUTED  = HKDT.C_MUTED  or ""

local Active              = HKDT.Active
local Queue               = HKDT.Queue
local ApplyLayout         = HKDT.ApplyLayout
local ApplyToastFont      = HKDT.ApplyToastFont
local SetFramePosition    = HKDT.SetFramePosition
local RefreshAnchor       = HKDT.RefreshAnchor
local Reflow              = HKDT.Reflow
local StartToast          = HKDT.StartToast
local RefreshActiveStyle  = HKDT.RefreshActiveStyle

--- =========================================================
-- Fonts (single source of truth: HKDT core)
-- =========================================================
local function GetFontListSafe()
  if HKDT and HKDT.GetFontList then
    local list = HKDT.GetFontList() or {}
    local out = {}
    for _, it in ipairs(list) do
      if it and it.name and it.name ~= "" then
        out[#out+1] = it.name
      end
    end
    if #out > 0 then return out end
  end
  return { "Friz Quadrata", "GameFontNormal", "Expressway" }
end

-- (rest stays the same)
local EnsureReminderTicker = HKDT.EnsureReminderTicker
local ScheduleDailyReset   = HKDT.ScheduleDailyReset
local CheckVaultAndNotify  = HKDT.CheckVaultAndNotify

local ApplyFriendToastSuppression = HKDT.ApplyFriendToastSuppression
local Friends_ResetCache          = HKDT.Friends_ResetCache

local RefreshLockChip

-- ---------------------------------------------------------
-- Color picker helpers (global wrappers)
-- ---------------------------------------------------------

-- normal picker (sem alpha) -> usado pra whisper/mail/etc
function OpenColorPicker(initial, onChanged)
  if not initial then return end

  local prev = { r = initial.r or 0, g = initial.g or 0, b = initial.b or 0 }

  local function Apply()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    if onChanged then onChanged(r, g, b) end
  end

  local function Cancel()
    if onChanged then onChanged(prev.r, prev.g, prev.b) end
  end

  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = prev.r, g = prev.g, b = prev.b,
      hasOpacity = false,
      swatchFunc = Apply,
      cancelFunc = Cancel,
    })
    return
  end

  -- legacy fallback
  ColorPickerFrame:Hide()
  ColorPickerFrame.hasOpacity = false
  ColorPickerFrame.func = Apply
  ColorPickerFrame.cancelFunc = Cancel
  ColorPickerFrame:SetColorRGB(prev.r, prev.g, prev.b)
  ColorPickerFrame:Show()
end

-- =========================================================
-- Theme helpers
-- =========================================================
local function GetPlayerClassColor()
  local classFile = select(2, UnitClass("player"))
  if C_ClassColor and C_ClassColor.GetClassColor and classFile then
    local c = C_ClassColor.GetClassColor(classFile)
    if c then return c.r, c.g, c.b end
  end
  if RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile] then
    local c = RAID_CLASS_COLORS[classFile]
    return c.r, c.g, c.b
  end
  return 1, 1, 1
end

local function ApplyConfigTheme(frame)
  if not frame then return end
  local r,g,b = GetPlayerClassColor()
  frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0,0,0,0.90)
  frame:SetBackdropBorderColor(r,g,b,0.85)
end

local function ApplyPanelTheme(panel)
  if not panel then return end
  panel:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  panel:SetBackdropColor(0,0,0,0.45)
  panel:SetBackdropBorderColor(1,1,1,0.08)
end

local function ApplySoftButtonTheme(btn, active)
  if not btn then return end
  btn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  if active then
    local r,g,b = GetPlayerClassColor()
    btn:SetBackdropColor(1,1,1,0.06)
    btn:SetBackdropBorderColor(r,g,b,0.75)
  else
    btn:SetBackdropColor(1,1,1,0.03)
    btn:SetBackdropBorderColor(1,1,1,0.10)
  end
end

local function ApplyFlatEditTheme(eb)
  if not eb then return end
  eb:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  eb:SetBackdropColor(0,0,0,0.35)
  eb:SetBackdropBorderColor(1,1,1,0.12)
end

local function ApplyFlatEditFocus(eb, focused)
  if not eb then return end
  if focused then
    local r,g,b = GetPlayerClassColor()
    eb:SetBackdropBorderColor(r,g,b,0.65)
    eb:SetBackdropColor(0,0,0,0.45)
  else
    eb:SetBackdropBorderColor(1,1,1,0.12)
    eb:SetBackdropColor(0,0,0,0.35)
  end
end

-- =========================================================
-- Root frame
-- =========================================================
local cfg = CreateFrame("Frame", "HKDToastsConfig", UIParent, "BackdropTemplate")
HKDT.ConfigFrame = cfg
cfg:Hide()
cfg:SetSize(820, 540)
cfg:SetPoint("CENTER")
cfg:SetClampedToScreen(true)
cfg:SetMovable(true)
cfg:EnableMouse(true)
cfg:SetFrameStrata("DIALOG")
cfg:SetFrameLevel((UIParent:GetFrameLevel() or 1) + 50)
ApplyConfigTheme(cfg)

-- ✅ Resizable window + min size
local CFG_MIN_W, CFG_MIN_H = 640, 420
cfg:SetResizable(true)
if cfg.SetMinResize then
  cfg:SetMinResize(CFG_MIN_W, CFG_MIN_H)
end

-- =========================================================
-- Header (✅ drag ONLY here)
-- =========================================================
local header = CreateFrame("Frame", nil, cfg)
header:SetPoint("TOPLEFT", 12, -10)
header:SetPoint("TOPRIGHT", -12, -10)
header:SetHeight(32)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() cfg:StartMoving() end)
header:SetScript("OnDragStop",  function() cfg:StopMovingOrSizing() end)

local cfgTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
cfgTitle:SetPoint("LEFT", 6, 0)
cfgTitle:SetText(C_ACCENT .. "HKDToasts" .. C_RESET .. " " .. C_MUTED .. "Config" .. C_RESET)

-- Close button
local closeBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
closeBtn:SetSize(22, 22)
closeBtn:SetPoint("RIGHT", 0, 0)
ApplySoftButtonTheme(closeBtn, false)

local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeX:SetPoint("CENTER", 0, 0)
closeX:SetText("X")
closeX:SetTextColor(1,1,1,0.90)

closeBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1,1,1,0.06) end)
closeBtn:SetScript("OnLeave", function(self) ApplySoftButtonTheme(self, false) end)
closeBtn:SetScript("OnClick", function() cfg:Hide() end)

-- Lock chip
local lockBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
lockBtn:SetSize(110, 22)
lockBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
ApplySoftButtonTheme(lockBtn, false)

local lockTxt = lockBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lockTxt:SetPoint("CENTER", 0, 0)

RefreshLockChip = function()
  local db = DB()
  if not db then
    lockTxt:SetText("Unlocked")
    lockTxt:SetTextColor(1,1,1,0.85)
    ApplySoftButtonTheme(lockBtn, false)
    return
  end

  lockTxt:SetText(db.locked and "Locked" or "Unlocked")
  if db.locked then
    lockTxt:SetTextColor(1,1,1,0.95)
    ApplySoftButtonTheme(lockBtn, true)
  else
    lockTxt:SetTextColor(1,1,1,0.85)
    ApplySoftButtonTheme(lockBtn, false)
  end
end
HKDT.RefreshLockChip = RefreshLockChip

lockBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1,1,1,0.06) end)
lockBtn:SetScript("OnLeave", function() RefreshLockChip() end)
lockBtn:SetScript("OnClick", function()
  local db = DB(); if not db then return end
  db.locked = not db.locked
  RefreshLockChip()
  RefreshAnchor()
  print("HKDToasts: " .. (db.locked and "locked." or "unlocked."))
end)

-- ✅ Test Toast button (top-left of Locked)
local testBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
testBtn:SetSize(110, 22)
testBtn:SetPoint("RIGHT", lockBtn, "LEFT", -10, 0)
ApplySoftButtonTheme(testBtn, false)

local testTxt = testBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
testTxt:SetPoint("CENTER", 0, 0)
testTxt:SetText("Test Toast")
testTxt:SetTextColor(1,1,1,0.90)

testBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1,1,1,0.06) end)
testBtn:SetScript("OnLeave", function(self) ApplySoftButtonTheme(self, false) end)
testBtn:SetScript("OnClick", function()
  Enqueue("WHISPER", "Hakoda-Azralon", "test whisper (Hello! :-))")
  C_Timer.After(0.6, function() Enqueue("BNET", "Friend#1234", "test BNet (Hi!)") end)
  C_Timer.After(1.2, function() Enqueue("MAIL", nil, "You have new mail to open.") end)
  C_Timer.After(1.8, function() Enqueue("VAULT", nil, "Rewards available to claim.") end)
  C_Timer.After(2.4, function() Enqueue("SYSTEM", nil, "Daily reset is live.") end)
  C_Timer.After(3.0, function() Enqueue("REMINDER", nil, "Stretch + water") end)
  C_Timer.After(3.6, function() Enqueue("DURA70", nil, "Armor at 70%") end)
  C_Timer.After(4.2, function() Enqueue("DURA30", nil, "Armor at 30%") end)
  C_Timer.After(4.8, function() Enqueue("DURA10", nil, "Armor at 10%") end)
  C_Timer.After(5.4, function() Enqueue("FRIEND_ON", "Thrall", "has come online.") end)
  C_Timer.After(6.0, function() Enqueue("FRIEND_OFF", "Thrall", "has gone offline.") end)
  C_Timer.After(6.6, function() Enqueue("BAG90", nil, "Bags at 90%") end)
  C_Timer.After(7.2, function() Enqueue("BAGFULL", nil, "Empty your bags.") end)
  C_Timer.After(7.8, function() Enqueue("KEY", "New Key", "Murder Row +12") end)
end)

-- ✅ Minimap button (next to Test Toast)
local mmBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
mmBtn:SetSize(130, 22)
mmBtn:SetPoint("RIGHT", testBtn, "LEFT", -10, 0)
ApplySoftButtonTheme(mmBtn, false)

local mmTxt = mmBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mmTxt:SetPoint("CENTER", 0, 0)

local function RefreshMinimapChip()
  local db = DB(); if not db then return end
  db.minimap = db.minimap or {}
  local hidden = db.minimap.hide and true or false
  mmTxt:SetText(hidden and "Minimap Button: OFF" or "Minimap Button: ON")
  mmTxt:SetTextColor(1,1,1,0.90)
end

mmBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1,1,1,0.06) end)
mmBtn:SetScript("OnLeave", function(self) ApplySoftButtonTheme(self, false) end)
mmBtn:SetScript("OnClick", function()
  local db = DB(); if not db then return end
  db.minimap = db.minimap or {}
  db.minimap.hide = not db.minimap.hide

  if HKDT.SetMinimapHidden then
    HKDT.SetMinimapHidden(db.minimap.hide)
  end

  RefreshMinimapChip()
end)

-- =========================================================
-- Body layout: [Reminders Panel] gap [Main Config]
-- =========================================================
local body = CreateFrame("Frame", nil, cfg)
body:SetPoint("TOPLEFT", 12, -52)
body:SetPoint("BOTTOMRIGHT", -12, 12)

local GAP = 10
local sidebarW = 150
local remindersW = 250

-- ✅ Reminders panel (child of cfg: hides/moves together)
local remPanel = CreateFrame("Frame", nil, body, "BackdropTemplate")
remPanel:SetPoint("TOPLEFT", 0, 0)
remPanel:SetPoint("BOTTOMLEFT", 0, 0)
remPanel:SetWidth(remindersW)
ApplyPanelTheme(remPanel)

local remTitle = remPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
remTitle:SetPoint("TOPLEFT", 12, -12)
remTitle:SetText(C_MUTED .. "Reminders" .. C_RESET)

-- Main shell to the right
local mainShell = CreateFrame("Frame", nil, body, "BackdropTemplate")
mainShell:SetPoint("TOPLEFT", remPanel, "TOPRIGHT", GAP, 0)
mainShell:SetPoint("BOTTOMRIGHT", 0, 0)
ApplyPanelTheme(mainShell)

-- Sidebar
local sidebar = CreateFrame("Frame", nil, mainShell, "BackdropTemplate")
sidebar:SetPoint("TOPLEFT", 0, 0)
sidebar:SetPoint("BOTTOMLEFT", 0, 0)
sidebar:SetWidth(sidebarW)
ApplyPanelTheme(sidebar)

-- Content panel
local content = CreateFrame("Frame", nil, mainShell, "BackdropTemplate")
content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
content:SetPoint("BOTTOMRIGHT", 0, 0)
ApplyPanelTheme(content)

-- ✅ Content scroll (so small window can scroll)
local contentScroll = CreateFrame("ScrollFrame", "HKDToastsConfigContentScroll", content, "UIPanelScrollFrameTemplate")
contentScroll:SetPoint("TOPLEFT", 0, 0)
contentScroll:SetPoint("BOTTOMRIGHT", 0, 0)

-- keep scrollbar inside
local sb = _G[contentScroll:GetName() .. "ScrollBar"]
if sb then
  sb:ClearAllPoints()
  sb:SetPoint("TOPRIGHT", -6, -18)
  sb:SetPoint("BOTTOMRIGHT", -6, 18)
end

local contentChild = CreateFrame("Frame", nil, contentScroll)
contentChild:SetSize(1, 1)

-- ✅ CRÍTICO: scroll child precisa ter largura “real” via anchors,
-- senão as páginas podem ficar com width 0 e “sumir”
contentChild:ClearAllPoints()
contentChild:SetPoint("TOPLEFT", 0, 0)
contentChild:SetPoint("TOPRIGHT", 0, 0)

contentScroll:SetScrollChild(contentChild)

-- =========================================================
-- Forward locals (NEEDED for functions declared before assignment)
-- =========================================================
local Pages, SidebarButtons, currentPageKey, RelayoutCallbacks

local function UpdateContentChildWidth()
  local w = contentScroll:GetWidth()
  if not w or w <= 1 then
    w = (content:GetWidth() or 0)
  end
  if not w or w <= 1 then w = 520 end

  -- o contentChild tá preso em TOPLEFT/TOPRIGHT, então ele já pega a largura.
  -- mas manter SetWidth ajuda quando o client tá meio maluco.
  contentChild:SetWidth(w)

  if type(Pages) == "table" then
    for _, p in pairs(Pages) do
      if p and p.SetWidth then
        p:SetWidth(w - 24)
      end
    end
  end
end

local function UpdateContentHeight()
  UpdateContentChildWidth()

  local p = (type(Pages) == "table") and Pages[currentPageKey] or nil
  local viewportH = contentScroll:GetHeight() or 1

  if not p or not p:IsShown() then
    contentChild:SetHeight(viewportH)
    return
  end

  local h = p._contentHeight or viewportH
  contentChild:SetHeight(math.max(h + 40, viewportH))
end

UpdateContentChildWidth()

-- =========================================================
-- Resize handle (bottom-right) - only config window
-- =========================================================
local resize = CreateFrame("Frame", nil, cfg)
resize:SetSize(18, 18)
resize:SetPoint("BOTTOMRIGHT", -2, 2)
resize:EnableMouse(true)

local resizeTex = resize:CreateTexture(nil, "OVERLAY")
resizeTex:SetAllPoints(resize)
resizeTex:SetColorTexture(1,1,1,0.10)

resize:SetScript("OnEnter", function() resizeTex:SetColorTexture(1,1,1,0.18) end)
resize:SetScript("OnLeave", function() resizeTex:SetColorTexture(1,1,1,0.10) end)

local function ClampSize(w, h)
  if w < CFG_MIN_W then w = CFG_MIN_W end
  if h < CFG_MIN_H then h = CFG_MIN_H end
  return w, h
end

resize:SetScript("OnMouseDown", function(_, btn)
  if btn ~= "LeftButton" then return end
  cfg:StartSizing("BOTTOMRIGHT")
end)

resize:SetScript("OnMouseUp", function(_, btn)
  if btn ~= "LeftButton" then return end
  cfg:StopMovingOrSizing()
  local w, h = cfg:GetSize()
  w, h = ClampSize(w, h)
  cfg:SetSize(w, h)
end)

-- =========================================================
-- Page system + UI helpers
-- =========================================================
Pages = {}
SidebarButtons = {}
currentPageKey = nil
RelayoutCallbacks = {}

local function GetContentInnerWidth()
  local w = contentScroll:GetWidth() or 0
  if w <= 0 then return 520 end
  return (w - 48) -- padding + scrollbar folga
end

local function CreatePage(key, title)
  local p = CreateFrame("Frame", nil, contentChild)
  p:Hide()
  p:SetPoint("TOPLEFT", 12, -12)
  p:SetPoint("TOPRIGHT", -12, -12)

  -- ✅ garante que a page tem área (evita “frame 0-height” bugado no scroll)
  p:SetHeight(1)

  local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("TOPLEFT", 0, 0)
  t:SetText(C_MUTED .. title .. C_RESET)

  p._title = t
  Pages[key] = p
  return p
end

local function SetActiveSidebar(btn, active)
  ApplySoftButtonTheme(btn, active)
  if btn._label then
    btn._label:SetTextColor(1,1,1, active and 0.95 or 0.80)
  end
end

local function ShowPage(key)
  for _, p in pairs(Pages) do p:Hide() end
  for _, b in ipairs(SidebarButtons) do SetActiveSidebar(b, false) end

  currentPageKey = key
  if Pages[key] then
    Pages[key]:Show()
  end

  for _, b in ipairs(SidebarButtons) do
    if b._key == key then
      SetActiveSidebar(b, true)
      break
    end
  end

  -- ✅ garante que o scroll child ganha altura DEPOIS de mostrar a page
  UpdateContentHeight()
end

local function CreateSidebarButton(key, text, y)
  local b = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
  b:SetSize(sidebarW - 18, 28)
  b:SetPoint("TOPLEFT", 9, y)
  b:EnableMouse(true)
  b._key = key
  ApplySoftButtonTheme(b, false)

  local l = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  l:SetPoint("LEFT", 10, 0)
  l:SetText(text)
  l:SetTextColor(1,1,1,0.80)
  b._label = l

  b:SetScript("OnEnter", function(self)
    if currentPageKey ~= self._key then self:SetBackdropColor(1,1,1,0.05) end
  end)
  b:SetScript("OnLeave", function(self)
    if currentPageKey ~= self._key then ApplySoftButtonTheme(self, false) end
  end)
  b:SetScript("OnClick", function() ShowPage(key) end)

  table.insert(SidebarButtons, b)
  return b
end

-- =========================================================
-- Flat checkbox (ElvUI-ish)
-- =========================================================
local function CreateFlatCheckbox(parent, labelText)
  local wrap = CreateFrame("Button", nil, parent)
	wrap:SetSize(260, 18)      -- ✅ largura default segura (evita sumir se não ancorar TOPRIGHT)
	wrap:EnableMouse(true)

  local box = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
  box:SetSize(14, 14)
  box:SetPoint("LEFT", 0, 0)
  box:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8x8",
    edgeFile="Interface\\Buttons\\WHITE8x8",
    edgeSize=1,
  })
  box:SetBackdropColor(0,0,0,0.35)
  box:SetBackdropBorderColor(1,1,1,0.14)

  local check = box:CreateTexture(nil, "OVERLAY")
  check:SetPoint("CENTER", 0, 0)
  check:SetSize(10, 10)
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetVertexColor(1,1,1,0.90)
  check:Hide()

  local text = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("LEFT", box, "RIGHT", 8, 0)
  text:SetText(labelText)
  text:SetTextColor(1,1,1,0.85)

  wrap._value = false
  wrap._set = function(self, v)
    self._value = v and true or false
    if self._value then
      check:Show()
      local r,g,b = GetPlayerClassColor()
      box:SetBackdropBorderColor(r,g,b,0.55)
    else
      check:Hide()
      box:SetBackdropBorderColor(1,1,1,0.14)
    end
  end
  wrap._get = function(self) return self._value end

  wrap:SetScript("OnEnter", function()
    box:SetBackdropColor(1,1,1,0.04)
  end)
  wrap:SetScript("OnLeave", function()
    box:SetBackdropColor(0,0,0,0.35)
  end)

  return wrap
end

-- =========================================================
-- UI builder per-page
-- =========================================================
local function NewUI(page)
  local P = page

  local UI = {
    page = P,
    y = -28,
    rowGap = 14,
    elements = {},
    relayout = {},
  }

  local function RegisterRelayout(fn) table.insert(UI.relayout, fn) end
  function UI:AddSpace(px) self.y = self.y - (px or self.rowGap) end

  function UI:AddDivider()
    local line = P:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1,1,1,0.08)
    line:SetPoint("TOPLEFT", 0, self.y)
    line:SetPoint("TOPRIGHT", 0, self.y)
    line:SetHeight(1)
    table.insert(self.elements, line)
    self.y = self.y - 14
  end

  function UI:AddSection(titleText)
    local t = P:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", 0, self.y)
    t:SetText(titleText)
    table.insert(self.elements, t)
    self.y = self.y - 22
  end

  local function Clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
  end

  local function SnapToStep(v, minV, step)
    if not step or step <= 0 then return v end
    local n = math.floor(((v - minV) / step) + 0.5)
    return minV + (n * step)
  end

  function UI:AddSlider(name, label, minV, maxV, step)
    local ebW, ebH = 64, 22
    local gap = 10

    local s = CreateFrame("Slider", name, P, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", 0, self.y)
    s:SetPoint("TOPRIGHT", -ebW - gap, self.y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    if _G[name.."Text"] then _G[name.."Text"]:Hide() end
    if _G[name.."Low"]  then _G[name.."Low"]:Hide()  end
    if _G[name.."High"] then _G[name.."High"]:Hide() end

    local lab = P:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lab:SetPoint("TOP", s, "TOP", 0, 14)
    lab:SetText(label)

    local eb = CreateFrame("EditBox", name.."Value", P, "BackdropTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(ebW, ebH)
    eb:SetTextInsets(6,6,2,2)
    eb:SetPoint("LEFT", s, "RIGHT", gap, 0)
    eb:SetJustifyH("CENTER")
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    ApplyFlatEditTheme(eb)
    eb:SetScript("OnEditFocusGained", function(self) ApplyFlatEditFocus(self, true) end)
    eb:SetScript("OnEditFocusLost",   function(self) ApplyFlatEditFocus(self, false) end)

    local function Format(v)
      if math.abs(v - math.floor(v + 0.5)) < 0.0001 then
        return tostring(math.floor(v + 0.5))
      end
      return string.format("%.2f", v)
    end

    local _updating = false
    local function ApplyValue(v)
      v = tonumber(v) or minV
      v = Clamp(v, minV, maxV)
      v = SnapToStep(v, minV, step)

      _updating = true
      s:SetValue(v)
      eb:SetText(Format(v))
      _updating = false
    end

    s:SetScript("OnValueChanged", function(_, v)
      if _updating then return end
      eb:SetText(Format(v))
    end)

    eb:SetScript("OnEnterPressed", function(self)
      ApplyValue(self:GetText())
      self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
      ApplyValue(self:GetText())
    end)

    s._ApplyValue = ApplyValue
    s._editbox = eb
    ApplyValue(minV)

    table.insert(self.elements, s)
    table.insert(self.elements, lab)
    table.insert(self.elements, eb)

    self.y = self.y - 54
    return s, eb
  end

  function UI:AddFlatCheck(labelText)
  local cb = CreateFlatCheckbox(P, labelText)
  cb:ClearAllPoints()
  cb:SetPoint("TOPLEFT", 0, self.y)
  cb:SetPoint("TOPRIGHT", 0, self.y) -- ✅ estica largura toda
  cb:SetHeight(18)
  table.insert(self.elements, cb)
  self.y = self.y - 24
  return cb
end

  function UI:AddLabelAt(text, x, y)
    local l = P:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", x, y)
    l:SetText(text)
    l:SetTextColor(1,1,1,0.70)
    table.insert(self.elements, l)
    return l
  end

  function UI:AddFlatEditBox(name, w, h, maxLetters)
    local eb = CreateFrame("EditBox", name, P, "BackdropTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(w or 120, h or 22)
    eb:SetMaxLetters(maxLetters or 200)
    eb:SetTextInsets(8,8,3,3)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetJustifyH("LEFT")

    ApplyFlatEditTheme(eb)
    eb:SetScript("OnEditFocusGained", function(self) ApplyFlatEditFocus(self, true) end)
    eb:SetScript("OnEditFocusLost",   function(self) ApplyFlatEditFocus(self, false) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)

    table.insert(self.elements, eb)
    return eb
  end

  function UI:AddSegmented(labelText, leftText, rightText, onToggle)
    local label = P:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, self.y)
    label:SetText(labelText)
    label:SetTextColor(1,1,1,0.75)
    table.insert(self.elements, label)
    self.y = self.y - 18

    local row = CreateFrame("Frame", nil, P)
	row:SetPoint("TOPLEFT", 0, self.y)
	row:SetPoint("TOPRIGHT", 0, self.y)      -- ✅ garante largura
	row:SetHeight(24)
	row:SetWidth(GetContentInnerWidth())

    local bL = CreateFrame("Button", nil, row, "BackdropTemplate")
    bL:SetSize(108, 22)
    bL:SetPoint("LEFT", 0, 0)
    ApplySoftButtonTheme(bL, true)

    local tL = bL:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tL:SetPoint("CENTER", 0, 0)
    tL:SetText(leftText)
    tL:SetTextColor(1,1,1,0.90)

    local bR = CreateFrame("Button", nil, row, "BackdropTemplate")
    bR:SetSize(108, 22)
    bR:SetPoint("LEFT", bL, "RIGHT", 8, 0)
    ApplySoftButtonTheme(bR, false)

    local tR = bR:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tR:SetPoint("CENTER", 0, 0)
    tR:SetText(rightText)
    tR:SetTextColor(1,1,1,0.90)

    row._set = function(_, isLeft)
      ApplySoftButtonTheme(bL, isLeft)
      ApplySoftButtonTheme(bR, not isLeft)
    end

    bL:SetScript("OnClick", function()
      row:_set(true)
      if onToggle then onToggle(true) end
    end)
    bR:SetScript("OnClick", function()
      row:_set(false)
      if onToggle then onToggle(false) end
    end)

    table.insert(self.elements, row)
    self.y = self.y - 32
    return row
  end
  

  local function SkinDropdown(dd)
    if not dd then return end
    local base = dd:GetName()
    if not base then return end

    local btn   = _G[base.."Button"]
    local left  = _G[base.."Left"]
    local mid   = _G[base.."Middle"]
    local right = _G[base.."Right"]

    if left  then left:SetAlpha(0) end
    if mid   then mid:SetAlpha(0) end
    if right then right:SetAlpha(0) end

    if not dd._bg then
      local bg = CreateFrame("Frame", nil, dd, "BackdropTemplate")
      bg:SetPoint("TOPLEFT", 18, -2)
      bg:SetPoint("BOTTOMRIGHT", -18, 6)
      bg:SetFrameLevel(dd:GetFrameLevel() - 1)

      bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
      })
      bg:SetBackdropColor(1,1,1,0.03)
      bg:SetBackdropBorderColor(1,1,1,0.12)

      dd._bg = bg
    end

    if btn then
      btn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
      btn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
      btn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
      btn:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
    end

    local text = _G[base.."Text"]
    if text then
      text:SetTextColor(1,1,1,0.85)
    end
  end

  function UI:AddDropdown(labelText, values, onSelect, width)
    local label = P:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, self.y)
    label:SetText(labelText)
    label:SetTextColor(1,1,1,0.75)
    table.insert(self.elements, label)

    self.y = self.y - 18

    HKDT._ddCounter = (HKDT._ddCounter or 0) + 1
    local ddName = "HKDToasts_DropDown_" .. HKDT._ddCounter

    local dd = CreateFrame("Frame", ddName, P, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", -16, self.y)
    UIDropDownMenu_SetWidth(dd, width or 240)
    SkinDropdown(dd)

    local function SetText(txt) UIDropDownMenu_SetText(dd, txt) end
	
	if not dd then return nil end

    UIDropDownMenu_Initialize(dd, function(self, level)
      for _, v in ipairs(values) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = v.text
        info.checked = function() return (dd._value == v.value) end
        info.func = function()
          dd._value = v.value
          SetText(v.text)
          if onSelect then onSelect(v.value, v.text) end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)

    dd._SetText = SetText

    table.insert(self.elements, dd)
    self.y = self.y - 40
    return dd
  end

  local function MakeSwatch(labelText)
    local wrap = CreateFrame("Frame", nil, P)
    wrap:SetSize(1, 1)

    local lab = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lab:SetPoint("TOP", 0, 0)
    lab:SetText(labelText)
    lab:SetTextColor(1,1,1,0.70)

    local btn = CreateFrame("Button", nil, wrap, "BackdropTemplate")
    btn:SetSize(18, 18)
    btn:SetPoint("TOP", lab, "BOTTOM", 0, -6)
    btn:EnableMouse(true)

    btn:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    btn:SetBackdropColor(0,0,0,1)
    btn:SetBackdropBorderColor(1,1,1,0.30)

    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(btn)
    tex:SetColorTexture(1,1,1,1)
    btn._tex = tex

    return wrap, btn
  end

  function UI:AddSwatchRow(items, gap)
    gap = gap or 8
    local n = #items

    local row = CreateFrame("Frame", nil, P)
    row:SetPoint("TOPLEFT", 0, self.y)
    row:SetPoint("TOPRIGHT", 0, self.y)
    row:SetHeight(44)

    local wraps = {}

    local function RelayoutSwatches()
      local totalW = GetContentInnerWidth()
      local colW = math.floor((totalW - ((n-1) * gap)) / n)
      if colW < 46 then colW = 46 end

      for i = 1, n do
        local wrap = wraps[i]
        wrap:SetSize(colW, 44)
        wrap:ClearAllPoints()
        if i == 1 then
          wrap:SetPoint("TOPLEFT", 0, 0)
        else
          wrap:SetPoint("TOPLEFT", (i-1) * (colW + gap), 0)
        end
      end
    end

    for i, it in ipairs(items) do
      local wrap, btn = MakeSwatch(it.label)
      wrap:SetParent(row)
      wraps[i] = wrap
      btn:SetScript("OnClick", it.onClick)
      it._btn = btn
    end

    RelayoutSwatches()
    RegisterRelayout(RelayoutSwatches)

    table.insert(self.elements, row)
    self.y = self.y - 54
    return items, row
  end

  function UI:RunRelayout()
    for _, fn in ipairs(self.relayout) do pcall(fn) end
  end

  table.insert(RelayoutCallbacks, function() UI:RunRelayout() end)
  return UI
end

-- =========================================================
-- Color picker helper
-- =========================================================
local function OpenBGColorPicker(bg, onChange)
  local db = HKDT.DB
  if db and db.bg then bg = db.bg end
  if not bg then return end

  bg.a = (bg.a ~= nil) and bg.a or 0.92
  local prev = { r = bg.r or 0, g = bg.g or 0, b = bg.b or 0, a = bg.a or 1 }

  -- ---------- Compat Get RGB ----------
  local function CP_GetRGB()
    if ColorPickerFrame.GetColorRGB then
      return ColorPickerFrame:GetColorRGB()
    end
    local cp = ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker
    if cp and cp.GetColorRGB then
      return cp:GetColorRGB()
    end
    return 1,1,1
  end

  -- ---------- Compat Get Alpha/Opacity ----------
  local function CP_GetA()
    -- Retail: alpha direto
    if ColorPickerFrame.GetColorAlpha then
      local a = ColorPickerFrame:GetColorAlpha()
      if type(a) == "number" then
        if a < 0 then a = 0 end
        if a > 1 then a = 1 end
        return a
      end
    end

    -- Legacy: slider é "opacity" (0 opaco -> 1 transparente)
    local opacity
    if ColorPickerFrame.opacitySlider and ColorPickerFrame.opacitySlider.GetValue then
      opacity = ColorPickerFrame.opacitySlider:GetValue()
    elseif ColorPickerFrame.Content and ColorPickerFrame.Content.OpacitySliderFrame
       and ColorPickerFrame.Content.OpacitySliderFrame.GetValue then
      opacity = ColorPickerFrame.Content.OpacitySliderFrame:GetValue()
    elseif OpacitySliderFrame and OpacitySliderFrame.GetValue then
      opacity = OpacitySliderFrame:GetValue()
    elseif ColorPickerFrame.opacity ~= nil then
      opacity = ColorPickerFrame.opacity
    else
      opacity = 0
    end

    if opacity < 0 then opacity = 0 end
    if opacity > 1 then opacity = 1 end
    return 1 - opacity
  end

  local function Apply()
    local r, g, b = CP_GetRGB()
    local a = CP_GetA()
    bg.r, bg.g, bg.b, bg.a = r, g, b, a

    if onChange then onChange(r, g, b, a) end
    if HKDT.RefreshActiveStyle then HKDT.RefreshActiveStyle() end
  end

  local function Cancel()
    bg.r, bg.g, bg.b, bg.a = prev.r, prev.g, prev.b, prev.a
    if onChange then onChange(bg.r, bg.g, bg.b, bg.a) end
    if HKDT.RefreshActiveStyle then HKDT.RefreshActiveStyle() end
  end

  -- ---------- Open ----------
  if ColorPickerFrame.SetupColorPickerAndShow then
    local usesAlphaAPI = (ColorPickerFrame.GetColorAlpha ~= nil)

    local info = {
      r = bg.r or 0, g = bg.g or 0, b = bg.b or 0,
      -- ✅ Se o client expõe GetColorAlpha, trata “opacity” como alpha pra não inverter.
      -- ✅ Se não expõe, assume legacy: “opacity” = 1 - alpha.
      opacity = usesAlphaAPI and (bg.a or 1) or (1 - (bg.a or 1)),
      hasOpacity = true,
      swatchFunc = Apply,
      opacityFunc = Apply,
      cancelFunc = Cancel,
    }

    ColorPickerFrame:SetupColorPickerAndShow(info)
    return
  end

  -- Legacy fallback (bem antigo)
  ColorPickerFrame:Hide()
  ColorPickerFrame.hasOpacity = true
  ColorPickerFrame.opacity = 1 - (bg.a or 1)
  ColorPickerFrame.previousValues = { prev.r, prev.g, prev.b, 1 - (prev.a or 1) }
  ColorPickerFrame.func = Apply
  ColorPickerFrame.opacityFunc = Apply
  ColorPickerFrame.cancelFunc = Cancel

  if ColorPickerFrame.SetColorRGB then
    ColorPickerFrame:SetColorRGB(bg.r or 0, bg.g or 0, bg.b or 0)
  elseif ColorPickerFrame_SetColorRGB then
    ColorPickerFrame_SetColorRGB(bg.r or 0, bg.g or 0, bg.b or 0)
  end

  ColorPickerFrame:Show()
end

-- =========================================================
-- Build pages (✅ no Reminders tab)
-- =========================================================
CreateSidebarButton("general", "General", -12)
CreateSidebarButton("modules", "Modules", -46)

local pGeneral = CreatePage("general", "General")
local pModules = CreatePage("modules", "Modules")

-- =========================================================
-- GENERAL PAGE
-- =========================================================
local UIG = NewUI(pGeneral)

local sScale = UIG:AddSlider("HKDToastsScale", "Scale", 0.7, 1.5, 0.05)
local sDur   = UIG:AddSlider("HKDToastsDur",   "Duration", 1.0, 6.0, 0.1)
local sWidth = UIG:AddSlider("HKDToastsWidth", "Width", 260, 560, 5)
local sMax   = UIG:AddSlider("HKDToastsMax",   "Max Visible", 1, 6, 1)

UIG:AddDivider()
UIG:AddSection(C_MUTED .. "Style" .. C_RESET)

local cbCompact  = UIG:AddFlatCheck("Compact layout (single-line)")
local cbStreamer = UIG:AddFlatCheck("Streamer mode (hide message + realms)")

UIG:AddSpace(8)

local segIconSide = UIG:AddSegmented("Icon side", "Left", "Right", function(isLeft)
  local db = DB(); if not db then return end
  db.layout = db.layout or CopyDefaults(DEFAULTS.layout, {})
  db.layout.iconSide = isLeft and "LEFT" or "RIGHT"
  for _, fr in ipairs(Active) do
    ApplyLayout(fr)
    SetFramePosition(fr)
  end
  RefreshAnchor()
  Reflow()
end)


local WOW_LOCKED_WIDTH     = 260 -- TWW Dark/Light + Journey
local NOFRAME_LOCKED_WIDTH = 320 -- Transparent (NOFRAME)


-- =========================================================
-- Skins preset (single dropdown)
-- - Modern Flat
-- - TWW Dark
-- - TWW Light
-- (Drives legacy fields: layout.iconPack, layout.toastSkin, layout.wowVariant)
-- =========================================================
local SKIN_PRESETS = {
  { text = "Modern Flat", value = "MODERN_FLAT" },
  { text = "TWW Dark",    value = "TWW_DARK" },
  { text = "TWW Light",   value = "TWW_LIGHT" },
  { text = "Journey",     value = "JOURNEY" },
  { text = "Evergreen",   value = "EVERGREEN" },
  { text = "Line",        value = "LINE" },
  { text = "Transparent", value = "NOFRAME" },

}

local function InferSkinPreset(db)
  db.layout = db.layout or CopyDefaults(DEFAULTS.layout, {})

  -- If already set, respect it
  if db.layout.skinPreset and db.layout.skinPreset ~= "" then
    return db.layout.skinPreset
  end

  -- Infer from legacy fields (safe migration)
  local toastSkin  = db.layout.toastSkin or "MODERN"
  local iconPack   = db.layout.iconPack  or "WOW"
  local wowVariant = db.layout.wowVariant or "DARK"
  if toastSkin == "JOURNEY" then
    return "JOURNEY"
  end
  
    if toastSkin == "NOFRAME" then
    return "NOFRAME"
  end
  
  if toastSkin == "EVERGREEN" then
    return "EVERGREEN"
  end

  if toastSkin == "LINE" then
    return "LINE"
  end

  if toastSkin == "WOW" then
    if wowVariant == "LIGHT" then return "TWW_LIGHT" end
    return "TWW_DARK"
  end

  -- Modern defaults to Flat (as requested)
  return "MODERN_FLAT"
end

local function ApplySkinPreset(preset)
  local db = DB(); if not db then return end
  db.layout = db.layout or CopyDefaults(DEFAULTS.layout, {})

  preset = preset or InferSkinPreset(db)
  db.layout.skinPreset = preset

  -- helper: lock width and remember previous once
  local function LockWidthTo(w)
    db.layout._widthBeforeSkinLock = db.layout._widthBeforeSkinLock or db.width
    db.width = w
  end

  local function UnlockWidth()
    if db.layout._widthBeforeSkinLock then
      db.width = db.layout._widthBeforeSkinLock
      db.layout._widthBeforeSkinLock = nil
    end
  end

  if preset == "MODERN_FLAT" then
    db.layout.iconPack   = "FLAT"
    db.layout.toastSkin  = "MODERN"
    db.layout.wowVariant = "DARK" -- irrelevante
    UnlockWidth()

  elseif preset == "TWW_DARK" or preset == "TWW_LIGHT" then
    db.layout.iconPack   = "WOW"
    db.layout.toastSkin  = "WOW"
    db.layout.wowVariant = (preset == "TWW_LIGHT") and "LIGHT" or "DARK"
    LockWidthTo(WOW_LOCKED_WIDTH)

  elseif preset == "JOURNEY" then
    db.layout.iconPack   = "WOW"
    db.layout.toastSkin  = "JOURNEY"
    db.layout.wowVariant = "DARK" -- irrelevante
    LockWidthTo(WOW_LOCKED_WIDTH)

  elseif preset == "NOFRAME" then
    db.layout.iconPack   = "FLAT"
    db.layout.toastSkin  = "NOFRAME"
    db.layout.wowVariant = "DARK"
    LockWidthTo(NOFRAME_LOCKED_WIDTH)
	
  elseif preset == "EVERGREEN" then
    db.layout.iconPack   = "WOW"          -- ou "FLAT" se preferir
    db.layout.toastSkin  = "EVERGREEN"    -- precisa existir no ToastSystem
    db.layout.wowVariant = "DARK"
    -- decide se trava width ou não (recomendação: NÃO travar)
    -- UnlockWidth()

  elseif preset == "LINE" then
    db.layout.iconPack   = "FLAT"          
    db.layout.toastSkin  = "LINE"         -- precisa existir no ToastSystem
    db.layout.wowVariant = "DARK"
    -- se Line for “só linhas top/bottom” eu recomendo travar width:
    -- LockWidthTo(320)	

  else
    -- safety fallback
    db.layout.skinPreset = "MODERN_FLAT"
    db.layout.iconPack   = "FLAT"
    db.layout.toastSkin  = "MODERN"
    db.layout.wowVariant = "DARK"
    UnlockWidth()
  end

  -- sync slider
  if sWidth and sWidth._ApplyValue then
    sWidth._ApplyValue(db.width)
  end
  if RefreshWidthControlState then RefreshWidthControlState() end

  -- apply to frames
  for _, fr in ipairs(Active) do
    ApplyLayout(fr)
    SetFramePosition(fr)
  end
  RefreshAnchor()
  Reflow()

  if HKDT.RefreshActiveStyle then HKDT.RefreshActiveStyle() end
  if HKDT.RefreshActiveText  then HKDT.RefreshActiveText()  end
end

-- UI: dropdown
UIG:AddSpace(6)
local ddSkin = UIG:AddDropdown("Skins", SKIN_PRESETS, function(val)
  ApplySkinPreset(val)
end, 240)







-- Animations dropdown
local animValues = {
  { text = "Fade",                   value = "FADE" },
  { text = "Fade + Slide Up",         value = "FADE_SLIDE_UP" },
  { text = "Fade + Slide Down",       value = "FADE_SLIDE_DOWN" },
  { text = "Fade + Slide from Left",  value = "FADE_SLIDE_LEFT" },
  { text = "Fade + Slide from Right", value = "FADE_SLIDE_RIGHT" },
  { text = "Grow",                    value = "GROW" },
}
local ddAnim = UIG:AddDropdown("Animation style", animValues, function(val)
  local db = DB(); if not db then return end
  db.animations = db.animations or CopyDefaults(DEFAULTS.animations, {})
  db.animations.mode = val
end, 240)

local segGrow = UIG:AddSegmented("Grow direction", "Up", "Down", function(isUp)
  local db = DB(); if not db then return end
  db.grow = isUp and "UP" or "DOWN"
  Reflow()
end)

UIG:AddDivider()
UIG:AddSection(C_MUTED .. "Colors" .. C_RESET)

local swRow
swRow = select(1, UIG:AddSwatchRow({
  { label="Whisper", onClick=function()
      local db = DB(); if not db then return end
      OpenColorPicker(db.colors.whisper, function(r,g,b)
        db.colors.whisper.r, db.colors.whisper.g, db.colors.whisper.b = r,g,b
        swRow[1]._btn._tex:SetColorTexture(r,g,b,1)
        RefreshActiveStyle()
      end)
    end
  },
  { label="BNet", onClick=function()
      local db = DB(); if not db then return end
      OpenColorPicker(db.colors.bnet, function(r,g,b)
        db.colors.bnet.r, db.colors.bnet.g, db.colors.bnet.b = r,g,b
        swRow[2]._btn._tex:SetColorTexture(r,g,b,1)
        RefreshActiveStyle()
      end)
    end
  },
  { label="Mail", onClick=function()
      local db = DB(); if not db then return end
      OpenColorPicker(db.colors.mail, function(r,g,b)
        db.colors.mail.r, db.colors.mail.g, db.colors.mail.b = r,g,b
        swRow[3]._btn._tex:SetColorTexture(r,g,b,1)
        RefreshActiveStyle()
      end)
    end
  },
  { label="Vault", onClick=function()
      local db = DB(); if not db then return end
      OpenColorPicker(db.colors.vault, function(r,g,b)
        db.colors.vault.r, db.colors.vault.g, db.colors.vault.b = r,g,b
        swRow[4]._btn._tex:SetColorTexture(r,g,b,1)
        RefreshActiveStyle()
      end)
    end
  },
  { label="Daily", onClick=function()
      local db = DB(); if not db then return end
      OpenColorPicker(db.colors.daily, function(r,g,b)
        db.colors.daily.r, db.colors.daily.g, db.colors.daily.b = r,g,b
        swRow[5]._btn._tex:SetColorTexture(r,g,b,1)
        RefreshActiveStyle()
      end)
    end
  },
  { label="Reminder", onClick=function()
      local db = DB(); if not db then return end
      OpenColorPicker(db.colors.reminder, function(r,g,b)
        db.colors.reminder.r, db.colors.reminder.g, db.colors.reminder.b = r,g,b
        swRow[6]._btn._tex:SetColorTexture(r,g,b,1)
        RefreshActiveStyle()
      end)
    end
  },
  { label="Key", onClick=function()
      local db = DB(); if not db then return end
      OpenColorPicker(db.colors.key, function(r,g,b)
        db.colors.key.r, db.colors.key.g, db.colors.key.b = r,g,b
        swRow[7]._btn._tex:SetColorTexture(r,g,b,1)
        RefreshActiveStyle()
      end)
    end
  },
  { label="BG", onClick=function()
    local db = DB(); if not db then return end
    db.bg = db.bg or { r = 0, g = 0, b = 0, a = 0.85 }

    OpenBGColorPicker(db.bg, function(r,g,b,a)
  db.bg.r, db.bg.g, db.bg.b, db.bg.a = r,g,b,a
  swRow[8]._btn._tex:SetColorTexture(db.bg.r, db.bg.g, db.bg.b, db.bg.a or 1)
  RefreshActiveStyle()
end)
  end
},
}, 6))

UIG:AddDivider()
UIG:AddSection(C_MUTED .. "Sound" .. C_RESET)
local cbSound = UIG:AddFlatCheck("Enable sounds")

-- =========================================================
-- MODULES PAGE
-- =========================================================
local UIM = NewUI(pModules)
UIM:AddSection(C_MUTED .. "Modules" .. C_RESET)

local cbVault   = UIM:AddFlatCheck("Great Vault")
local cbReset   = UIM:AddFlatCheck("Daily Reset")
local cbRem     = UIM:AddFlatCheck("Custom Reminders")
local cbDura    = UIM:AddFlatCheck("Durability (70/30/10)")
local cbBags    = UIM:AddFlatCheck("Bags (Almost Full / Full)")
local cbFriends = UIM:AddFlatCheck("Friends Online/Offline")
local cbKeys    = UIM:AddFlatCheck("Mythic+ Keys (New Key)")

-- =========================================================
-- REMINDERS PANEL (docked)
-- =========================================================
local remUI = { y = -34 }

local function RemAddLabel(text, x, y)
  local l = remPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  l:SetPoint("TOPLEFT", x, y)
  l:SetText(text)
  l:SetTextColor(1,1,1,0.70)
  return l
end

local function RemFlatEdit(name, w, h, maxLetters)
  local eb = CreateFrame("EditBox", name, remPanel, "BackdropTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(w or 120, h or 22)
  eb:SetMaxLetters(maxLetters or 200)
  eb:SetTextInsets(8,8,3,3)
  eb:SetFontObject("GameFontHighlightSmall")
  eb:SetJustifyH("LEFT")
  ApplyFlatEditTheme(eb)
  eb:SetScript("OnEditFocusGained", function(self) ApplyFlatEditFocus(self, true) end)
  eb:SetScript("OnEditFocusLost",   function(self) ApplyFlatEditFocus(self, false) end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
  return eb
end

local function RemFlatButton(text, onClick)
  local b = CreateFrame("Button", nil, remPanel, "BackdropTemplate")
  b:SetSize(100, 22)
  ApplySoftButtonTheme(b, false)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetText(text)
  fs:SetTextColor(1,1,1,0.90)

  b:SetScript("OnEnter", function(self) self:SetBackdropColor(1,1,1,0.06) end)
  b:SetScript("OnLeave", function(self) ApplySoftButtonTheme(self, false) end)
  b:SetScript("OnClick", function() if onClick then onClick() end end)
  return b
end

-- Add Reminder section
local remSec = remPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
remSec:SetPoint("TOPLEFT", 12, -38)
remSec:SetText(C_MUTED .. "Add Reminder" .. C_RESET)

RemAddLabel("Minutes", 12, -60)
RemAddLabel("Message", 90, -60)

local ebMin = RemFlatEdit("HKDToastsRemMin", 64, 22, 6)
ebMin:SetPoint("TOPLEFT", 12, -76)

local ebMsg = RemFlatEdit("HKDToastsRemMsg", 1, 22, 200)
ebMsg:SetPoint("TOPLEFT", 90, -76)
ebMsg:SetPoint("TOPRIGHT", -12, -76)

local cbInf = CreateFlatCheckbox(remPanel, "Repeat until turn off")
cbInf:ClearAllPoints()
cbInf:SetPoint("TOPLEFT", 12, -106)
cbInf:SetPoint("TOPRIGHT", -12, -106) -- ✅ prende dentro do painel
cbInf:SetHeight(18)

-- agora o Repeat X fica abaixo (alinhado com Minutes)
RemAddLabel("Repeat X times", 12, -132)
local ebRep = RemFlatEdit("HKDToastsRemRep", 64, 22, 6)
ebRep:ClearAllPoints()
ebRep:SetPoint("TOPLEFT", 12, -148)

-- ✅ faz o toggle funcionar e evita confusão visual
cbInf:_set(true) -- default: repeat until turn off (∞)

local function SyncRepeatUI()
  local infinite = cbInf:_get()
  if infinite then
    ebRep:SetText("")
    ebRep:ClearFocus()
    ebRep:EnableMouse(false)
    ebRep:SetAlpha(0.35)
  else
    ebRep:EnableMouse(true)
    ebRep:SetAlpha(1.0)
  end
end

cbInf:SetScript("OnClick", function(self)
  self:_set(not self:_get())
  SyncRepeatUI()
end)

SyncRepeatUI()

local addBtn = RemFlatButton("Add", function()
  local db = DB(); if not db then return end
  db.reminders = db.reminders or {}

  local mins = tonumber(ebMin:GetText() or "")
  local text = ebMsg:GetText() or ""
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  if not mins or mins <= 0 then
    print("HKDToasts: invalid minutes.")
    return
  end
  if text == "" then
    print("HKDToasts: message cannot be empty.")
    return
  end

  local repeats = 0
  if not cbInf:_get() then
    repeats = tonumber(ebRep:GetText() or "") or 0
    if repeats < 0 then repeats = 0 end
  end

  table.insert(db.reminders, {
    enabled = true,
    minutes = mins,
    text = text,
    last = GetTime(),
    repeats = repeats,
    remaining = (repeats > 0) and repeats or 0,
  })

  EnsureReminderTicker()
  if cfg._RebuildReminderRows then cfg._RebuildReminderRows(true) end
end)

local clearBtn = RemFlatButton("Clear", function()
  ebMin:SetText("")
  ebMsg:SetText("")
  ebRep:SetText("")
  cbInf:_set(true)
  SyncRepeatUI()
end)

addBtn:SetPoint("TOPLEFT", 12, -182)
clearBtn:SetPoint("TOPRIGHT", -12, -182)

-- List title
local listTitle = remPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
listTitle:SetPoint("TOPLEFT", 12, -214)
listTitle:SetText(C_MUTED .. "Reminders" .. C_RESET)

-- Scroll list (✅ inset so it doesn't bleed into gap)
local reminderScroll = CreateFrame("ScrollFrame", "HKDToastsReminderScroll", remPanel, "UIPanelScrollFrameTemplate")
reminderScroll:SetPoint("TOPLEFT", 12, -234)
reminderScroll:SetPoint("BOTTOMRIGHT", -12, 12)

local sb2 = _G[reminderScroll:GetName() .. "ScrollBar"]
if sb2 then
  sb2:ClearAllPoints()
  sb2:SetPoint("TOPRIGHT", -2, -18)
  sb2:SetPoint("BOTTOMRIGHT", -2, 18)
end

local reminderList = CreateFrame("Frame", nil, reminderScroll)
reminderList:SetSize(1, 1)
reminderScroll:SetScrollChild(reminderList)

local reminderRows = {}

local function Trunc(s, n)
  if not s then return "" end
  if #s <= n then return s end
  return string.sub(s, 1, n-3) .. "..."
end

local function UpdateReminderListLayout()
  local w = reminderScroll:GetWidth() or 0
  if w <= 0 then w = remindersW - 24 end
  local listW = w - 26
  if listW < 160 then listW = 160 end
  reminderList:SetWidth(listW)
  for _, row in ipairs(reminderRows) do
    if row and row:IsShown() then row:SetWidth(listW) end
  end
  reminderScroll:UpdateScrollChildRect()
end

local function RebuildReminderRows(forceStructure)
  local db = DB()
  if not db or not db.reminders then
    for _, r in ipairs(reminderRows) do if r then r:Hide() end end
    wipe(reminderRows)
    reminderList:SetHeight(1)
    UpdateReminderListLayout()
    return
  end

  local rowH = 22
  local y = 0
  local listW = (reminderList:GetWidth() or 220)

  for i = 1, #db.reminders do
    local row = reminderRows[i]
    if not row then
      row = CreateFrame("Frame", nil, reminderList)
      row:SetHeight(rowH)

      local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", 0, 0)
      fs:SetTextColor(1,1,1,0.85)
      row._fs = fs

      local bT = CreateFrame("Button", nil, row, "BackdropTemplate")
      bT:SetSize(46, rowH)
      bT:SetPoint("RIGHT", -54, 0)
      ApplySoftButtonTheme(bT, false)
      local t = bT:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      t:SetPoint("CENTER", 0, 0)
      t:SetTextColor(1,1,1,0.9)
      bT._txt = t
      row._bT = bT

      local bD = CreateFrame("Button", nil, row, "BackdropTemplate")
      bD:SetSize(46, rowH)
      bD:SetPoint("RIGHT", 0, 0)
      ApplySoftButtonTheme(bD, false)
      local d = bD:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      d:SetPoint("CENTER", 0, 0)
      d:SetText("DEL")
      d:SetTextColor(1,1,1,0.9)
      row._bD = bD

      reminderRows[i] = row
    end

    row:Show()
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetWidth(listW)

    local data = db.reminders[i]

    local repText
    if data.repeats and tonumber(data.repeats) and tonumber(data.repeats) > 0 then
      repText = string.format(" (%d left)", tonumber(data.remaining) or 0)
    else
      repText = " (∞)"
    end

    row._fs:SetText(string.format("%d) %sm | %s%s",
      i,
      tostring(data.minutes or "?"),
      Trunc(data.text or "", 38),
      repText
    ))

    local function RefreshToggleLabel()
      local on = db.reminders[i] and db.reminders[i].enabled
      row._bT._txt:SetText(on and "ON" or "OFF")
      ApplySoftButtonTheme(row._bT, on and true or false)
    end
    RefreshToggleLabel()

    row._bT:SetScript("OnClick", function()
      if not db.reminders[i] then return end
      db.reminders[i].enabled = not db.reminders[i].enabled

      if db.reminders[i].enabled then
        db.reminders[i].last = GetTime()
        if db.reminders[i].repeats and tonumber(db.reminders[i].repeats) and tonumber(db.reminders[i].repeats) > 0 then
          db.reminders[i].remaining = tonumber(db.reminders[i].repeats)
        end
      end

      EnsureReminderTicker()
      RebuildReminderRows(false)
    end)

    row._bD:SetScript("OnClick", function()
      table.remove(db.reminders, i)
      EnsureReminderTicker()
      RebuildReminderRows(true)
    end)

    y = y + rowH + 6
  end

  for i = #db.reminders + 1, #reminderRows do
    if reminderRows[i] then reminderRows[i]:Hide() end
  end

  reminderList:SetHeight(math.max(1, y))
  UpdateReminderListLayout()
end

cfg._RebuildReminderRows = RebuildReminderRows

-- =========================================================
-- Wiring / Apply
-- =========================================================
local function ApplyModuleToggles()
  local db = DB(); if not db then return end
  db.modules = db.modules or {}

  local wasFriends = db.modules.friends and true or false

  db.modules.vault      = cbVault:_get() and true or false
  db.modules.dailyReset = cbReset:_get() and true or false
  db.modules.reminders  = cbRem:_get() and true or false
  db.modules.durability = cbDura:_get() and true or false
  db.modules.bags       = cbBags:_get() and true or false
  db.modules.friends    = cbFriends:_get() and true or false
  db.modules.keys       = cbKeys:_get() and true or false

  local nowFriends = db.modules.friends and true or false

  db.sounds = db.sounds or CopyDefaults(DEFAULTS.sounds, {})
  db.sounds.enabled = cbSound:_get() and true or false

  HKDT.UpdateEventRegistrations()

  if HKDT.Bags_SetBaseline then
    HKDT.Bags_SetBaseline()
  end

  if (not wasFriends) and nowFriends then
    ApplyFriendToastSuppression(true)
  elseif wasFriends and (not nowFriends) then
    Friends_ResetCache()
    HKDT.ShowReloadPopup()

    if db.modules.keys and HKDT.Keys_SetBaseline then
      HKDT.Keys_SetBaseline()
    end
  else
    ApplyFriendToastSuppression(nowFriends)
  end

  ScheduleDailyReset()
  EnsureReminderTicker()
  CheckVaultAndNotify()
end

local function HookFlatCheck(cb, fn)
  cb:SetScript("OnClick", function(self)
    self:_set(not self:_get())
    if fn then fn(self:_get()) end
  end)
end

HookFlatCheck(cbVault,   ApplyModuleToggles)
HookFlatCheck(cbReset,   ApplyModuleToggles)
HookFlatCheck(cbRem,     ApplyModuleToggles)
HookFlatCheck(cbDura,    ApplyModuleToggles)
HookFlatCheck(cbBags,    ApplyModuleToggles)
HookFlatCheck(cbFriends, ApplyModuleToggles)
HookFlatCheck(cbKeys,    ApplyModuleToggles)

HookFlatCheck(cbSound, function()
  ApplyModuleToggles()
end)

HookFlatCheck(cbStreamer, function(on)
  local db = DB(); if not db then return end
  db.layout = db.layout or CopyDefaults(DEFAULTS.layout, {})
  db.layout.streamerMode = on and true or false

  if HKDT.RefreshActiveText then
    HKDT.RefreshActiveText()
  else
    for _, fr in ipairs(Active) do
      if fr and HKDT.UpdateText then
        HKDT.UpdateText(fr, fr._kind, fr._author, fr._msgText, fr._meta)
      end
    end
  end
end)

HookFlatCheck(cbCompact, function(on)
  local db = DB(); if not db then return end
  db.layout = db.layout or CopyDefaults(DEFAULTS.layout, {})

  db.layout.compact = on and true or false
  db.layout._widthNormal  = db.layout._widthNormal  or db.width or DEFAULTS.width or 360
  db.layout._widthCompact = db.layout._widthCompact or 320

  if db.layout.compact then
    db.layout._widthNormal = db.width
    db.width = db.layout._widthCompact
  else
    db.width = db.layout._widthNormal or db.width
  end

  if sWidth and sWidth._ApplyValue then
    sWidth._ApplyValue(db.width)
  end

  for _, fr in ipairs(Active) do
    ApplyLayout(fr)
    SetFramePosition(fr)
  end
  RefreshAnchor()
  Reflow()
end)

local function CanonFontName(name)
  if not name then return "" end
  local n = name:lower()
  if n:find("friz") and n:find("quadr") then
    return "Friz Quadrata"
  end
  return name
end

local function RefreshFontDropdown()
  if not ddFont then return end -- ✅ evita UIDropDownMenu_Initialize(nil,...)
  local db = DB(); if not db then return end
  db.layout = db.layout or CopyDefaults(DEFAULTS.layout, {})

  local fonts = GetFontListSafe()
  local values, seen = {}, {}

  for _, raw in ipairs(fonts or {}) do
    local name = CanonFontName(raw)
    if name ~= "" and not seen[name] then
      seen[name] = true
      values[#values+1] = { text = name, value = name }
    end
  end

  table.sort(values, function(a,b) return a.text < b.text end)

  UIDropDownMenu_Initialize(ddFont, function(self, level)
    for _, v in ipairs(values) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = v.text
      info.checked = (ddFont._value == v.value)
      info.func = function()
        ddFont._value = v.value
        UIDropDownMenu_SetText(ddFont, v.text)

        local db2 = DB(); if not db2 then return end
        db2.layout = db2.layout or CopyDefaults(DEFAULTS.layout, {})

        db2.layout.font = v.value
        db2.layout.fontPath = nil -- ✅ NÃO salvar path

        for _, fr in ipairs(Active) do
          ApplyToastFont(fr)
        end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  local selected = CanonFontName(db.layout.font or "GameFontNormal")
  ddFont._value = selected
  UIDropDownMenu_SetText(ddFont, selected)
end




local function SetSliderEnabled(slider, enabled, lockedText)
  if not slider then return end
  local eb = slider._editbox

  local a = enabled and 1.0 or 0.35
  slider:SetAlpha(a)
  if slider.EnableMouse then slider:EnableMouse(enabled) end
  if slider.Enable then
    if enabled then slider:Enable() else slider:Disable() end
  end

  local name = slider.GetName and slider:GetName()
  if name then
    local thumb = _G[name.."Thumb"]
    if thumb then thumb:SetAlpha(enabled and 1.0 or 0.25) end
  end

  if eb then
    eb:SetAlpha(a)
    if eb.ClearFocus then eb:ClearFocus() end
    if eb.EnableMouse then eb:EnableMouse(enabled) end
    if eb.Enable then
      if enabled then eb:Enable() else eb:Disable() end
    end
    if not enabled and lockedText then
      eb:SetText(lockedText)
    end
  end
end

local function IsWidthLockedSkin()
  local db = DB()
  if not (db and db.layout) then return false end
  local s = db.layout.toastSkin
  return (s == "WOW" or s == "JOURNEY" or s == "NOFRAME")
end

RefreshWidthControlState = function()
  if not sWidth then return end
  if IsWidthLockedSkin() then
    SetSliderEnabled(sWidth, false, "Locked")
  else
    SetSliderEnabled(sWidth, true)
  end
end

local function RefreshConfig()
  local db = DB(); if not db then return end
  ApplyConfigTheme(cfg)
  
  -- Skins preset (sync UI + apply legacy fields safely)
local preset = InferSkinPreset(db)
ApplySkinPreset(preset)

if ddSkin then
  ddSkin._value = preset
  -- set dropdown text
  local txt = "Modern Flat"
  if preset == "TWW_DARK" then txt = "TWW Dark"
  elseif preset == "TWW_LIGHT" then txt = "TWW Light"
   elseif preset == "JOURNEY" then txt = "Journey"
   elseif preset == "EVERGREEN" then txt = "Evergreen"
  elseif preset == "LINE" then txt = "Line"
  elseif preset == "NOFRAME" then txt = "Transparent"
  end
  if ddSkin._SetText then ddSkin._SetText(txt) end
end

  
  if RefreshWowVariantControlState then RefreshWowVariantControlState() end
  db.animations = CopyDefaults(DEFAULTS.animations, db.animations or {})
  db.sounds = db.sounds or CopyDefaults(DEFAULTS.sounds, {})

  sScale._ApplyValue(db.scale)
  sDur._ApplyValue(db.duration)
  sWidth._ApplyValue(db.width)
  sMax._ApplyValue(db.maxVisible or 3)

  cbCompact:_set(db.layout and db.layout.compact)
  cbStreamer:_set(db.layout and db.layout.streamerMode)

  segIconSide:_set((db.layout.iconSide or "LEFT") ~= "RIGHT")

  if ddFont then RefreshFontDropdown() end


  do
    local map = {
      FADE = "Fade",
      FADE_SLIDE_UP = "Fade + Slide Up",
      FADE_SLIDE_DOWN = "Fade + Slide Down",
      FADE_SLIDE_LEFT = "Fade + Slide from Left",
      FADE_SLIDE_RIGHT = "Fade + Slide from Right",
      GROW = "Grow",
    }
    local key = db.animations.mode or "FADE_SLIDE_UP"
    ddAnim._value = key
    if ddAnim._SetText then ddAnim._SetText(map[key] or "Fade + Slide Up") end
  end

  segGrow:_set((db.grow or "DOWN") == "UP")

  swRow[1]._btn._tex:SetColorTexture(db.colors.whisper.r, db.colors.whisper.g, db.colors.whisper.b, 1)
  swRow[2]._btn._tex:SetColorTexture(db.colors.bnet.r, db.colors.bnet.g, db.colors.bnet.b, 1)
  swRow[3]._btn._tex:SetColorTexture(db.colors.mail.r, db.colors.mail.g, db.colors.mail.b, 1)
  swRow[4]._btn._tex:SetColorTexture(db.colors.vault.r, db.colors.vault.g, db.colors.vault.b, 1)
  swRow[5]._btn._tex:SetColorTexture(db.colors.daily.r, db.colors.daily.g, db.colors.daily.b, 1)
  swRow[6]._btn._tex:SetColorTexture(db.colors.reminder.r, db.colors.reminder.g, db.colors.reminder.b, 1)
  swRow[7]._btn._tex:SetColorTexture(db.colors.key.r, db.colors.key.g, db.colors.key.b, 1)
  swRow[8]._btn._tex:SetColorTexture(db.bg.r, db.bg.g, db.bg.b, 1)

  cbSound:_set(db.sounds and db.sounds.enabled)

  cbVault:_set(db.modules and db.modules.vault)
  cbReset:_set(db.modules and db.modules.dailyReset)
  cbRem:_set(db.modules and db.modules.reminders)
  cbDura:_set(db.modules and db.modules.durability)
  cbBags:_set(db.modules and db.modules.bags)
  cbFriends:_set(db.modules and db.modules.friends)
  cbKeys:_set(db.modules and db.modules.keys)

  cbInf:_set(true)
  RefreshLockChip()
  RefreshWidthControlState()
  RefreshMinimapChip()

  UpdateReminderListLayout()
  RebuildReminderRows(true)

  pGeneral._contentHeight = math.abs(UIG.y) + 60
  pModules._contentHeight = math.abs(UIM.y) + 40

  UpdateContentHeight()
end

-- Size changed -> relayout light
local function RunLightRelayout()
  UpdateContentChildWidth()
  for _, fn in ipairs(RelayoutCallbacks) do pcall(fn) end
  UpdateReminderListLayout()
  UpdateContentHeight()
end

local resizeDebounce
local resizeThrottle
local lastRelayoutAt = 0
local THROTTLE_INTERVAL = 0.016
local FINAL_DEBOUNCE    = 0.06

local function ScheduleFinalRelayout()
  if resizeDebounce and resizeDebounce.Cancel then resizeDebounce:Cancel() end
  resizeDebounce = C_Timer.NewTimer(FINAL_DEBOUNCE, function()
    resizeDebounce = nil
    RunLightRelayout()
  end)
end

local function ThrottledRelayout()
  local now = GetTime()
  if (now - lastRelayoutAt) >= THROTTLE_INTERVAL then
    lastRelayoutAt = now
    RunLightRelayout()
    return
  end

  if resizeThrottle and resizeThrottle.Cancel then resizeThrottle:Cancel() end
  local wait = THROTTLE_INTERVAL - (now - lastRelayoutAt)
  if wait < 0.001 then wait = 0.001 end

  resizeThrottle = C_Timer.NewTimer(wait, function()
    resizeThrottle = nil
    lastRelayoutAt = GetTime()
    RunLightRelayout()
  end)
end

cfg:SetScript("OnSizeChanged", function(self)
  local w, h = self:GetSize()
  w, h = ClampSize(w, h)
  if w ~= self:GetWidth() or h ~= self:GetHeight() then
    self:SetSize(w, h)
    return
  end
  if not self:IsShown() then return end
  ThrottledRelayout()
  ScheduleFinalRelayout()
end)

-- =========================================================
-- Toggle config
-- =========================================================
local function ToggleConfig()
  if cfg:IsShown() then
    cfg:Hide()
  else
    cfg:Show()
    RefreshConfig()
    currentPageKey = nil
    ShowPage("general")
    RunLightRelayout()

    C_Timer.After(0, function()
      if cfg:IsShown() then
        UpdateContentHeight()
      end
    end)
  end
end
HKDT.ToggleConfig = ToggleConfig

-- Sliders -> DB
sScale:HookScript("OnValueChanged", function(_, v)
  local db = DB(); if not db then return end
  db.scale = v
  for _, fr in ipairs(Active) do ApplyLayout(fr) end
  Reflow()
  RefreshAnchor()
end)

sDur:HookScript("OnValueChanged", function(_, v)
  local db = DB(); if not db then return end
  db.duration = v
end)

sWidth:HookScript("OnValueChanged", function(_, v)
  local db = DB(); if not db then return end

  -- ✅ WoW skin: width travado
    if IsWidthLockedSkin() then
    -- garante que o slider volte pro valor real travado
    if sWidth and sWidth._ApplyValue then
      sWidth._ApplyValue(db.width)
    end
    return
  end

  db.width = v
  for _, fr in ipairs(Active) do
    ApplyLayout(fr)
    SetFramePosition(fr)
  end
  Reflow()
  RefreshAnchor()
end)

sMax:HookScript("OnValueChanged", function(_, v)
  local db = DB(); if not db then return end
  db.maxVisible = math.floor(v + 0.5)
  while #Queue > 0 and #Active < db.maxVisible do
    local item = table.remove(Queue, 1)
    StartToast(item.kind, item.author, item.msg, item.meta)
  end
end)

-- Default page
ShowPage("general")

-- =========================================================
-- Slash commands
-- =========================================================
SLASH_HKDTOASTS1 = "/hkdtoasts"
SLASH_HKDTOASTS2 = "/hkdt"

SlashCmdList.HKDTOASTS = function(msg)
  local db = DB(); if not db then return end

  msg = (msg or ""):lower()
  if msg == "" then
    ToggleConfig()
    return
  end

  if msg == "test" then
    Enqueue("MAIL", nil, "You have new mail to open.")
    Enqueue("VAULT", nil, "Rewards available to claim.")
    Enqueue("SYSTEM", nil, "Daily reset is live.")
    Enqueue("REMINDER", nil, "Stretch + water")
    return
  end

  if msg == "sound" then
    db.sounds = db.sounds or CopyDefaults(DEFAULTS.sounds, {})
    db.sounds.enabled = not db.sounds.enabled
    print("HKDToasts: sounds " .. (db.sounds.enabled and "ON" or "OFF"))
    return
  end

  if msg == "lock" then
    db.locked = true
    RefreshLockChip()
    RefreshAnchor()
    print("HKDToasts: locked.")
    return
  end

  if msg == "unlock" then
    db.locked = false
    RefreshLockChip()
    RefreshAnchor()
    print("HKDToasts: unlocked.")
    return
  end

  print(C_ACCENT .. "HKDToasts" .. C_RESET .. " commands:")
  print("  /hkdtoasts or /hkdt  - open config")
  print("  /hkdtoasts test      - test toast")
  print("  /hkdtoasts sound     - toggle sounds")
  print("  /hkdtoasts lock      - lock position")
  print("  /hkdtoasts unlock    - unlock position")
end