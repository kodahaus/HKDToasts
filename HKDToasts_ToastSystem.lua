local ADDON_NAME = ...

-- Shared addon namespace (single table across all files)
local HKDT = _G.HKDT
if not HKDT then
  HKDT = {}
  _G.HKDT = HKDT
end



-- >>> HKDT: SECTION [05] TOAST ENGINE CORE

HKDT.FramePool = HKDT.FramePool or {}
HKDT.Active    = HKDT.Active or {} -- newest first
HKDT.Queue     = HKDT.Queue or {}


local function GetToastSkin()
  local db = HKDT.DB
  local skin = db and db.layout and db.layout.toastSkin or "MODERN"

  -- When "Toast Skin" is set to WOW, pick the correct variant key
  if skin == "WOW" then
    local v = db and db.layout and db.layout.wowVariant or "DARK"
    if v == "LIGHT" then return "WOW_LIGHT" end
    return "WOW_DARK"
  end
  
  if skin == "JOURNEY" then
    return "JOURNEY"
  end

  return skin
end

local function IsWowSkin(skin)
  return skin == "WOW" or skin == "WOW_DARK" or skin == "WOW_LIGHT" or skin == "EVERGREEN"
end

local function IsJourneySkin(skin)
  return skin == "JOURNEY"
end

local function GetSkinsBasePath()
  local addon = HKDT.ADDON_NAME or "HKDToasts"
  return "Interface\\AddOns\\" .. addon .. "\\Media\\Skins\\"
end

local function GetWowIconsBasePath()
  local addon = HKDT.ADDON_NAME or "HKDToasts"
  return "Interface\\AddOns\\" .. addon .. "\\Media\\Icons\\wowicons\\"
end

-- ---------------------------------------------------------
-- [05.2] Layout & positioning
-- ---------------------------------------------------------
function HKDT.ApplyToastBackground(frame)
  local DB = HKDT.DB
  if not DB or not DB.bg then return end

  local def = HKDT.GetSkinDef()

  -- Se a skin não permite tint, NÃO mexe no backdrop color.
  -- Assim, se o ApplyToastBackdrop setou um fallback sólido (texture missing),
  -- ele não é apagado.
  if def and def.allowTintBG == false then
    return
  end

  frame:SetBackdropColor(DB.bg.r, DB.bg.g, DB.bg.b, DB.bg.a)
end



function HKDT.ApplyToastBorder(frame, kind)
  local def = HKDT.GetSkinDef()
  if def and def.border then
    frame:SetBackdropBorderColor(def.border[1], def.border[2], def.border[3], def.border[4])
    return
  end

  local DB = HKDT.DB
  local a = (DB and DB.borderAlpha) or 0.85
  local c = HKDT.GetKindColor(kind)
  if not c then
    frame:SetBackdropBorderColor(1,1,1,0.08)
    return
  end
  frame:SetBackdropBorderColor(c.r, c.g, c.b, a)
end

local function GetSkinBasePath()
  local addon = HKDT.ADDON_NAME or "HKDToasts"
  return "Interface\\AddOns\\" .. addon .. "\\Media\\Skins\\"
end

function HKDT.ApplyToastBackdrop(frame)
  if not frame then return end

  local def = HKDT.GetSkinDef()
  if not def or not def.type then return end

  local db = HKDT.DB
  local compact = db and db.layout and db.layout.compact



  -- Reset common layers
  if frame._wowBG then frame._wowBG:Hide() end
  if frame._journeyBG then frame._journeyBG:Hide() end

  -- =========================================================
  -- NOFRAME
  -- =========================================================
  if def.type == "NOFRAME" then
    frame:SetBackdropColor(0,0,0,0)
    frame:SetBackdropBorderColor(0,0,0,0)
    if frame._iconBG then frame._iconBG:SetAlpha(0) end

    local t = def.text or {}
    local function Apply(fs, rgba)
      if not fs or not rgba then return end
      fs:SetTextColor(rgba[1], rgba[2], rgba[3], rgba[4] or 1)
      fs:SetShadowColor(0,0,0,0.85)
      fs:SetShadowOffset(1,-1)
    end
    Apply(frame._title, t.title)
    Apply(frame._body,  t.body)
    return
  end

  -- =========================================================
  -- JOURNEY
  -- =========================================================
  if def.type == "JOURNEY" then
    local base = GetSkinsBasePath()

    local file = (def.journey and def.journey.bgTex) or "toastblizzlike_mode2.tga"
    if compact and def.journey and def.journey.bgTexCompact then
      file = def.journey.bgTexCompact
    end

    local tex = base .. file

    frame._skinFallbackSolid = true
    frame:SetBackdropColor(0,0,0,0)
    frame:SetBackdropBorderColor(0,0,0,0)

    if frame._journeyBG then
      frame._journeyBG:SetTexture(tex)
      frame._journeyBG:SetVertexColor(1,1,1,1)
      frame._journeyBG:SetAlpha(1)
      frame._journeyBG:Show()

      -- debug/fallback: se não carregou a textura, evita ficar invisível
      if not frame._journeyBG:GetTexture() then
        print("HKDToasts: JOURNEY texture NOT FOUND ->", tex)
        frame:SetBackdropColor(0,0,0,0.85)
        frame:SetBackdropBorderColor(1,1,1,0.10)
        frame._journeyBG:Hide()
      end
    end

    if frame._iconBG then frame._iconBG:SetAlpha(0) end

    local t = def.text or {}
    local function Apply(fs, rgba)
      if not fs or not rgba then return end
      fs:SetTextColor(rgba[1], rgba[2], rgba[3], rgba[4] or 1)
      fs:SetShadowColor(0,0,0,0.75)
      fs:SetShadowOffset(1,-1)
    end
    Apply(frame._title, t.title)
    Apply(frame._body,  t.body)

    if frame._badgeText then
      frame._badgeText:SetTextColor(0.95, 0.92, 0.86, 1)
      frame._badgeText:SetShadowColor(0, 0, 0, 0.55)
      frame._badgeText:SetShadowOffset(1, -1)
    end

    return
  end

  -- =========================================================
  -- WOW (DARK/LIGHT)
  -- =========================================================
  if def.type == "WOW" then
    local base = GetSkinsBasePath()

    local file = (def.wow and def.wow.bgTex) or "toastblizzlike_dark.tga"
    if compact and def.wow and def.wow.bgTexCompact then
      file = def.wow.bgTexCompact
    end

    local tex = base .. file

    frame:SetBackdropColor(0,0,0,0)
    frame:SetBackdropBorderColor(0,0,0,0)

    if frame._wowBG then
      frame._wowBG:SetTexture(tex)
      frame._wowBG:SetVertexColor(1,1,1,1)
      frame._wowBG:SetAlpha(1)
      frame._wowBG:Show()

      if not frame._wowBG:GetTexture() then
        print("HKDToasts: WOW texture NOT FOUND ->", tex)
		frame._skinFallbackSolid = true
        frame:SetBackdropColor(0,0,0,0.85)
        frame:SetBackdropBorderColor(1,1,1,0.10)
        frame._wowBG:Hide()
		
	else
        frame._skinFallbackSolid = nil  
        frame._wowBG:Show()	
      end
    end

    if frame._iconBG then frame._iconBG:SetAlpha(0) end

    local t = def.text or {}
    local isLight = (def.variant == "LIGHT")

    local function Apply(fs, rgba)
      if not fs or not rgba then return end
      fs:SetTextColor(rgba[1], rgba[2], rgba[3], rgba[4] or 1)
      fs:SetShadowColor(0,0,0, isLight and 0.85 or 0.75)
      fs:SetShadowOffset(1,-1)
    end
    Apply(frame._title, t.title)
    Apply(frame._body,  t.body)

    if frame._badgeText then
      if isLight then
        frame._badgeText:SetTextColor(0.10, 0.10, 0.10, 1)
        frame._badgeText:SetShadowColor(1, 1, 1, 0.25)
      else
        frame._badgeText:SetTextColor(0.95, 0.92, 0.86, 1)
        frame._badgeText:SetShadowColor(0, 0, 0, 0.55)
      end
      frame._badgeText:SetShadowOffset(1, -1)
    end

    return
  end

  -- =========================================================
  -- MODERN fallback
  -- =========================================================
  if frame._iconBG then frame._iconBG:SetAlpha(1) end
