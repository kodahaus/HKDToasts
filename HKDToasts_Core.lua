local ADDON_NAME = ...

-- Shared addon namespace (single table across all files)
local HKDT = _G.HKDT
if not HKDT then
  HKDT = {}
  _G.HKDT = HKDT
end

HKDToastsDB = HKDToastsDB or {}

-- >>> HKDT: SECTION [01] DEFAULTS & DB BOOTSTRAP
HKDT.DEFAULTS = {
  point = "CENTER",
  relPoint = "CENTER",
  x = 0,
  y = 180,

  scale = 1.0,
  width = 360,
  height = 56,

  duration = 3.2,
  animIn = 0.18,
  animOut = 0.22,

  animations = {
    mode = "FADE_SLIDE_UP",
  },

  locked = false,
  
  minimap = {
  hide = false,
},

layout = {
  compact = false,
  compactMinWidth = 260,
  iconSide = "LEFT",
  iconPack = "FLAT",
  toastSkin = "MODERN",
  wowVariant = "DARK",     -- ✅ ADD
  font = "GameFontNormal",
},

  modules = {
    vault      = true,
    dailyReset = true,
    reminders  = true,
    durability = true,
    friends    = true,
	bags = true,
	keys = true,
	streamerMode = false,
streamer = {
  hideNames = false,       -- troca nomes por "Someone"
  hideContent = false,    -- se true: troca a mensagem por "New message"
  hideRealms = true,      -- remove "-Realm"
  keepLinks = true,       -- se false: remove links |H...|h
},
  },

  reminders = {},

  maxVisible = 3,
  stackGap = 10,
  grow = "DOWN",

  borderAlpha = 0.85,
  colors = {
    whisper  = { r = 1.00, g = 0.50, b = 1.00 },
    bnet     = { r = 0.00, g = 1.00, b = 0.96 },
    mail     = { r = 0.82, g = 0.68, b = 0.28 },
    vault    = { r = 1.00, g = 0.99, b = 0.45 },
    daily    = { r = 0.35, g = 0.67, b = 0.95 },
    reminder = { r = 0.92, g = 0.62, b = 1.00 },

    dura70   = { r = 1.00, g = 0.50, b = 0.10 },
    dura30   = { r = 1.00, g = 0.20, b = 0.20 },
    dura10   = { r = 1.00, g = 0.05, b = 0.05 },
	
	bag90   = { r = 1.00, g = 0.50, b = 0.10 },
    bagfull = { r = 1.00, g = 0.20, b = 0.20 },

    friendOn  = { r = 0.00, g = 1.00, b = 0.96 },
    friendOff = { r = 0.55, g = 0.62, b = 0.75 },
	
	key = { r = 0.26, g = 0.95, b = 0.56 },
  },

  bg = { r = 0.00, g = 0.00, b = 0.00, a = 0.92 },

  sounds = {
    enabled = true,

    whisper  = true,
    bnet     = true,
    mail     = true,
    vault    = true,
    daily    = true,
    reminder = true,

    dura70   = true,
    dura30   = true,
    dura10   = true,
	
	bag90   = true,
	bagfull = true,	

    friendOn  = true,
    friendOff = true,
	
	key = true,

    ids = {
      whisper   = 3081,
      bnet      = 111366,
      mail      = 1192,
      vault     = 12188,
      daily     = 4574,
      reminder  = 258818,

      dura70    = 175002,
      dura30    = 175002,
      dura10    = 175002,
	  
	  bag90   = 859,
	  bagfull = 859,

      friendOn  = 111363,
      friendOff = 111362,
	  
	  key = 187884,
    },

    channel = "SFX",
  },
}

function HKDT.CopyDefaults(src, dst)
  if type(src) ~= "table" then
    return dst
  end

  if type(dst) ~= "table" then
    dst = {}
  end

  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then
        dst[k] = {}
      end
      HKDT.CopyDefaults(v, dst[k])
    else
      if dst[k] == nil then
        dst[k] = v
      end
    end
  end

  return dst
end

HKDT.DB = nil

-- SKINS

HKDT.SKINS = {

  MODERN = {
    type = "MODERN",
    bg = { r=0, g=0, b=0, a=0.92 },
    borderAlpha = 0.85,
    textMode = "COLORED",
  },

  WOW_DARK = {
    type = "WOW",
    variant = "DARK",
    textMode = "PLAIN",
  },

  WOW_LIGHT = {
    type = "WOW",
    variant = "LIGHT",
    textMode = "PLAIN",
  },

}

function HKDT.GetSkin()
  local db = HKDT.DB
  if not db or not db.layout then return HKDT.SKINS.MODERN end

  local key = db.layout.toastSkin or "MODERN"
  if key == "WOW" then
    local v = db.layout.wowVariant or "DARK"
    if v == "LIGHT" then return HKDT.SKINS.WOW_LIGHT end
    return HKDT.SKINS.WOW_DARK
  end

  return HKDT.SKINS[key] or HKDT.SKINS.MODERN