end

function HKDT.ApplyToastFont(frame)
  if not frame or not frame._title or not frame._body then return end

  local db = HKDT.DB
  local key = (db and db.layout and db.layout.font) or "GameFontNormal"

  local path, resolvedKey = HKDT.GetFontPathByKey(key)

  local compact = db and db.layout and db.layout.compact
  local titleSize = compact and 12 or 13
  local bodySize  = compact and 12 or 12

  local ok1 = frame._title:SetFont(path, titleSize, "")
  local ok2 = frame._body:SetFont(path, bodySize, "")

if not ok1 or not ok2 then
  print("HKDToasts: SetFont FAILED for:", tostring(key), "->", tostring(path))
end

  frame._title:SetFont(path, titleSize, "")
  frame._body:SetFont(path, bodySize, "")
end

local function EnsureLayoutDefaults()
  local db = HKDT.DB
  if not db then return end

  if HKDT.DEFAULTS and HKDT.DEFAULTS.layout and HKDT.CopyDefaults then
    db.layout = HKDT.CopyDefaults(HKDT.DEFAULTS.layout, db.layout or {})
  else
    db.layout = db.layout or {}
  end

  if db.layout then
    if db.layout.compactMinWidth == nil then
      db.layout.compactMinWidth = 260
    end
  end
end

function HKDT.ApplyLayout(frame)
  local DB = HKDT.DB
  if not DB then return end

  EnsureLayoutDefaults()

local skin = GetToastSkin()
local def  = HKDT.GetSkinDef()

local w = DB.width or 260
local h = DB.height or 56

if def.lockWidth then
  w = tonumber(def.lockWidth) or w
else
  if DB.layout and DB.layout.compact then
    local minW = tonumber(DB.layout.compactMinWidth) or 260
    if w < minW then w = minW end
  end
end

  -- compact height continua funcionando
  if DB.layout and DB.layout.compact then
    local compactH = math.floor((h * 0.72) + 0.5)
    if compactH < 34 then compactH = 34 end
    if compactH > 44 then compactH = 44 end
    h = compactH
  end

  frame:SetScale(DB.scale or 1)
  frame:SetSize(w, h)

  HKDT.ApplyToastBackdrop(frame)
  HKDT.ApplyToastBackground(frame)
  HKDT.ApplyToastFont(frame)

  frame._effectiveW = w
  frame._effectiveH = h
end

-- ---------------------------------------------------------
-- Position anchor (invisible) for GROW
-- ---------------------------------------------------------
HKDT.PosAnchor = HKDT.PosAnchor or nil

function HKDT.EnsurePosAnchor()
  if HKDT.PosAnchor then return end
  HKDT.PosAnchor = CreateFrame("Frame", "HKDToastsPosAnchor", UIParent)
  HKDT.PosAnchor:SetSize(1, 1)
  HKDT.PosAnchor:SetClampedToScreen(true)
  HKDT.PosAnchor:Hide()
end

-- Keep it safe & useful: re-apply layout + update text based on stored fields.
function HKDT.RenderToast(frame)
  if not frame then return end
  local db = HKDT.DB
  if not db then return end

  EnsureLayoutDefaults()

  HKDT.ApplyLayout(frame)
  if frame._ApplyInternalLayout then
    frame:_ApplyInternalLayout()
  end

  HKDT.UpdateText(frame, frame._kind or "WHISPER", frame._author, frame._msgText or "")
end

function HKDT.SetPosAnchorPosition(frame)
  local DB = HKDT.DB
  if not DB then return end
  HKDT.EnsurePosAnchor()

  local w = (frame and frame._effectiveW) or (DB.width or 360)
  local h = (frame and frame._effectiveH) or (DB.height or 56)

  HKDT.PosAnchor:ClearAllPoints()
  HKDT.PosAnchor:SetScale(DB.scale or 1)
  HKDT.PosAnchor:SetSize(w, h)
  HKDT.PosAnchor:SetPoint(DB.point, UIParent, DB.relPoint, DB.x, DB.y)
end

function HKDT.SetFramePosition(frame)
  local DB = HKDT.DB
  if not DB then return end

  local ax = (frame._animOffsetX or 0)
  local ay = (frame._animOffsetY or 0)

  frame:ClearAllPoints()

  local modeNow = frame._animMode or (DB.animations and DB.animations.mode)

  if modeNow == "GROW" then
    HKDT.SetPosAnchorPosition(frame)
    frame:SetPoint("CENTER", HKDT.PosAnchor, "CENTER", ax, (frame._stackOffset or 0) + ay)
    return
  end

  frame:SetPoint(
    DB.point,
    UIParent,
    DB.relPoint,
    DB.x + ax,
    DB.y + (frame._stackOffset or 0) + ay
  )
end

-- ---------------------------------------------------------
-- [05.3] Move Anchor (overlay when unlocked)
-- ---------------------------------------------------------
HKDT.Anchor = HKDT.Anchor or nil

function HKDT.SetAnchorPosition()
  local DB = HKDT.DB
  if not HKDT.Anchor or not DB then return end
  HKDT.Anchor:ClearAllPoints()
  HKDT.Anchor:SetPoint(DB.point, UIParent, DB.relPoint, DB.x, DB.y)
end

function HKDT.ApplyAnchorLayout()
  local DB = HKDT.DB
  if not HKDT.Anchor or not DB then return end

  EnsureLayoutDefaults()

  HKDT.Anchor:SetScale(DB.scale or 1)

  local w = DB.width or 360
  local h = DB.height or 56
  if DB.layout and DB.layout.compact then
    local compactH = math.floor((h * 0.72) + 0.5)
    if compactH < 34 then compactH = 34 end
    if compactH > 44 then compactH = 44 end
    h = compactH
  end

  HKDT.Anchor:SetSize(w, h)
end

function HKDT.EnsureAnchor()
  if HKDT.Anchor then return end

  local Anchor = CreateFrame("Frame", "HKDToastsMoveAnchor", UIParent, "BackdropTemplate")
  Anchor:SetClampedToScreen(true)
  Anchor:SetMovable(true)
  Anchor:EnableMouse(true)
  Anchor:RegisterForDrag("LeftButton")
  Anchor:SetFrameStrata("DIALOG")
  Anchor:SetFrameLevel((UIParent:GetFrameLevel() or 1) + 80)

  Anchor:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })

  Anchor:SetBackdropColor(0.20, 0.55, 1.00, 0.14)
  Anchor:SetBackdropBorderColor(0.35, 0.78, 1.00, 0.70)

  local label = Anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER", 0, 0)
  label:SetText("|cff5cc7ffUnlocked|r  •  drag to move")
  label:SetTextColor(1,1,1,0.95)
  Anchor._label = label

  Anchor:SetScript("OnDragStart", function(self)
    local DB = HKDT.DB
    if DB and DB.locked then return end
    self:StartMoving()
  end)

  Anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local DB = HKDT.DB
    if not DB then return end
    local point, _, relPoint, x, y = self:GetPoint(1)
    DB.point, DB.relPoint, DB.x, DB.y = point, relPoint, x, y

    HKDT.SetAnchorPosition()
    for _, fr in ipairs(HKDT.Active) do
      HKDT.SetFramePosition(fr)
    end
  end)

  Anchor:Hide()
  HKDT.Anchor = Anchor
end

function HKDT.RefreshAnchor()
  local DB = HKDT.DB
  if not DB then return end
  HKDT.EnsureAnchor()
  HKDT.ApplyAnchorLayout()
  HKDT.SetAnchorPosition()

  if DB.locked then
    HKDT.Anchor:Hide()
  else
    HKDT.Anchor:Show()
  end
end

HKDT.SKIN_DEFS = HKDT.SKIN_DEFS or {
  MODERN = {
    type = "MODERN",
    lockWidth = false,
    allowTintBG = true,
    text = { title = {0.92,0.92,0.92,1}, body = {0.85,0.85,0.85,1}, shadowA = 0.35 },
    wow = nil,
  },

    WOW_DARK = {
    type = "WOW",
    variant = "DARK",   -- ✅ ADD
    lockWidth = 260,
    allowTintBG = false,
    wow = {
  bgTex = "toastblizzlike_dark.tga",
  bgTexCompact = "toastblizzlike_dark_compact.tga",
},
    text = { title = {0.92, 0.84, 0.65, 1}, body = {0.92, 0.90, 0.84, 1}, shadowA = 0.75 },
    border = {0,0,0,0},
  },

  WOW_LIGHT = {
  type = "WOW",
  variant = "LIGHT",
  lockWidth = 260,
  allowTintBG = false,
  wow = {
  bgTex = "toastblizzlike_light.tga",
  bgTexCompact = "toastblizzlike_light_compact.tga",
},

  text = {
  -- TÍTULO: dourado claro estilo WoW
  title = {1.00, 0.92, 0.65, 1},

  -- BODY: quase branco quente
  body  = {0.97, 0.95, 0.88, 1},

  shadowA = 0.55,
},
  border = {0,0,0,0},
},

JOURNEY = {
  type = "JOURNEY",
  lockWidth = 260,
  allowTintBG = false,
  journey = {
    bgTex = "toastblizzlike_mode2.tga",
    bgTexCompact = "toastblizzlike_mode2_compact.tga",
  },
  text = { title = {0.92, 0.84, 0.65, 1}, body = {0.92, 0.90, 0.84, 1}, shadowA = 0.75 },
  border = {0,0,0,0},
},

NOFRAME = {
  type = "NOFRAME",
  lockWidth = false,
  allowTintBG = false,
  text = {
    title = {1,1,1,1},
    body  = {1,1,1,1},
    shadowA = 0.85,
  },
  border = {0,0,0,0},
  badgeAnchor = "LEFT",
},

EVERGREEN = {
  type = "WOW",
  variant = "DARK",
  lockWidth = 260,
  allowTintBG = false,
  wow = {
    bgTex = "toastblizzlike_stone.tga",
    bgTexCompact = "toastblizzlike_stone_compact.tga",
  },
  text = { title = {0.92, 0.84, 0.65, 1}, body = {0.92, 0.90, 0.84, 1}, shadowA = 0.75 },
  border = {0,0,0,0},
},

LINE = {
  type = "WOW",
  variant = "DARK",
  lockWidth = false,         -- deixa livre por enquanto
  allowTintBG = false,
  wow = {
    bgTex = "transparentline.tga",
    bgTexCompact = "transparentline.tga", -- mesma pros dois, como você comentou
  },
  text = { title = {1,1,1,1}, body = {1,1,1,0.95}, shadowA = 0.85 },
  border = {0,0,0,0},
  badgeAnchor = "LEFT",      -- 👈 flag pra mover a bolinha só nessa skin
},

}

function HKDT.GetSkinDef()
  local key = GetToastSkin()
  return HKDT.SKIN_DEFS[key] or HKDT.SKIN_DEFS.MODERN
end