end


-- Color constants (exported)
HKDT.C_ACCENT = HKDT.C_ACCENT or "|cffEA4581"
HKDT.C_MUTED  = HKDT.C_MUTED  or "|cff9aa4b2"
HKDT.C_RESET  = HKDT.C_RESET  or "|r"

-- Reload popup helper
function HKDT.ShowReloadPopup()
  if not StaticPopupDialogs["HKDTOASTS_RELOAD_REQUIRED"] then
    StaticPopupDialogs["HKDTOASTS_RELOAD_REQUIRED"] = {
      text = "You need to reload the game for this change to take effect.",
      button1 = "OK",
      button2 = "Cancel",
      OnAccept = function()
        ReloadUI()
      end,
      OnCancel = function()
        -- Do nothing
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end

  StaticPopup_Show("HKDTOASTS_RELOAD_REQUIRED")
end



-- >>> HKDT: SECTION [02] SMALL UTILITIES (COLORS / MATH / HELPERS)
function HKDT.Hex(r,g,b)
  local function to255(x)
    x = (tonumber(x) or 0)
    if x < 0 then x = 0 end
    if x > 1 then x = 1 end
    return math.floor(x * 255 + 0.5)
  end
  return string.format("|cff%02x%02x%02x", to255(r), to255(g), to255(b))
end

HKDT.C_RESET  = "|r"
HKDT.C_ACCENT = HKDT.Hex(0.36, 0.78, 1.0)
HKDT.C_MUTED  = HKDT.Hex(0.75, 0.78, 0.82)

function HKDT.Clamp01(x)
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

function HKDT.ClampScale(x)
  if x == nil then return 0.01 end
  if x < 0.01 then return 0.01 end
  return x
end

function HKDT.EaseOutQuad(x)
  return 1 - (1 - x) * (1 - x)
end

function HKDT.StackSign()
  local DB = HKDT.DB
  if DB and DB.grow == "UP" then return 1 end
  return -1
end

-- streamer herlpers
local function StripLinks(s)
  if not s or s == "" then return s end
  -- remove links do WoW: |H...|h[Texto]|h
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("|H.-|h(.-)|h", "%1")
  return s
end

local function StripRealm(name)
  if not name then return name end
  -- "Player-Realm" -> "Player"
  return name:gsub("%-.*$", "")
end

function HKDT_Sanitize(kind, title, body, meta)
  -- meta pode ter sender, bnetName, etc (se você já usa)
  local db = HKDToastsDB
  if not db or not db.streamerMode then
    return title, body, meta
  end

  db.streamer = db.streamer or {}
  local opt = db.streamer

  meta = meta or {}

  -- Links
  if opt.keepLinks == false then
    title = StripLinks(title)
    body  = StripLinks(body)
  end

  -- Conteúdo
  if opt.hideContent then
    body = "New message"
  end

  -- Nomes / Realms (principalmente whisper/bnet)
  if kind == "whisper" or kind == "bnet" then
    if opt.hideRealms then
      if meta.sender then meta.sender = StripRealm(meta.sender) end
      if meta.bnetName then meta.bnetName = StripRealm(meta.bnetName) end
    end

    if opt.hideNames then
      -- limpa title/body de ocorrências “óbvias” (sem precisar saber o formato exato)
      if meta.sender and meta.sender ~= "" then
        title = title and title:gsub(meta.sender, "Someone") or title
        body  = body  and body:gsub(meta.sender, "Someone") or body
      end
      if meta.bnetName and meta.bnetName ~= "" then
        title = title and title:gsub(meta.bnetName, "Someone") or title
        body  = body  and body:gsub(meta.bnetName, "Someone") or body
      end

      -- fallback agressivo: se teu title é tipo "Whisper from X" / "X says"
      title = title and title:gsub("from%s+.+$", "from Someone") or title
      title = title and title:gsub("^.+%s+says$", "Someone says") or title
    end
  end

  return title, body, meta
end

-- Fonts / LibSharedMedia
HKDT.LSM = nil
function HKDT.GetLSM()
  if HKDT.LSM ~= nil then return HKDT.LSM end
  if LibStub and LibStub.GetLibrary then
    HKDT.LSM = LibStub:GetLibrary("LibSharedMedia-3.0", true)
  end
  return HKDT.LSM
end

-- Fonts fallback (non-LSM) shipped with the addon
HKDT.FALLBACK_FONTS = {
  ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
  ["Arial Narrow"]           = "Fonts\\ARIALN.TTF",
  ["Morpheus"]               = "Fonts\\MORPHEUS.ttf",

  -- addon bundled
  ["Homespun"]               = "Interface\\AddOns\\HKDToasts\\Media\\Fonts\\Homespun.ttf",
  ["Expressway"]             = "Interface\\AddOns\\HKDToasts\\Media\\Fonts\\Expressway.ttf",
  ["PTSansNarrow"]           = "Interface\\AddOns\\HKDToasts\\Media\\Fonts\\PTSansNarrow.ttf",
  ["Friz Quadrata"] = "Interface\\AddOns\\HKDToasts\\Media\\Fonts\\FrizQuadrata.ttf",
}

function HKDT.GetFontPathByKey(fontKey)
  -- 1) LSM fonts
  local lsm = HKDT.GetLSM()
  if lsm and fontKey and fontKey ~= "" then
    local tbl = lsm:HashTable("font")
    if tbl and tbl[fontKey] then
      return tbl[fontKey], fontKey
    end
  end

  -- 2) Addon fallback fonts (non-LSM)
  if fontKey and fontKey ~= "" and HKDT.FALLBACK_FONTS and HKDT.FALLBACK_FONTS[fontKey] then
    return HKDT.FALLBACK_FONTS[fontKey], fontKey
  end

  -- 3) GameFontNormal path (client default)
  local gf = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
  if gf then
    return gf, "GameFontNormal"
  end

  -- 4) Absolute last fallback
  return "Fonts\\FRIZQT__.TTF", "Friz Quadrata"