-- ---------------------------------------------------------
-- [05.4] Click-to-reply helpers
-- ---------------------------------------------------------
function HKDT.Trim(s)
  if not s then return "" end
  s = tostring(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function HKDT.StripRealm(name)
  if not name or name == "" then return name end
  local base = name:match("^([^%-]+)%-.+$")
  return base or name
end

function HKDT.StripBattleTag(name)
  name = HKDT.Trim(name)
  if name == "" then return "" end
  name = name:gsub("#%d+", "")
  return HKDT.Trim(name)
end

function HKDT.ReplyWhisper(author)
  author = HKDT.Trim(author)
  if author == "" then return end

  if ChatFrame_SendTell then
    ChatFrame_SendTell(author)
    return
  end

  if ChatFrame_OpenChat then
    ChatFrame_OpenChat("/w " .. author .. " ")
  end
end

function HKDT.ReplyBNet(bnetIDAccount, authorFallback)
  if type(bnetIDAccount) == "number" and ChatFrame_SendBNetTell then
    ChatFrame_SendBNetTell(bnetIDAccount)
    return
  end

  authorFallback = HKDT.Trim(authorFallback)
  if authorFallback ~= "" and ChatFrame_OpenChat then
    ChatFrame_OpenChat("/w " .. authorFallback .. " ")
  end
end

-- ---------------------------------------------------------
-- [05.4.1] Badge stacking (WHISPER / BNET)
-- ---------------------------------------------------------
function HKDT.ApplyBadgeColors(frame)
  if not frame or not frame._badgeFrame then return end

  local badge = frame._badgeFrame
  local bg = badge._bg
  local border = badge._border
  if not bg or not border then return end

  local skinKey = GetToastSkin()

  -- ✅ WOW skins: usa textura fixa stackcounter.tga (sem borda colorida)
  if skinKey == "WOW_DARK" or skinKey == "WOW_LIGHT" or skinKey == "EVERGREEN" or skinKey == "JOURNEY" then
  if badge._skinTex then badge._skinTex:Show() end

  bg:SetAlpha(0)
  border:SetAlpha(0)
  if badge._borderInner then badge._borderInner:SetAlpha(0) end

  -- ✅ sempre branco
  if frame._badgeText then
    frame._badgeText:SetTextColor(1, 1, 1, 0.95)
    frame._badgeText:SetShadowColor(0, 0, 0, 0.65)
    frame._badgeText:SetShadowOffset(1, -1)
  end

  return
end

  -- ✅ outras skins (Modern / NOFRAME / LINE / JOURNEY etc): mantém o sistema atual
  if badge._skinTex then badge._skinTex:Hide() end

  bg:SetAlpha(1)
  border:SetAlpha(1)
  if badge._borderInner then badge._borderInner:SetAlpha(1) end

  bg:SetColorTexture(7/255, 8/255, 10/255, 1.00)

  local c = HKDT.GetKindColor(frame._kind)
  local a = (HKDT.DB and HKDT.DB.borderAlpha) or 0.85

  if c then
    border:SetColorTexture(c.r, c.g, c.b, a)
  else
    border:SetColorTexture(1, 1, 1, 0.20)
  end

  if badge._borderInner then
    badge._borderInner:SetColorTexture(7/255, 8/255, 10/255, 1.00)
  end
end

function HKDT.SetBadge(frame, count)
  if not frame or not frame._badgeFrame or not frame._badgeText then return end

  count = tonumber(count) or 0
  frame._badgeCount = count

  HKDT.ApplyBadgeColors(frame)

  if count > 0 then
    frame._badgeText:SetText("+" .. count)
    frame._badgeFrame:Show()
  else
    frame._badgeFrame:Hide()
  end
end

function HKDT.BuildStackKey(kind, authorText, meta)
  if kind == "WHISPER" then
    local fullLower = select(1, HKDT.NormalizeAuthorName(authorText or ""))
    if fullLower == "" then fullLower = (authorText or ""):lower() end
    return "WHISPER:" .. fullLower
  end

  if kind == "BNET" then
    local id = meta and meta.bnetIDAccount
    if type(id) == "number" then
      return "BNET:" .. tostring(id)
    end
    local a = HKDT.Trim(authorText):lower()
    return "BNET:" .. a
  end

  return nil
end

function HKDT.BumpActiveToast(frame, kind, authorText, msgText, meta)
  if not frame or frame._animState == "OUT" then return end

  frame._badgeCount = (frame._badgeCount or 0) + 1
  frame._msgText = msgText or ""

  HKDT.SetToastStyle(frame, kind, authorText, meta)
  HKDT.UpdateText(frame, kind, authorText, msgText)
  HKDT.SetBadge(frame, frame._badgeCount)

  local DB = HKDT.DB
  local base = frame._baseScale or (DB and DB.scale) or 1.0

  frame._paused = false
  frame._pauseAt = 0
  frame._pausedTotal = 0
  frame._animOffsetX = 0
  frame._animOffsetY = 0
  frame:SetAlpha(1)
  frame:SetScale(base)

  frame._animState = "HOLD"
  frame._t0 = GetTime()

  HKDT.SetFramePosition(frame)
end

function HKDT.TryStackToExisting(kind, authorText, msgText, meta)
  local key = HKDT.BuildStackKey(kind, authorText, meta)
  if not key then return false end

  for _, fr in ipairs(HKDT.Active) do
    if fr._stackKey == key and fr._animState ~= "OUT" then
      HKDT.BumpActiveToast(fr, kind, authorText, msgText, meta)
      return true
    end
  end

  for _, it in ipairs(HKDT.Queue) do
    if it and it.stackKey == key then
      it.badge = (it.badge or 0) + 1
      it.author = authorText
      it.msg = msgText
      it.meta = meta
      return true
    end
  end

  return false
end

-- ---------------------------------------------------------
-- [05.5] Unit -> portrait helpers (WHISPER only)
-- ---------------------------------------------------------
function HKDT.NormalizeAuthorName(author)
  author = HKDT.Trim(author)
  if author == "" then return "", "" end

  author = author:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

  local short = author:match("^([^%-]+)") or author
  return author:lower(), short:lower()
end

function HKDT.FindUnitForAuthor(author)
  if not author or author == "" then return nil end
  local fullLower, shortLower = HKDT.NormalizeAuthorName(author)

  local function MatchUnit(unit)
    if not UnitExists(unit) then return false end
    local n, realm = UnitName(unit)
    if not n or n == "" then return false end

    local full = n
    if realm and realm ~= "" then full = n .. "-" .. realm end

    full = full:lower()
    n = n:lower()

    if fullLower == full or fullLower == n then return true end
    if shortLower == n then return true end
    return false
  end

  if MatchUnit("player") then return "player" end
  if MatchUnit("target") then return "target" end
  if MatchUnit("focus") then return "focus" end

  if IsInRaid and IsInRaid() then
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
      local u = "raid" .. i
      if MatchUnit(u) then return u end
    end
  elseif IsInGroup and IsInGroup() then
    local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    for i = 1, n do
      local u = "party" .. i
      if MatchUnit(u) then return u end
    end
  end

  return nil
end

-- ---------------------------------------------------------
-- [05.1] Frame pool (create/acquire/release)
-- ---------------------------------------------------------
function HKDT.CreateToastFrame()
  local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame:Hide()
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropBorderColor(1, 1, 1, 0.08)

  frame._stackOffset = 0
  frame._animOffsetX = 0
  frame._animOffsetY = 0
  frame._baseScale = 1.0
  frame._kind = "WHISPER"
  frame._author = nil
  frame._bnetIDAccount = nil
  frame._unit = nil
  frame._dragging = false

  frame._paused = false
  frame._pauseAt = 0
  frame._pausedTotal = 0
  frame._fullText = nil
  frame._showTooltip = false
  frame._msgText = nil

  local function ShowFullTextTooltip(self)
    if not self._fullText or self._fullText == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(self._fullText, 1,1,1, true)
    GameTooltip:Show()
  end

  local function HideTooltip()
    if GameTooltip and GameTooltip:IsShown() then GameTooltip:Hide() end
  end

  frame:SetScript("OnEnter", function(self)
    if self._animState == "HOLD" then
      self._paused = true
      self._pauseAt = GetTime()
    end

    if self._showTooltip then
      ShowFullTextTooltip(self)
    end
  end)

  frame:SetScript("OnLeave", function(self)
    if self._paused then
      local now = GetTime()
      self._pausedTotal = (self._pausedTotal or 0) + (now - (self._pauseAt or now))
      self._paused = false
    end
    HideTooltip()
  end)

  frame:SetScript("OnDragStart", function(self)
    local DB = HKDT.DB
    if DB and DB.locked then return end
    self._dragging = true
    self:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self._dragging = false

    local DB = HKDT.DB
    if not DB then return end
    local point, _, relPoint, x, y = self:GetPoint(1)
    DB.point, DB.relPoint, DB.x, DB.y = point, relPoint, x, y
    for _, fr in ipairs(HKDT.Active) do
      HKDT.SetFramePosition(fr)
    end
  end)

  frame:SetScript("OnMouseUp", function(self, button)
    if self._dragging then return end

    if button == "RightButton" then
      if self._animState and self._animState ~= "OUT" then
        self._animState = "OUT"
        self._t0 = GetTime()
        self._paused = false
        self._pauseAt = 0
        self._pausedTotal = 0
        HideTooltip()
      end
      return
    end

    if button ~= "LeftButton" then return end

    if self._kind == "WHISPER" then
      HKDT.ReplyWhisper(self._author)
    elseif self._kind == "BNET" then
      HKDT.ReplyBNet(self._bnetIDAccount, self._author)
    end
  end)

  local iconBG = frame:CreateTexture(nil, "ARTWORK")
  iconBG:SetSize(34, 34)
  iconBG:SetColorTexture(1,1,1,0.05)

  local icon = frame:CreateTexture(nil, "OVERLAY")
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER", iconBG)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local body  = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  title:SetJustifyH("LEFT")
  body:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  body:SetWordWrap(false)

  frame._iconBG = iconBG
  frame._icon = icon
  frame._title = title
  frame._body = body

frame._wowBG = frame:CreateTexture(nil, "ARTWORK", nil, -1)
frame._wowBG:SetAllPoints(frame)
frame._wowBG:Hide()

frame._journeyBG = frame:CreateTexture(nil, "ARTWORK", nil, -1)
frame._journeyBG:SetAllPoints(frame)
frame._journeyBG:Hide()

  -- badge (for stacked whispers/bnet)
  local badge = CreateFrame("Frame", nil, frame)
  badge:SetSize(18, 18)
  badge:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
  badge:EnableMouse(false)

  local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

  local badgeBG = badge:CreateTexture(nil, "BACKGROUND")
  badgeBG:SetAllPoints()
  badgeBG:SetColorTexture(7/255, 8/255, 10/255, 1.00)

  local ringOuter = badge:CreateTexture(nil, "BORDER")
  ringOuter:SetAllPoints()
  ringOuter:SetColorTexture(1, 1, 1, 0.22)

  local ringInner = badge:CreateTexture(nil, "ARTWORK")
  ringInner:SetPoint("TOPLEFT", badge, "TOPLEFT", 1, -1)
  ringInner:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -1, 1)
  ringInner:SetColorTexture(7/255, 8/255, 10/255, 1.00)
  
  local function ApplyRoundMask(tex)
    if not tex then return end
    if tex.SetMaskTexture then
      tex:SetMaskTexture(MASK)
      return
    end
    if tex.AddMaskTexture and badge.CreateMaskTexture then
      local m = badge:CreateMaskTexture()
      m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      m:SetAllPoints(tex)
      tex:AddMaskTexture(m)
      return m
    end
  end

  local addon = HKDT.ADDON_NAME or "HKDToasts"
  local ICONS_BASE = "Interface\\AddOns\\" .. addon .. "\\Media\\Icons\\"  
  
  -- WOW badge skin (used only on WOW_DARK/WOW_LIGHT/EVERGREEN)
  local badgeSkin = badge:CreateTexture(nil, "ARTWORK")
  badgeSkin:SetAllPoints()
  badgeSkin:SetTexture(ICONS_BASE .. "stackcounter.tga")
  badgeSkin:SetVertexColor(1,1,1,1)
  badgeSkin:SetAlpha(1)
  badgeSkin:Hide()

  -- aplica máscara redonda também na textura da skin
  frame._badgeMaskSkin = ApplyRoundMask(badgeSkin)

  badge._skinTex = badgeSkin

  local function ApplyRoundMask(tex)
    if not tex then return end
    if tex.SetMaskTexture then
      tex:SetMaskTexture(MASK)
      return
    end
    if tex.AddMaskTexture and badge.CreateMaskTexture then
      local m = badge:CreateMaskTexture()
      m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      m:SetAllPoints(tex)
      tex:AddMaskTexture(m)
      return m
    end
  end

  frame._badgeMaskBG    = ApplyRoundMask(badgeBG)
  frame._badgeMaskOuter = ApplyRoundMask(ringOuter)
  frame._badgeMaskInner = ApplyRoundMask(ringInner)

  badge._bg = badgeBG
  badge._border = ringOuter
  badge._borderInner = ringInner

  local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  badgeText:SetPoint("CENTER", 0, 0)
  badgeText:SetText("+1")
  badgeText:SetTextColor(1, 1, 1, 0.95)
  badgeText:SetFontObject("GameFontNormalSmall")

  badge:Hide()
  frame._badgeFrame = badge
  frame._badgeText  = badgeText
  frame._badgeCount = 0
  frame._stackKey   = nil

  frame._ApplyInternalLayout = function(self)
    local DB = HKDT.DB
    EnsureLayoutDefaults()
	
	local skin = HKDT.GetToastSkin and HKDT.GetToastSkin() or GetToastSkin()

    local compact = DB and DB.layout and DB.layout.compact
    local side = DB and DB.layout and DB.layout.iconSide or "LEFT"

   local bgSize   = compact and 28 or 34
local iconSize = compact and 16 or 18

-- pack direto do DB (não chama GetIconPack aqui)
local pack = (DB and DB.layout and DB.layout.iconPack) or "WOW"

-- forced packs por skin (igual seu GetIconPack)
local skinKey = GetToastSkin()
if skinKey == "EVERGREEN" then pack = "WOW" end
if skinKey == "LINE" then pack = "FLAT" end

-- atlas um pouco maior (FLAT fica intacto)
if pack == "WOW" then
  iconSize = compact and 18 or 21
end

-- skins WOW/JOURNEY/EVERGREEN podem ser maiores ainda
local skinNow = GetToastSkin()
if IsWowSkin(skinNow) or skinNow == "JOURNEY" then
  iconSize = compact and 22 or 24
end

    self._showTooltip = false
    self._fullText = nil

    iconBG:ClearAllPoints()
    title:ClearAllPoints()
    body:ClearAllPoints()

    iconBG:SetSize(bgSize, bgSize)
    icon:SetSize(iconSize, iconSize)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", iconBG)

    if side == "RIGHT" then
      iconBG:SetPoint("RIGHT", -14, 0)
    else
      iconBG:SetPoint("LEFT", 14, 0)
    end

    if self._badgeFrame then
  local bsz = compact and 18 or 20
  self._badgeFrame:SetSize(bsz, bsz)
  self._badgeFrame:ClearAllPoints()
  local leak = math.floor(bsz * 0.45 + 0.5)

  local def = HKDT.GetSkinDef and HKDT.GetSkinDef() or nil
  if def and def.badgeAnchor == "LEFT" then
    self._badgeFrame:SetPoint("TOPLEFT", self, "TOPLEFT", -leak, leak)
  else
    self._badgeFrame:SetPoint("TOPRIGHT", self, "TOPRIGHT", leak, leak)
  end
end

    if compact then
      title:Hide()
      body:Show()

      if side == "RIGHT" then
        body:SetPoint("LEFT", 14, 0)
        body:SetPoint("RIGHT", iconBG, "LEFT", -12, 0)
      else
        body:SetPoint("LEFT", iconBG, "RIGHT", 12, 0)
        body:SetPoint("RIGHT", -14, 0)
      end
    else
      title:Show()
      body:Show()

      if side == "RIGHT" then
  -- espelha o LEFT (centralizado)
  title:SetPoint("LEFT", 14, 10)
  title:SetPoint("RIGHT", iconBG, "LEFT", -12, 0)

  body:SetPoint("LEFT", 14, -6)
  body:SetPoint("RIGHT", iconBG, "LEFT", -12, 0)
else
  title:SetPoint("LEFT", iconBG, "RIGHT", 12, 10)
  title:SetPoint("RIGHT", -14, 0)

  body:SetPoint("LEFT", iconBG, "RIGHT", 12, -6)
  body:SetPoint("RIGHT", -14, 0)
end
    end
  end

  return frame
end

function HKDT.AcquireFrame()
  for _, fr in ipairs(HKDT.FramePool) do
    if not fr._inUse then
      fr._inUse = true
      return fr
    end
  end
  local fr = HKDT.CreateToastFrame()
  fr._inUse = true
  table.insert(HKDT.FramePool, fr)
  return fr
end

function HKDT.ReleaseFrame(frame)
  if not frame then return end
  frame:SetScript("OnUpdate", nil)
  frame:Hide()
  frame:SetAlpha(1)
  frame._inUse = false
  frame._kind = "WHISPER"
  frame._author = nil
  frame._bnetIDAccount = nil
  frame._unit = nil
  frame._stackOffset = 0
  frame._animOffsetX = 0
  frame._animOffsetY = 0
  frame._baseScale = 1.0

  local DB = HKDT.DB
  frame:SetScale((DB and DB.scale) or 1.0)

  frame._paused = false
  frame._pauseAt = 0
  frame._pausedTotal = 0
  frame._fullText = nil
  frame._showTooltip = false
  frame._msgText = nil

  frame._badgeCount = 0
  if frame._badgeText then frame._badgeText:SetText("") end
  if frame._badgeFrame then frame._badgeFrame:Hide() end
  if frame._badgeFrame and frame._badgeFrame._skinTex then
    frame._badgeFrame._skinTex:Hide()
  end  
  frame._stackKey = nil
end

-- ---------------------------------------------------------
-- [05.5.1] KEY helpers
-- ---------------------------------------------------------
function HKDT.NormalizeKeyText(s)
  s = s or ""
  return (s:gsub("^%s*New%s+Key%s*:%s*", ""))
end