end

function HKDT.GetFontList()
  local out, seen = {}, {}

  local function add(name, path)
    if not name or name == "" or seen[name] then return end
    seen[name] = true
    out[#out+1] = { name = name, path = path }
  end

  -- 1) LSM
  local lsm = HKDT.GetLSM()
  if lsm then
    local tbl = lsm:HashTable("font")
    if tbl then
      for name, path in pairs(tbl) do
        add(name, path)
      end
    end
  end

  -- 2) fallback fonts
  if HKDT.FALLBACK_FONTS then
    for name, path in pairs(HKDT.FALLBACK_FONTS) do
      add(name, path)
    end
  end

  -- 3) GameFontNormal
  local gf = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
  if gf then
    add("GameFontNormal", gf)
  end

  table.sort(out, function(a,b) return a.name < b.name end)
  return out
end
-- <<< HKDT: SECTION [02]




-- =========================================================
-- Minimap Icon (LibDataBroker + LibDBIcon)
-- =========================================================
HKDT.MINIMAP_LDB_NAME = "HKDToasts"
HKDT.MINIMAP_ICON_PATH = "Interface\\AddOns\\HKDToasts\\Media\\Icons\\Toast.tga"

local function GetDBSafe()
  return HKDT.DB or HKDToastsDB
end

function HKDT.SetMinimapHidden(hidden)
  local db = GetDBSafe()
  db.minimap = db.minimap or {}
  db.minimap.hide = hidden and true or false

  local ok, LDB = pcall(LibStub, "LibDataBroker-1.1", true)
  local ok2, DBIcon = pcall(LibStub, "LibDBIcon-1.0", true)
  if ok2 and DBIcon then
    if db.minimap.hide then
      DBIcon:Hide(HKDT.MINIMAP_LDB_NAME)
    else
      DBIcon:Show(HKDT.MINIMAP_LDB_NAME)
    end
  end
end

function HKDT.ToggleLock()
  local db = GetDBSafe()
  db.locked = not db.locked

  if HKDT.RefreshLockChip then HKDT.RefreshLockChip() end
  if HKDT.RefreshAnchor then HKDT.RefreshAnchor() end
  if HKDT.Reflow then HKDT.Reflow() end

  print("HKDToasts: " .. (db.locked and "locked." or "unlocked."))
end

function HKDT.RegisterMinimapIcon()
  local db = GetDBSafe()
  db.minimap = db.minimap or { hide = false }

  local LDB = LibStub("LibDataBroker-1.1", true)
  local DBIcon = LibStub("LibDBIcon-1.0", true)
  if not LDB or not DBIcon then return end

  if not HKDT._minimapObj then
    HKDT._minimapObj = LDB:NewDataObject(HKDT.MINIMAP_LDB_NAME, {
      type = "data source",
      text = "HKDToasts",
      icon = HKDT.MINIMAP_ICON_PATH,

      OnClick = function(_, button)
        if button == "LeftButton" then
          if HKDT.ToggleConfig then
            HKDT.ToggleConfig()
          else
            print("HKDToasts: config not ready yet.")
          end
        elseif button == "RightButton" then
          HKDT.ToggleLock()
        end
      end,

      OnTooltipShow = function(tt)
        if not tt or not tt.AddLine then return end
        tt:AddLine("HKDToasts")
        tt:AddLine("Left-click: Open Config", 1,1,1)
        tt:AddLine("Right-click: Lock/Unlock", 1,1,1)
      end,
    })
  end

  if not DBIcon:IsRegistered(HKDT.MINIMAP_LDB_NAME) then
    DBIcon:Register(HKDT.MINIMAP_LDB_NAME, HKDT._minimapObj, db.minimap)
  end

  if db.minimap.hide then
    DBIcon:Hide(HKDT.MINIMAP_LDB_NAME)
  else
    DBIcon:Show(HKDT.MINIMAP_LDB_NAME)
  end