function HKDT.ColorizeTrailingNumber(kind, s)
  s = s or ""
  local num = s:match("(%+?%d+)%s*$")
  if not num then return s end
  local prefix = s:sub(1, #s - #num)
  return prefix .. HKDT.ColoredText(kind, num)
end

-- ---------------------------------------------------------
-- [05.6] Ellipsis
-- ---------------------------------------------------------
function HKDT.SetSingleLineEllipsis(fs, text, maxWidth)
  if not fs or not text then return false end
  fs:SetWidth(maxWidth)
  fs:SetText(text)
  if not fs:IsTruncated() then return false end

  local ell = "..."
  local s = text
  while fs:IsTruncated() and #s > 0 do
    s = string.sub(s, 1, #s - 1)
    fs:SetText(s .. ell)
  end
  return true
end

-- ---------------------------------------------------------
-- Text rendering + Streamer Mode sanitize (FIXED)
-- ---------------------------------------------------------
function HKDT.UpdateText(frame, kind, authorText, msgText)
  local db = HKDT.DB
  local streamer = db and db.layout and db.layout.streamerMode

  -- normalize types (some callers may pass meta in msgText by mistake)
  if type(authorText) ~= "string" then
    authorText = authorText and tostring(authorText) or ""
  end

  if type(msgText) ~= "string" then
    if type(msgText) == "number" then
      msgText = tostring(msgText)
    elseif type(msgText) == "boolean" then
      msgText = msgText and "true" or "false"
    else
      -- table/function/etc -> don't concatenate
      msgText = ""
    end
  end

  if streamer and (kind == "WHISPER" or kind == "BNET") then
    -- Author sanitization (ONLY whisper + bnet)
    if kind == "WHISPER" then
      authorText = HKDT.StripRealm(authorText or "Player")
    else -- BNET
      authorText = "Battle.net Friend"
    end

    -- Message sanitization (ONLY whisper + bnet)
    msgText = "Message hidden"
  end

  local DB = HKDT.DB
  local w = frame._effectiveW or ((DB and DB.width) or 360)
  local compact = DB and DB.layout and DB.layout.compact

  local leftPad, rightPad = 14, 14
  local iconW, gap = 34, 12
  local textWidth = (w - leftPad - rightPad) - (iconW + gap)
  if textWidth < 80 then textWidth = 80 end

  frame._fullText = nil
  frame._showTooltip = false

  if compact then
    if kind == "KEY" then
      local clean = HKDT.NormalizeKeyText(msgText or "")
      clean = HKDT.ColorizeTrailingNumber(kind, clean)

      local prefix = HKDT.ColoredText(kind, "New Key:") .. " "
      local full = prefix .. clean

      local truncated = HKDT.SetSingleLineEllipsis(frame._body, full, textWidth)
      if truncated then
        frame._fullText = "New Key: " .. HKDT.NormalizeKeyText(msgText or "")
        frame._showTooltip = true
      end
      return
    end

    if kind == "WHISPER" or kind == "BNET" then
      local name = authorText or ""
      if kind == "BNET" then
        name = HKDT.StripBattleTag(name)
      end

      local coloredName = (name ~= "") and HKDT.ColoredText(kind, name) or ""
      local full = coloredName ~= "" and (coloredName .. ": " .. (msgText or "")) or (msgText or "")

      local truncated = HKDT.SetSingleLineEllipsis(frame._body, full, textWidth)
      if truncated then
        local rawFull = (name ~= "" and (name .. ": ") or "") .. (msgText or "")
        frame._fullText = rawFull
        frame._showTooltip = true
      end
      return
    end

    if kind == "FRIEND_ON" or kind == "FRIEND_OFF" then
      local name = HKDT.StripBattleTag(authorText or "")
      local status = msgText or ""
      local full = (name ~= "" and (HKDT.ColoredText(kind, name) .. " " .. status) or status)

      local truncated = HKDT.SetSingleLineEllipsis(frame._body, full, textWidth)
      if truncated then
        frame._fullText = (name ~= "" and (name .. " " .. status) or status)
        frame._showTooltip = true
      end
      return
    end

    local full = msgText or ""
    if kind == "DURA70" or kind == "DURA30" or kind == "DURA10" then
      full = HKDT.ColorDurabilityNumber(kind, full)
    end

    local truncated = HKDT.SetSingleLineEllipsis(frame._body, full, textWidth)
    if truncated then
      frame._fullText = msgText or ""
      frame._showTooltip = true
    end
    return
  end

  -- non-compact
  if (kind == "WHISPER" or kind == "BNET") then
    HKDT.SetSingleLineEllipsis(frame._body, msgText or "", textWidth)
    return
  end

  if kind == "FRIEND_ON" or kind == "FRIEND_OFF" then
    HKDT.SetSingleLineEllipsis(frame._body, msgText or "", textWidth)
    return
  end

  if kind == "KEY" then
    local clean = HKDT.NormalizeKeyText(msgText or "")
    clean = HKDT.ColorizeTrailingNumber(kind, clean)
    HKDT.SetSingleLineEllipsis(frame._body, clean, textWidth)
    return
  end

  if authorText and authorText ~= "" then
    HKDT.SetSingleLineEllipsis(frame._body, authorText .. ": " .. (msgText or ""), textWidth)
  else
    HKDT.SetSingleLineEllipsis(frame._body, msgText or "", textWidth)
  end
end

-- ---------------------------------------------------------
-- [05.7] Style
-- ---------------------------------------------------------
function HKDT.SetIcon(frame, atlas, fallbackTexture, useAtlasSize)
  if not frame or not frame._icon then return end

  -- NÃO seta size aqui. Layout cuida disso.
  frame._icon:ClearAllPoints()
  frame._icon:SetPoint("CENTER", frame._iconBG)

  frame._icon:SetTexCoord(0,1,0,1)
  frame._icon:SetVertexColor(1,1,1,1)

  if atlas and frame._icon.SetAtlas then
    local ok = pcall(function()
      frame._icon:SetAtlas(atlas, useAtlasSize and true or false)
    end)
    if ok then return end
  end

  if fallbackTexture then
    frame._icon:SetTexture(fallbackTexture)
    return
  end

  frame._icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

function HKDT.RefreshActiveText()
  local active = HKDT.Active
  if not active then return end
  for _, fr in ipairs(active) do
    if fr and fr._kind then
      HKDT.UpdateText(fr, fr._kind, fr._author, fr._msgText or "")
    end
  end
end

function HKDT.SetPortraitIcon(frame, unit)
  if not frame or not frame._icon or not unit then return false end
  if not UnitExists(unit) then return false end
  if not SetPortraitTexture then return false end

  frame._icon:ClearAllPoints()
  frame._icon:SetSize(frame._iconBG:GetWidth(), frame._iconBG:GetHeight())
  frame._icon:SetPoint("CENTER", frame._iconBG)
  frame._icon:SetTexCoord(0,1,0,1)
  frame._icon:SetVertexColor(1,1,1,1)

  SetPortraitTexture(frame._icon, unit)
  return true
end

function HKDT.SetToastStyle(frame, kind, authorText, meta)
  frame._kind = kind
  frame._author = authorText
  frame._bnetIDAccount = meta and meta.bnetIDAccount or nil
  frame._unit = meta and meta.unit or nil

  HKDT.ApplyToastBorder(frame, kind)
  HKDT.ApplyBadgeColors(frame)

  local DB = HKDT.DB
  local compact = DB and DB.layout and DB.layout.compact

  if kind == "MAIL" then
    HKDT.SetKindIcon(frame, kind, nil, "Interface\\Minimap\\Tracking\\Mailbox")
    frame._title:SetText(HKDT.ColoredText(kind, "Mail"))

  elseif kind == "BNET" then
    HKDT.SetKindIcon(frame, kind, "ui-chaticon-app")
    local disp = HKDT.StripBattleTag(authorText or "BNet")
    frame._title:SetText(HKDT.ColoredText(kind, disp))

  elseif kind == "VAULT" then
    HKDT.SetKindIcon(frame, kind, "greatvault-dragonflight-32x32")
    frame._title:SetText(HKDT.ColoredText(kind, compact and "Vault" or "Great Vault"))

  elseif kind == "REMINDER" then
    HKDT.SetKindIcon(frame, kind, "quest-recurring-available")
    frame._title:SetText(HKDT.ColoredText(kind, "Reminder"))

  elseif kind == "SYSTEM" then
    HKDT.SetKindIcon(frame, kind, "chromietime-32x32")
    frame._title:SetText(HKDT.ColoredText(kind, compact and "Reset" or "Daily Reset"))

  elseif kind == "DURA70" or kind == "DURA30" or kind == "DURA10" then
    HKDT.SetKindIcon(frame, kind, nil, "Interface\\Minimap\\Tracking\\Repair")
    frame._title:SetText(HKDT.ColoredText(kind, "Durability"))

  elseif kind == "BAG90" then
    HKDT.SetKindIcon(frame, kind, nil, "Interface\\Minimap\\Tracking\\Banker")
    frame._title:SetText(HKDT.ColoredText(kind, compact and "Inventory Almost Full" or "Inventory Almost Full"))

  elseif kind == "BAGFULL" then
    HKDT.SetKindIcon(frame, kind, nil, "Interface\\Minimap\\Tracking\\Banker")
    frame._title:SetText(HKDT.ColoredText(kind, compact and "Inventory Full" or "Inventory Full"))

  elseif kind == "FRIEND_ON" then
    HKDT.SetKindIcon(frame, kind, nil, "Interface\\FriendsFrame\\StatusIcon-Online")
    local disp = HKDT.StripBattleTag(authorText or "Friend")
    frame._title:SetText(HKDT.ColoredText(kind, disp))

  elseif kind == "FRIEND_OFF" then
    HKDT.SetKindIcon(frame, kind, nil, "Interface\\FriendsFrame\\StatusIcon-Offline")
    local disp = HKDT.StripBattleTag(authorText or "Friend")
    frame._title:SetText(HKDT.ColoredText(kind, disp))

  elseif kind == "KEY" then
    HKDT.SetKindIcon(frame, kind, "poi-saltherilssoiree", "Interface\\Icons\\INV_Relic_Hourglass", true)
    frame._title:SetText(HKDT.ColoredText(kind, compact and "New Key:" or "New Key"))

  else
    local usedPortrait = false
    if kind == "WHISPER" and meta and meta.unit then
      usedPortrait = HKDT.SetPortraitIcon(frame, meta.unit) and true or false
      if usedPortrait then frame._icon:SetVertexColor(1,1,1,1) end
    end

    if not usedPortrait then
      HKDT.SetKindIcon(frame, kind, "common-icon-speak")
    end

    local db = HKDT.DB
    local streamer = db and db.layout and db.layout.streamerMode

    local disp = authorText or "Whisper"
    if streamer and kind == "WHISPER" then
      disp = HKDT.StripRealm(disp)
    end

    frame._title:SetText(HKDT.ColoredText(kind, disp))
  end
end

function HKDT.RefreshActiveStyle()
  local DB = HKDT.DB
  for _, fr in ipairs(HKDT.Active) do
    HKDT.ApplyToastBackdrop(fr)
    HKDT.ApplyToastBorder(fr, fr._kind)
    HKDT.ApplyToastBackground(fr)
    HKDT.ApplyToastFont(fr)
    if fr._ApplyInternalLayout then
      fr:_ApplyInternalLayout()
    end

    local compact = DB and DB.layout and DB.layout.compact

    local titleText
    if fr._kind == "MAIL" then
      titleText = "Mail"
    elseif fr._kind == "VAULT" then
      titleText = compact and "Vault" or "Great Vault"
    elseif fr._kind == "REMINDER" then
      titleText = "Reminder"
    elseif fr._kind == "SYSTEM" then
      titleText = compact and "Reset" or "Daily Reset"
    elseif fr._kind == "BNET" then
      titleText = HKDT.StripBattleTag(fr._author or "BNet")
    elseif fr._kind == "FRIEND_ON" or fr._kind == "FRIEND_OFF" then
      titleText = HKDT.StripBattleTag(fr._author or "Friend")
    else
      titleText = fr._author or "Whisper"
    end

    if (DB and DB.layout and DB.layout.streamerMode) and fr._kind == "WHISPER" then
      titleText = HKDT.StripRealm(titleText)
    end

    fr._title:SetText(HKDT.ColoredText(fr._kind, titleText))
  end
end

-- ---------------------------------------------------------
-- [05.7.1] Icon Packs (WOW vs FLAT)
-- ---------------------------------------------------------
HKDT.FLAT_ICONS = {
  MAIL       = "mail.tga",
  BNET       = "bnet.tga",
  VAULT      = "vault.tga",
  REMINDER   = "reminder.tga",
  SYSTEM     = "dailyreset.tga",

  DURA70     = "armor70.tga",
  DURA30     = "armor30.tga",
  DURA10     = "armor10.tga",

  BAG90      = "bag90.tga",
  BAGFULL    = "bagfull.tga",

  FRIEND_ON  = "friendON.tga",
  FRIEND_OFF = "friendOFF.tga",

  WHISPER    = "whisper.tga",
  KEY        = "mkey.tga",
}




HKDT.WOWSKIN_ICONS = {
  MAIL       = "mail.tga",
  BNET       = "bnetmessage.tga",   
  VAULT      = "vault.tga",
  REMINDER   = "reminder.tga",
  SYSTEM     = "dailyreset.tga",
  DURA70     = "repair.tga",
  DURA30     = "repair.tga",
  DURA10     = "repair.tga",
  BAG90      = "inventoryfull.tga", 
  BAGFULL    = "inventoryfull.tga",
  FRIEND_ON  = "bnetON.tga",        
  FRIEND_OFF = "bnetOFFdark.tga",   
  WHISPER    = "whisper.tga",
  KEY        = "mkey.tga",
}

local function GetIconPack()
  -- forced packs by toast skin
  local skinKey = GetToastSkin()
  if skinKey == "EVERGREEN" then pack = "WOW" end
if skinKey == "LINE" then pack = "FLAT" end

  local db = HKDT.DB
  return (db and db.layout and db.layout.iconPack) or "WOW"
end

local function GetFlatBasePath()
  local addon = HKDT.ADDON_NAME or "HKDToasts"
  return "Interface\\AddOns\\" .. addon .. "\\Media\\Icons\\"
end

function HKDT.SetKindIcon(frame, kind, atlas, fallbackTexture, useAtlasSize)
  if not frame or not frame._icon then return end

  local pack = GetIconPack()

  -- 1) FLAT: sempre usa TGAs do pack FLAT (independente da skin)
  if pack == "FLAT" then
    local file = HKDT.FLAT_ICONS[kind] or "default.tga"
    frame._icon:SetTexture(GetFlatBasePath() .. file)

    local c = HKDT.GetKindColor(kind)
    if c then
      frame._icon:SetVertexColor(c.r, c.g, c.b, 1)
    else
      frame._icon:SetVertexColor(1, 1, 1, 1)
    end
    return
  end

  -- 2) WOW: sempre tenta Atlas (independente de WOW/JOURNEY/NOFRAME/MODERN)
  HKDT.SetIcon(frame, atlas, fallbackTexture, useAtlasSize)
  frame._icon:SetVertexColor(1,1,1,1)
end

-- ---------------------------------------------------------
-- [05.8] Stacking / reflow
-- ---------------------------------------------------------
function HKDT.Reflow()
  local DB = HKDT.DB
  if not DB then return end
  local sign = HKDT.StackSign()
  local step = ((HKDT.Active[1] and HKDT.Active[1]:GetHeight()) or (DB.height + (DB.stackGap or 10))) + (DB.stackGap or 10)
  step = step * sign

  for i, fr in ipairs(HKDT.Active) do
    fr._stackOffset = (i - 1) * step
    HKDT.SetFramePosition(fr)
  end

  HKDT.RefreshAnchor()
end

function HKDT.RemoveActive(frame)
  for i = 1, #HKDT.Active do
    if HKDT.Active[i] == frame then
      table.remove(HKDT.Active, i)
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------
-- [05.9] Animation per-frame
-- ---------------------------------------------------------
function HKDT.GetAnimMode()
  local DB = HKDT.DB
  if DB and DB.animations and DB.animations.mode then
    return DB.animations.mode
  end
  return "FADE_SLIDE_UP"
end

function HKDT.GetInOffsets(mode)
  if mode == "FADE" then
    return 0, 0, 1.0
  elseif mode == "FADE_SLIDE_UP" then
    return 0, -8, 1.0
  elseif mode == "FADE_SLIDE_DOWN" then
    return 0, 8, 1.0
  elseif mode == "FADE_SLIDE_LEFT" then
    return -18, 0, 1.0
  elseif mode == "FADE_SLIDE_RIGHT" then
    return 18, 0, 1.0
  elseif mode == "GROW" then
    return 0, 0, 0.06
  end
  return 0, -8, 1.0
end

function HKDT.GetOutOffsets(mode)
  if mode == "FADE" then
    return 0, 0, 1.0
  elseif mode == "FADE_SLIDE_UP" then
    return 0, -6, 1.0
  elseif mode == "FADE_SLIDE_DOWN" then
    return 0, 6, 1.0
  elseif mode == "FADE_SLIDE_LEFT" then
    return -12, 0, 1.0
  elseif mode == "FADE_SLIDE_RIGHT" then
    return 12, 0, 1.0
  elseif mode == "GROW" then
    return 0, 0, 0.6
  end
  return 0, -6, 1.0
end