end

-- Register after login (safe timing)
local mmEvt = CreateFrame("Frame")
mmEvt:RegisterEvent("PLAYER_LOGIN")
mmEvt:SetScript("OnEvent", function()
  if HKDT.RegisterMinimapIcon then
    HKDT.RegisterMinimapIcon()
  end
end)



-- >>> HKDT: SECTION [03] KIND ROUTING
function HKDT.GetKindColor(kind)
  local DB = HKDT.DB
  if not DB or not DB.colors then return nil end

  if kind == "MAIL"    then return DB.colors.mail end
  if kind == "BNET"    then return DB.colors.bnet end
  if kind == "WHISPER" then return DB.colors.whisper end

  if kind == "VAULT"    then return DB.colors.vault end
  if kind == "SYSTEM"   then return DB.colors.daily end
  if kind == "REMINDER" then return DB.colors.reminder end

  if kind == "DURA70" then return DB.colors.dura70 end
  if kind == "DURA30" then return DB.colors.dura30 end
  if kind == "DURA10" then return DB.colors.dura10 end
  
  if kind == "BAG90"   then return DB.colors.bag90 end
  if kind == "BAGFULL" then return DB.colors.bagfull end

  if kind == "FRIEND_ON"  then return DB.colors.friendOn end
  if kind == "FRIEND_OFF" then return DB.colors.friendOff end
  
  if kind == "KEY" then return DB.colors.key end

  return DB.colors.whisper
end

function HKDT.ColoredText(kind, text)
  if text == nil then return "" end
  local s = HKDT.GetSkin()
  if s and s.type == "WOW" then
    return tostring(text)
  end

  if kind == nil then return tostring(text) end
  local c = HKDT.GetKindColor(kind)
  if not c then return tostring(text) end
  return HKDT.Hex(c.r, c.g, c.b) .. tostring(text) .. HKDT.C_RESET
end

 

function HKDT.ColorDurabilityNumber(kind, text)
  if not text then return text end

  local c = HKDT.GetKindColor(kind)
  if not c then return text end

  local hex = HKDT.Hex(c.r, c.g, c.b)

  if text:match("%d+%%") then
    return (text:gsub("(%d+)%%", function(n)
      return hex .. n .. "%" .. HKDT.C_RESET
    end, 1))
  end

  return (text:gsub("(%d+)", function(n)
    return hex .. n .. "%" .. HKDT.C_RESET
  end, 1))
end
-- <<< HKDT: SECTION [03]

-- >>> HKDT: SECTION [04] SOUND SYSTEM
HKDT.lastSoundAtByKey = {}
HKDT.SOUND_COOLDOWN = 0.25

function HKDT.PlayToastSoundForKind(kind)
  local DB = HKDT.DB
  if not DB or not DB.sounds or not DB.sounds.enabled then return end
  if not kind then return end

  local s = DB.sounds
  local key

  if kind == "WHISPER" then key = "whisper"
  elseif kind == "BNET" then key = "bnet"
  elseif kind == "MAIL" then key = "mail"
  elseif kind == "VAULT" then key = "vault"
  elseif kind == "SYSTEM" then key = "daily"
  elseif kind == "REMINDER" then key = "reminder"
  elseif kind == "DURA70" then key = "dura70"
  elseif kind == "DURA30" then key = "dura30"
  elseif kind == "DURA10" then key = "dura10"
  elseif kind == "BAG90" then key = "bag90"
  elseif kind == "BAGFULL" then key = "bagfull"
  elseif kind == "FRIEND_ON" then key = "friendOn"
  elseif kind == "FRIEND_OFF" then key = "friendOff"
  elseif kind == "KEY" then key = "key"
  else
    return
  end

  if s[key] == false then return end

  local id = s.ids and s.ids[key]
  if not id then return end

  local now = GetTime()
  local last = HKDT.lastSoundAtByKey[key] or 0
  if (now - last) < HKDT.SOUND_COOLDOWN then return end
  HKDT.lastSoundAtByKey[key] = now

  local channel = s.channel or "SFX"

-- Esses dois kits são chatos: em alguns clients só saem audíveis no Master
if id == 111362 or id == 111363 then
  channel = "Master"
end

PlaySound(id, channel)
end
-- <<< HKDT: SECTION [04]