function HKDT.StartToast(kind, authorText, msgText, meta, badgeExtra)
  local DB = HKDT.DB
  if not DB then return end

  EnsureLayoutDefaults()

  local fr = HKDT.AcquireFrame()
  HKDT.ApplyLayout(fr)

  if fr._ApplyInternalLayout then
    fr:_ApplyInternalLayout()
  end

  fr._msgText = (type(msgText) == "string" and msgText) or ""

  fr._stackKey = HKDT.BuildStackKey(kind, authorText, meta)
  fr._badgeCount = tonumber(badgeExtra) or 0
  HKDT.SetBadge(fr, fr._badgeCount)

  HKDT.SetToastStyle(fr, kind, authorText, meta)
  HKDT.UpdateText(fr, kind, authorText, msgText)

  local mode = HKDT.GetAnimMode()

  fr._animState = "IN"
  fr._t0 = GetTime()
  fr._animMode = (DB.animations and DB.animations.mode) or "FADE_SLIDE_UP"

  fr._paused = false
  fr._pauseAt = 0
  fr._pausedTotal = 0

  fr._baseScale = (DB and DB.scale) or 1.0

  local inX, inY, inS = HKDT.GetInOffsets(mode)
  fr._animOffsetX = inX
  fr._animOffsetY = inY

  fr:SetAlpha(0)
  fr:SetScale(fr._baseScale * inS)
  fr:Show()

  table.insert(HKDT.Active, 1, fr)
  HKDT.Reflow()

  HKDT.PlayToastSoundForKind(kind)

  fr:SetScript("OnUpdate", function(self)
    local DB = HKDT.DB
    if not DB then return end
    local now = GetTime()
    local modeNow = HKDT.GetAnimMode()

    if self._animState == "IN" then
      local ain = (DB.animIn and DB.animIn > 0) and DB.animIn or 0.18
      local p = HKDT.Clamp01((now - self._t0) / ain)
      local e = HKDT.EaseOutQuad(p)

      self:SetAlpha(e)

      local sx, sy, sScale = HKDT.GetInOffsets(modeNow)
      self._animOffsetX = sx * (1 - e)
      self._animOffsetY = sy * (1 - e)

      local base = self._baseScale or (DB.scale or 1.0)

      if modeNow == "GROW" then
        local curS = sScale + (1.05 - sScale) * e
        if p >= 0.85 then
          curS = 1.05 - ((p - 0.85) / 0.15) * 0.05
        end
        self:SetScale(base * curS)
      else
        local targetS = 1.0
        local curS = sScale + (targetS - sScale) * e
        self:SetScale(base * curS)
      end

      HKDT.SetFramePosition(self)

      if p >= 1 then
        self._animState = "HOLD"
        self._t0 = now
        self._pausedTotal = 0
        self:SetAlpha(1)
        self._animOffsetX = 0
        self._animOffsetY = 0
        self:SetScale(base * 1.0)
        HKDT.SetFramePosition(self)
      end

    elseif self._animState == "HOLD" then
      if self._paused then return end

      local elapsed = (now - self._t0) - (self._pausedTotal or 0)
      if elapsed >= (DB.duration or 3.2) then
        self._animState = "OUT"
        self._t0 = now
      end

    elseif self._animState == "OUT" then
      local aout = (DB.animOut or 0.22)
      if aout <= 0 then aout = 0.01 end

      local p = HKDT.Clamp01((now - self._t0) / aout)
      local e = 1 - HKDT.EaseOutQuad(p)

      self:SetAlpha(e)

      local ox, oy, endS = HKDT.GetOutOffsets(modeNow)

      if modeNow == "GROW" then
        endS = endS or 0.06
        if endS < 0.01 then endS = 0.01 end

        local base = self._baseScale or (DB.scale or 1.0)
        local curS = 1.0 + (endS - 1.0) * (1 - e)
        self:SetScale(base * HKDT.ClampScale(curS))
      end

      self._animOffsetX = (ox or 0) * (1 - e)
      self._animOffsetY = (oy or 0) * (1 - e)
      HKDT.SetFramePosition(self)

      if p >= 1 then
        self:SetScript("OnUpdate", nil)

        HKDT.RemoveActive(self)
        HKDT.ReleaseFrame(self)
        HKDT.Reflow()

        if #HKDT.Queue > 0 and #HKDT.Active < (DB.maxVisible or 3) then
          local item = table.remove(HKDT.Queue, 1)
          HKDT.StartToast(item.kind, item.author, item.msg, item.meta, item.badge)
        end
      end
    end
  end)
end

-- ---------------------------------------------------------
-- Combat Lockdown (queue during combat)
-- ---------------------------------------------------------
HKDT.IN_COMBAT = HKDT.IN_COMBAT or false
HKDT.POST_COMBAT_QUEUE = HKDT.POST_COMBAT_QUEUE or {}
HKDT.FLUSH_TICKER = HKDT.FLUSH_TICKER or nil

function HKDT.IsInCombat()
  return HKDT.IN_COMBAT or InCombatLockdown()
end

function HKDT.QueuePostCombat(payload)
  HKDT.POST_COMBAT_QUEUE[#HKDT.POST_COMBAT_QUEUE + 1] = payload
end

function HKDT.CancelFlushTicker()
  if HKDT.FLUSH_TICKER and HKDT.FLUSH_TICKER.Cancel then
    HKDT.FLUSH_TICKER:Cancel()
  end
  HKDT.FLUSH_TICKER = nil
end

function HKDT.FlushPostCombatQueue()
  if HKDT.IsInCombat() then return end
  if not HKDT.POST_COMBAT_QUEUE or #HKDT.POST_COMBAT_QUEUE == 0 then
    HKDT.CancelFlushTicker()
    return
  end

  if not C_Timer or not C_Timer.NewTicker then
    while #HKDT.POST_COMBAT_QUEUE > 0 do
      local p = table.remove(HKDT.POST_COMBAT_QUEUE, 1)
      HKDT.EnqueueRaw(p.kind, p.author, p.msg, p.meta)
    end
    return
  end

  HKDT.CancelFlushTicker()
  HKDT.FLUSH_TICKER = C_Timer.NewTicker(0.12, function()
    if HKDT.IsInCombat() then return end
    if #HKDT.POST_COMBAT_QUEUE == 0 then
      HKDT.CancelFlushTicker()
      return
    end

    for _ = 1, 2 do
      if #HKDT.POST_COMBAT_QUEUE == 0 then break end
      local p = table.remove(HKDT.POST_COMBAT_QUEUE, 1)
      HKDT.EnqueueRaw(p.kind, p.author, p.msg, p.meta)
    end
  end)
end

-- ---------------------------------------------------------
-- [05.10] Queueing (HARD SANITIZE)
-- ---------------------------------------------------------

-- Known kinds map (fast lookup)
HKDT.KNOWN_KINDS = HKDT.KNOWN_KINDS or {
  WHISPER=true, BNET=true, MAIL=true, VAULT=true, REMINDER=true, SYSTEM=true,
  DURA70=true, DURA30=true, DURA10=true,
  BAG90=true, BAGFULL=true,
  FRIEND_ON=true, FRIEND_OFF=true,
  KEY=true,
}

local function IsKnownKind(k)
  return type(k) == "string" and HKDT.KNOWN_KINDS[k] == true
end

local function ToStr(v)
  if v == nil then return "" end
  if type(v) == "string" then return v end
  if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  -- table/function/etc: don't concat explode
  return ""
end

-- Fixes:
-- 1) swapped args (kind/author)
-- 2) msgText accidentally passed as meta table
-- 3) non-string msgText causing concat errors
-- 4) lowercase kinds
function HKDT.NormalizeEnqueueArgs(kind, authorText, msgText, meta)
  -- if msgText is actually meta table
  if type(msgText) == "table" and meta == nil then
    meta = msgText
    msgText = ""
  end

  -- if authorText is actually meta table (rare)
  if type(authorText) == "table" and meta == nil then
    meta = authorText
    authorText = ""
  end

  -- normalize kind to uppercase if string
  if type(kind) == "string" then
    kind = kind:upper()
  end

  -- swapped call? (kind came as "Hakoda-Azralon", author came as "MAIL")
  if not IsKnownKind(kind) and type(authorText) == "string" then
    local maybeKind = authorText:upper()
    if IsKnownKind(maybeKind) then
      -- swap
      authorText, kind = kind, maybeKind
    end
  end

  -- final coercions
  authorText = ToStr(authorText)
  msgText    = ToStr(msgText)

  -- ensure meta is table or nil
  if meta ~= nil and type(meta) ~= "table" then meta = nil end

  -- fallback kind
  if not IsKnownKind(kind) then
    kind = "SYSTEM"
  end

  return kind, authorText, msgText, meta
end

-- internal raw enqueue (no combat logic)
function HKDT.EnqueueRaw(kind, authorText, msgText, meta)
  local DB = HKDT.DB
  if not DB then return end

  kind, authorText, msgText, meta = HKDT.NormalizeEnqueueArgs(kind, authorText, msgText, meta)

  -- intelligent stack badge for WHISPER/BNET
  if kind == "WHISPER" or kind == "BNET" then
    if HKDT.TryStackToExisting(kind, authorText, msgText, meta) then
      HKDT.PlayToastSoundForKind(kind)
      return
    end
  end

  local maxV = (DB and DB.maxVisible) or 3
  if #HKDT.Active < maxV then
    HKDT.StartToast(kind, authorText, msgText, meta, 0)
  else
    table.insert(HKDT.Queue, {
      kind = kind,
      author = authorText,
      msg = msgText,
      meta = meta,
      stackKey = HKDT.BuildStackKey(kind, authorText, meta),
      badge = 0,
    })
  end
end

-- public enqueue (combat queue)
function HKDT.Enqueue(kind, authorText, msgText, meta)
  local DB = HKDT.DB
  if not DB then return end

  kind, authorText, msgText, meta = HKDT.NormalizeEnqueueArgs(kind, authorText, msgText, meta)

  if HKDT.IsInCombat() then
    HKDT.QueuePostCombat({ kind = kind, author = authorText, msg = msgText, meta = meta })
    return
  end

  HKDT.EnqueueRaw(kind, authorText, msgText, meta)
end

-- <<< HKDT: SECTION [05]