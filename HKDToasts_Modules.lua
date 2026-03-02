-- HKDToasts_Modules.lua
-- Feature modules: whispers/bnet, mail, vault, daily reset, reminders, durability, friends + Blizzard toast suppression

local HKDT = _G.HKDT
if not HKDT then return end

local function Enqueue(kind, author, msg, meta)
  if HKDT and HKDT.Enqueue then
    return HKDT.Enqueue(kind, author, msg, meta)
  end
end

local FindUnitForAuthor = HKDT.FindUnitForAuthor

local function DB() return HKDT.DB end

-- Color constants (for any prints that might live here)
local C_ACCENT = HKDT.C_ACCENT or ""
local C_RESET  = HKDT.C_RESET  or ""

-- =========================================================
-- [06] MESSAGE HANDLERS (WHISPER / BNET)
-- =========================================================
local function HandleWhisper(author, msg)
  local unit = FindUnitForAuthor and FindUnitForAuthor(author) or nil
  Enqueue("WHISPER", author, msg, { unit = unit })
end

local function HandleBNWhisper(author, msg, bnetIDAccount)
  Enqueue("BNET", author, msg, { bnetIDAccount = bnetIDAccount })
end

HKDT.HandleWhisper   = HandleWhisper
HKDT.HandleBNWhisper = HandleBNWhisper

-- =========================================================
-- [07] FEATURE MODULES
-- =========================================================

-- ---------------------------------------------------------
-- [07.1] Mail (login-only-if-has + new mail while playing)
-- ---------------------------------------------------------
local mailLastToastAt    = 0
local MAIL_COALESCE      = 1.00

local mailLoginGrace     = true
local mailLoginTimer     = nil
local mailStabilizeTimer = nil
local mailKnownState     = false
local mailLoginChecked   = false

local function IsMailboxOpen()
  return (MailFrame and MailFrame.IsShown and MailFrame:IsShown()) and true or false
end

local function CancelTimer(t)
  if t and t.Cancel then t:Cancel() end
end

local function FireMailToast()
  local now = GetTime()
  if (now - (mailLastToastAt or 0)) < MAIL_COALESCE then return end
  mailLastToastAt = now
  Enqueue("MAIL", nil, "You have new mail to open.")
end

local function ReadHasNewMail()
  if not HasNewMail then return false end
  return HasNewMail() and true or false
end

local function EndLoginGrace()
  mailLoginGrace = false
end

local function StartLoginMailCheck()
  mailLoginGrace = true
  mailLoginChecked = false

  CancelTimer(mailLoginTimer)
  mailLoginTimer = nil

  if not C_Timer or not C_Timer.NewTimer then
    mailKnownState = ReadHasNewMail()
    mailLoginChecked = true
    EndLoginGrace()
    if mailKnownState and not IsMailboxOpen() then
      FireMailToast()
    end
    return
  end

  mailLoginTimer = C_Timer.NewTimer(1.35, function()
    mailLoginTimer = nil
    mailKnownState = ReadHasNewMail()
    mailLoginChecked = true

    C_Timer.NewTimer(0.30, EndLoginGrace)

    if mailKnownState and not IsMailboxOpen() then
      FireMailToast()
    end
  end)
end

local function StabilizeMailStateSoon()
  CancelTimer(mailStabilizeTimer)
  mailStabilizeTimer = nil

  if not C_Timer or not C_Timer.NewTimer then
    mailKnownState = ReadHasNewMail()
    return
  end

  mailStabilizeTimer = C_Timer.NewTimer(0.12, function()
    mailStabilizeTimer = nil
    mailKnownState = ReadHasNewMail()
  end)
end

-- ✅ Always toast whenever the event fires AND there is new mail (coalesce prevents spam)
local function OnPendingMailEvent()
  if mailLoginGrace then
    StabilizeMailStateSoon()
    return
  end
  if IsMailboxOpen() then
    StabilizeMailStateSoon()
    return
  end

  local nowHas = ReadHasNewMail()
  if nowHas then
    FireMailToast()
  end

  mailKnownState = nowHas
end

local function OnMailboxInboxUpdate()
  mailKnownState = ReadHasNewMail()
end

local function Mail_ResetState()
  mailLastToastAt = 0
  mailKnownState = ReadHasNewMail()
  mailLoginGrace = true
  mailLoginChecked = false
  CancelTimer(mailLoginTimer)
  CancelTimer(mailStabilizeTimer)
  mailLoginTimer = nil
  mailStabilizeTimer = nil
end

local function Mail_IsLoginChecked()
  return mailLoginChecked and true or false
end

HKDT.StartLoginMailCheck   = StartLoginMailCheck
HKDT.OnPendingMailEvent    = OnPendingMailEvent
HKDT.OnMailboxInboxUpdate  = OnMailboxInboxUpdate
HKDT.Mail_ResetState       = Mail_ResetState
HKDT.Mail_IsLoginChecked   = Mail_IsLoginChecked

-- ---------------------------------------------------------
-- [07.2] Great Vault (login retry so it can fire BEFORE opening Vault UI)
-- ---------------------------------------------------------
local vaultNotifiedThisSession = false
local vaultRetryTicker = nil
local vaultRetryTries = 0

local function Vault_StopRetry()
  if vaultRetryTicker and vaultRetryTicker.Cancel then
    vaultRetryTicker:Cancel()
  end
  vaultRetryTicker = nil
  vaultRetryTries = 0
end

local function CheckVaultAndNotify(force)
  local db = DB()
  if not db or not db.modules or not db.modules.vault then return end
  if not C_WeeklyRewards or not C_WeeklyRewards.HasAvailableRewards then return end

  local ok = C_WeeklyRewards.HasAvailableRewards()
  if ok then
    if vaultNotifiedThisSession and not force then return end
    vaultNotifiedThisSession = true
    Enqueue("VAULT", nil, "Rewards available to claim.")
    Vault_StopRetry()
  end
end

local function Vault_StartRetry()
  local db = DB()
  if not db or not db.modules or not db.modules.vault then return end
  if not C_Timer or not C_Timer.NewTicker then return end
  if not C_WeeklyRewards or not C_WeeklyRewards.HasAvailableRewards then return end

  Vault_StopRetry()

-- Retry for ~60s (30 * 2s) without opening the Vault UI
  vaultRetryTries = 0
  vaultRetryTicker = C_Timer.NewTicker(2.0, function()
    vaultRetryTries = vaultRetryTries + 1
    CheckVaultAndNotify(false)

    if vaultRetryTries >= 30 then
      Vault_StopRetry()
    end
  end)
end

HKDT.CheckVaultAndNotify = CheckVaultAndNotify
HKDT.Vault_StartRetry   = Vault_StartRetry
HKDT.Vault_StopRetry    = Vault_StopRetry

-- ---------------------------------------------------------
-- [07.3] Daily reset scheduling
-- ---------------------------------------------------------
local dailyResetTimer

local function ScheduleDailyReset()
  if dailyResetTimer and dailyResetTimer.Cancel then
    dailyResetTimer:Cancel()
    dailyResetTimer = nil
  end

  local db = DB()
  if not db or not db.modules or not db.modules.dailyReset then return end
  if not C_DateAndTime or not C_DateAndTime.GetSecondsUntilDailyReset then return end
  if not C_Timer or not C_Timer.NewTimer then return end

  local secs = C_DateAndTime.GetSecondsUntilDailyReset()
  if not secs or secs <= 0 then secs = 60 end

  dailyResetTimer = C_Timer.NewTimer(secs + 1, function()
    local db2 = DB()
    if db2 and db2.modules and db2.modules.dailyReset then
      Enqueue("SYSTEM", nil, "Daily reset is live.")
    end
    ScheduleDailyReset()
  end)
end

HKDT.ScheduleDailyReset = ScheduleDailyReset

-- ---------------------------------------------------------
-- [07.4] Custom reminders ticker
-- ---------------------------------------------------------
local reminderTicker

local function EnsureReminderTicker()
  if reminderTicker and reminderTicker.Cancel then
    reminderTicker:Cancel()
    reminderTicker = nil
  end

  local db = DB()
  if not db or not db.modules or not db.modules.reminders then return end
  if not C_Timer or not C_Timer.NewTicker then return end

  db.reminders = db.reminders or {}

  reminderTicker = C_Timer.NewTicker(5, function()
    local db2 = DB()
    if not db2 or not db2.modules or not db2.modules.reminders then return end

    local now = GetTime()
    for _, r in ipairs(db2.reminders) do
      if r.enabled and r.minutes and r.text and r.text ~= "" then
        local interval = (tonumber(r.minutes) or 0) * 60
        if interval > 0 then
          r.last = r.last or 0
          if (now - r.last) >= interval then
            if r.repeats and tonumber(r.repeats) and tonumber(r.repeats) > 0 then
              r.remaining = tonumber(r.remaining) or tonumber(r.repeats)
              if r.remaining <= 0 then
                r.enabled = false
              else
                r.remaining = r.remaining - 1
                r.last = now
                Enqueue("REMINDER", nil, r.text)
                if r.remaining <= 0 then r.enabled = false end
              end
            else
              r.last = now
              Enqueue("REMINDER", nil, r.text)
            end
          end
        end
      end
    end
  end)
end

HKDT.EnsureReminderTicker = EnsureReminderTicker

-- ---------------------------------------------------------
-- [07.5] Durability module (70/30/10 thresholds)
-- ---------------------------------------------------------
local DURABILITY_SLOTS = {
  1,  -- HeadSlot
  3,  -- ShoulderSlot
  5,  -- ChestSlot
  6,  -- WaistSlot
  7,  -- LegsSlot
  8,  -- FeetSlot
  9,  -- WristSlot
  10, -- HandsSlot
  16, -- MainHandSlot
  17, -- SecondaryHandSlot
}

local duraLastPct = nil
local duraFired70 = false
local duraFired30 = false
local duraFired10 = false

local function GetLowestDurabilityPercent()
  local lowest = nil

  for _, slotId in ipairs(DURABILITY_SLOTS) do
    local cur, max = GetInventoryItemDurability(slotId)
    if cur and max and max > 0 then
      local pct = (cur / max) * 100
      if (lowest == nil) or (pct < lowest) then
        lowest = pct
      end
    end
  end

  return lowest -- can be nil if nothing trackable
end

local function ResetDurabilityFiresIfRepaired(pct)
  if not pct then return end
  if pct > 70 then
    duraFired70, duraFired30, duraFired10 = false, false, false
  elseif pct > 30 then
    duraFired30, duraFired10 = false, false
  elseif pct > 10 then
    duraFired10 = false
  end
end

local function CheckDurabilityAndNotify()
  local db = DB()
  if not db or not db.modules or not db.modules.durability then return end
  if not GetInventoryItemDurability then return end

  local pct = GetLowestDurabilityPercent()
  if not pct then return end

  ResetDurabilityFiresIfRepaired(pct)

  local last = duraLastPct
  duraLastPct = pct

  -- First run: don't spam immediately
  if not last then return end

  -- 10 first (most critical)
  if (not duraFired10) and last > 10 and pct <= 10 then
    duraFired10 = true
    local p = math.floor(pct + 0.5)
    Enqueue("DURA10", nil, "Armor at " .. p .. "%")
    return
  end

  -- then 30
  if (not duraFired30) and last > 30 and pct <= 30 then
    duraFired30 = true
    local p = math.floor(pct + 0.5)
    Enqueue("DURA30", nil, "Armor at " .. p .. "%")
    return
  end

  -- then 70
  if (not duraFired70) and last > 70 and pct <= 70 then
    duraFired70 = true
    local p = math.floor(pct + 0.5)
    Enqueue("DURA70", nil, "Armor at " .. p .. "%")
    return
  end
end

local function Durability_SetBaseline()
  duraLastPct = GetLowestDurabilityPercent()
end

HKDT.CheckDurabilityAndNotify = CheckDurabilityAndNotify
HKDT.Durability_SetBaseline  = Durability_SetBaseline

-- ---------------------------------------------------------
-- [07.6] Bags Almost Full / Bags Full (90% / 100%)
-- Robust: includes Reagent Bag and uses FREE SLOTS for "full"
-- ---------------------------------------------------------
local bagsLastFree = nil
local bagsLastTotal = nil
local bagsCanFire90 = false
local bagsCanFireFull = false

local function Bags_IterBagIndices()
  -- Backpack (0) + equipped bags (1-4)
  local list = { 0, 1, 2, 3, 4 }

  -- Reagent bag (Retail)
  local reagentIndex = nil
  if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
    reagentIndex = Enum.BagIndex.ReagentBag
  else
    -- fallback (usually 5)
    reagentIndex = 5
  end

  if C_Container and C_Container.GetContainerNumSlots then
    local rSlots = C_Container.GetContainerNumSlots(reagentIndex) or 0
    if rSlots and rSlots > 0 then
      table.insert(list, reagentIndex)
    end
  end

  return list
end

local function Bags_GetTotals()
  local totalSlots, freeSlots = 0, 0

  local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

  if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumFreeSlots then
    for _, bag in ipairs(Bags_IterBagIndices()) do
      if bag ~= REAGENT_BAG then
        local n = C_Container.GetContainerNumSlots(bag) or 0
        local f = C_Container.GetContainerNumFreeSlots(bag) or 0
        totalSlots = totalSlots + n
        freeSlots  = freeSlots + f
      end
    end

  elseif GetContainerNumSlots and GetContainerNumFreeSlots then
    -- Legacy fallback: excludes reagent bag (bags 0-4 only)
    for bag = 0, 4 do
      local n = GetContainerNumSlots(bag) or 0
      local f = GetContainerNumFreeSlots(bag) or 0
      totalSlots = totalSlots + n
      freeSlots  = freeSlots + f
    end

  else
    return nil
  end

  if totalSlots <= 0 then return nil end
  return totalSlots, freeSlots
end

local function Bags_GetUsedPercent()
  local totalSlots, freeSlots = Bags_GetTotals()
  if not totalSlots then return nil end
  local used = totalSlots - freeSlots
  local pct = (used / totalSlots) * 100
  return pct, totalSlots, freeSlots
end

local function Bags_SetBaseline()
  local pct, total, free = Bags_GetUsedPercent()
  bagsLastTotal = total
  bagsLastFree = free

  -- Rearm rules (same intention as yours, but based on free slots)
  -- 90% armed when you're comfortably below threshold (free > 15% total)
  if total and free then
    bagsCanFire90   = (free >= math.ceil(total * 0.15))
    -- Full armed when you have at least 2 free slots (so it won't spam while full)
    bagsCanFireFull = (free >= 2)
  else
    bagsCanFire90, bagsCanFireFull = false, false
  end
end

local function CheckBagsAndNotify()
  local db = DB()
  if not db or not db.modules or not db.modules.bags then return end

  local pct, total, free = Bags_GetUsedPercent()
  if not pct or not total or not free then return end

  local lastFree = bagsLastFree
  local lastTotal = bagsLastTotal

  bagsLastFree = free
  bagsLastTotal = total

  -- first run: don't toast instantly
  if lastFree == nil or lastTotal == nil then return end

  -- Rearm logic
  if free >= math.ceil(total * 0.15) then
    bagsCanFire90 = true
  end
  if free >= 2 then
    bagsCanFireFull = true
  end

  -- FULL: fire when free hits 0 (this is the real "full")
  if bagsCanFireFull and lastFree > 0 and free == 0 then
    bagsCanFireFull = false
    local compact = db.layout and db.layout.compact
    Enqueue("BAGFULL", nil, compact and "Inventory Full" or "Empty your bags — you are out of slots.")
    return
  end

  -- 90%: fire when you cross into <=10% free AND not full
  local thresholdFree = math.floor(total * 0.10 + 0.5) -- ~10% of slots
  if thresholdFree < 1 then thresholdFree = 1 end

  if bagsCanFire90 and lastFree > thresholdFree and free <= thresholdFree and free > 0 then
    bagsCanFire90 = false
    local compact = db.layout and db.layout.compact
    Enqueue("BAG90", nil, compact and "Inventory Almost Full" or "Your bags are almost full.")
    return
  end
end

HKDT.CheckBagsAndNotify = CheckBagsAndNotify
HKDT.Bags_SetBaseline   = Bags_SetBaseline

-- ---------------------------------------------------------
-- [07.7] Friends online/offline + suppression of Blizzard toast
-- ---------------------------------------------------------
local friendBaselineReady = false
local friendOnline = {} -- [name]=true/false

local function BuildFriendBaseline()
  if not C_FriendList or not C_FriendList.GetNumFriends or not C_FriendList.GetFriendInfoByIndex then
    friendBaselineReady = true
    return
  end

  wipe(friendOnline)

  local n = C_FriendList.GetNumFriends()
  for i = 1, n do
    local info = C_FriendList.GetFriendInfoByIndex(i)
    if info and info.name then
      friendOnline[info.name] = info.connected and true or false
    end
  end

  friendBaselineReady = true
end

local function OnFriendListUpdate()
  local db = DB()
  if not db or not db.modules or not db.modules.friends then return end
  if not C_FriendList or not C_FriendList.GetNumFriends or not C_FriendList.GetFriendInfoByIndex then return end

  if not friendBaselineReady then
    BuildFriendBaseline()
    return
  end

  local seen = {}
  local n = C_FriendList.GetNumFriends()

  for i = 1, n do
    local info = C_FriendList.GetFriendInfoByIndex(i)
    if info and info.name then
      local name = info.name
      local nowOn = info.connected and true or false
      local wasOn = friendOnline[name]

      seen[name] = true

      if wasOn ~= nil and wasOn ~= nowOn then
        if nowOn then
          Enqueue("FRIEND_ON",  name, "has come online.")
        else
          Enqueue("FRIEND_OFF", name, "has gone offline.")
        end
      end

      friendOnline[name] = nowOn
    end
  end

  for name, _ in pairs(friendOnline) do
    if not seen[name] then
      friendOnline[name] = nil
    end
  end
end

local function GetBNetWhoFromEventArgs(...)
  local bnetIDAccount = select(1, ...)
  local who = nil

  if type(bnetIDAccount) == "number" and C_BattleNet and C_BattleNet.GetAccountInfoByID then
    local info = C_BattleNet.GetAccountInfoByID(bnetIDAccount)
    if info then
      who =
        (info.battleTag and info.battleTag ~= "" and info.battleTag) or
        (info.accountName and info.accountName ~= "" and info.accountName) or
        (info.gameAccountInfo and info.gameAccountInfo.characterName and info.gameAccountInfo.characterName ~= "" and info.gameAccountInfo.characterName) or
        nil
    end
  end

  if not who then
    for i = 1, select("#", ...) do
      local v = select(i, ...)
      if type(v) == "string" and v ~= "" then
        if v:find("#") then
          who = v
          break
        end
        if not who then who = v end
      end
    end
  end

  return who or "Battle.net Friend"
end

local function OnBNFriendOnline(...)
  local db = DB()
  if not db or not db.modules or not db.modules.friends then return end
  local who = GetBNetWhoFromEventArgs(...)
  Enqueue("FRIEND_ON", who, "has come online.")
end

local function OnBNFriendOffline(...)
  local db = DB()
  if not db or not db.modules or not db.modules.friends then return end
  local who = GetBNetWhoFromEventArgs(...)
  Enqueue("FRIEND_OFF", who, "has gone offline.")
end

HKDT.OnFriendListUpdate = OnFriendListUpdate
HKDT.OnBNFriendOnline  = OnBNFriendOnline
HKDT.OnBNFriendOffline = OnBNFriendOffline

local function Friends_ResetCache()
  wipe(friendOnline)
  friendBaselineReady = false
end

HKDT.Friends_ResetCache = Friends_ResetCache

-- =========================================================
-- Friend toast suppression (reversible, robust)
-- =========================================================
local HKDT_Suppress = {
  enabled = false,

  wrappedGlobal = false,
  origGlobal = nil,

  wrappedFrames = {}, -- [frame]=true
  origMethods = {},   -- [frame]={ AddToast=fn, RegisterEvent=fn }
}

local function HKDT_IsFriendToastType(toastType, ...)
  if type(toastType) == "number" then
    if (_G.TOAST_TYPE_FRIEND_ONLINE and toastType == _G.TOAST_TYPE_FRIEND_ONLINE) or
       (_G.TOAST_TYPE_FRIEND_OFFLINE and toastType == _G.TOAST_TYPE_FRIEND_OFFLINE) or
       (_G.TOAST_TYPE_BN_FRIEND_ONLINE and toastType == _G.TOAST_TYPE_BN_FRIEND_ONLINE) or
       (_G.TOAST_TYPE_BN_FRIEND_OFFLINE and toastType == _G.TOAST_TYPE_BN_FRIEND_OFFLINE) or
       (_G.TOAST_TYPE_BNET_FRIEND_ONLINE and toastType == _G.TOAST_TYPE_BNET_FRIEND_ONLINE) or
       (_G.TOAST_TYPE_BNET_FRIEND_OFFLINE and toastType == _G.TOAST_TYPE_BNET_FRIEND_OFFLINE) then
      return true
    end
  end

  local s = tostring(toastType or ""):lower()
  if s ~= "" then
    if s:find("friend") and (s:find("online") or s:find("offline")) then
      return true
    end
    if s:find("bn") and s:find("friend") then
      return true
    end
  end

  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" then
      local t = v:lower()
      if t:find("has come online") or t:find("has gone offline") then
        return true
      end
    end
  end

  return false
end

local function HKDT_IsFriendEvent(evName)
  return (evName == "FRIENDLIST_UPDATE" or
          evName == "BN_FRIEND_ACCOUNT_ONLINE" or
          evName == "BN_FRIEND_ACCOUNT_OFFLINE")
end

local function HKDT_WrapFrame(frame)
  if not frame or HKDT_Suppress.wrappedFrames[frame] then return end

  HKDT_Suppress.wrappedFrames[frame] = true
  HKDT_Suppress.origMethods[frame] = HKDT_Suppress.origMethods[frame] or {}

  if type(frame.AddToast) == "function" and not HKDT_Suppress.origMethods[frame].AddToast then
    HKDT_Suppress.origMethods[frame].AddToast = frame.AddToast
    frame.AddToast = function(self, toastType, ...)
      if HKDT_Suppress.enabled and HKDT_IsFriendToastType(toastType, ...) then
        return
      end
      return HKDT_Suppress.origMethods[self].AddToast(self, toastType, ...)
    end
  end

  if type(frame.RegisterEvent) == "function" and not HKDT_Suppress.origMethods[frame].RegisterEvent then
    HKDT_Suppress.origMethods[frame].RegisterEvent = frame.RegisterEvent
    frame.RegisterEvent = function(self, evName, ...)
      if HKDT_Suppress.enabled and HKDT_IsFriendEvent(evName) then
        return
      end
      return HKDT_Suppress.origMethods[self].RegisterEvent(self, evName, ...)
    end
  end
end

local function HKDT_UnregisterFriendEventsOnFrame(frame)
  if not frame or not frame.UnregisterEvent then return end
  pcall(function() frame:UnregisterEvent("BN_FRIEND_ACCOUNT_ONLINE") end)
  pcall(function() frame:UnregisterEvent("BN_FRIEND_ACCOUNT_OFFLINE") end)
  pcall(function() frame:UnregisterEvent("FRIENDLIST_UPDATE") end)
end

local function ApplyFriendToastSuppression(enabled)
  HKDT_Suppress.enabled = enabled and true or false

  if not HKDT_Suppress.origGlobal and _G.ToastFrame_AddToast then
    HKDT_Suppress.origGlobal = _G.ToastFrame_AddToast
  end

  if HKDT_Suppress.enabled then
    if HKDT_Suppress.origGlobal and not HKDT_Suppress.wrappedGlobal then
      HKDT_Suppress.wrappedGlobal = true
      _G.ToastFrame_AddToast = function(toastType, ...)
        if HKDT_Suppress.enabled and HKDT_IsFriendToastType(toastType, ...) then
          return
        end
        return HKDT_Suppress.origGlobal(toastType, ...)
      end
    end
  else
    if HKDT_Suppress.wrappedGlobal and HKDT_Suppress.origGlobal then
      _G.ToastFrame_AddToast = HKDT_Suppress.origGlobal
    end
    HKDT_Suppress.wrappedGlobal = false
  end

  HKDT_WrapFrame(_G.ToastFrame)
  HKDT_WrapFrame(_G.SocialToastFrame)
  HKDT_WrapFrame(_G.BNToastFrame)

  if HKDT_Suppress.enabled then
    HKDT_UnregisterFriendEventsOnFrame(_G.ToastFrame)
    HKDT_UnregisterFriendEventsOnFrame(_G.SocialToastFrame)
    HKDT_UnregisterFriendEventsOnFrame(_G.BNToastFrame)
  end
end

HKDT.ApplyFriendToastSuppression = ApplyFriendToastSuppression

-- ---------------------------------------------------------
-- [07.8] Mythic+ Keystone (New Key / key changed)
-- ---------------------------------------------------------
local keyBaselineReady = false
local lastKeyMapID = nil
local lastKeyLevel = nil
local lastKeyToastAt = 0
local KEY_COALESCE = 0.40

local function GetOwnedKeyFromBags()
  if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemLink then
    return nil, nil
  end

  for bag = 0, 4 do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local link = C_Container.GetContainerItemLink(bag, slot)
      if link and link:find("Hkeystone:") then
        local payload = link:match("Hkeystone:([^|]+)")
        if payload then
          local parts = {}
          for v in payload:gmatch("([^:]+)") do
            parts[#parts + 1] = v
          end

          -- Common layout: [1]=itemID, [2]=mapID, [3]=level ...
          local mapID  = tonumber(parts[2])
          local level  = tonumber(parts[3])

          if not (mapID and level and level > 0) then
            -- fallback heuristic
            local nums = {}
            for i = 1, #parts do
              local n = tonumber(parts[i])
              if n then nums[#nums + 1] = n end
            end

            for i = 1, #nums - 1 do
              local a, b = nums[i], nums[i + 1]
              if a and b and b > 0 and b < 50 then
                mapID, level = a, b
                break
              end
            end
          end

          if mapID and level and level > 0 then
            return mapID, level
          end
        end
      end
    end
  end

  return nil, nil
end

local function GetOwnedKey()
  -- Best source: bag keystone link
  local mapID, level = GetOwnedKeyFromBags()
  if mapID and level and level > 0 then
    return mapID, level
  end

  -- Fallback: Mythic+ API
  if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneChallengeMapID then
    local lvl = C_MythicPlus.GetOwnedKeystoneLevel()
    local mid = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if lvl and lvl > 0 and mid then
      return mid, lvl
    end
  end

  return nil, nil
end

local function GetKeyLabel(mapID, level)
  local name = nil

  if mapID == "GENERIC" then
    name = "Mythic Keystone"
    return name, ""
  end

  if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local nm = C_ChallengeMode.GetMapUIInfo(mapID)
    if type(nm) == "string" then
      name = nm
    elseif type(nm) == "table" and nm.name then
      name = nm.name
    end
  end

  if not name and mapID and C_Map and C_Map.GetMapInfo then
    local mi = C_Map.GetMapInfo(mapID)
    if mi and mi.name then name = mi.name end
  end

  name = name or ("Dungeon " .. tostring(mapID))

  if level and level > 0 then
    return name, "+" .. tostring(level)
  end
  return name, ""
end

-- =========================================================
-- [07.8.X] Apply keystone hint (from chat/system/loot)
-- Uses parsed mapId/level directly to avoid timing issues
-- =========================================================
function HKDT.Keys_ApplyHint(mapId, level)
  local db = DB()
  if not db or not db.modules or not db.modules.keys then return end

  mapId = tonumber(mapId)
  level = tonumber(level)
  if not (mapId and level and level > 0) then return end

  if not keyBaselineReady then
    lastKeyMapID = mapId
    lastKeyLevel = level
    keyBaselineReady = true
    return
  end

  if mapId ~= lastKeyMapID or level ~= lastKeyLevel then
    lastKeyMapID = mapId
    lastKeyLevel = level
    FireKeyToast(mapId, level)
  end
end

local function FireKeyToast(mapID, level)
  local db = DB()
  if not db or not db.modules or not db.modules.keys then return end

  local now = GetTime()
  if (now - (lastKeyToastAt or 0)) < KEY_COALESCE then return end
  lastKeyToastAt = now

  local dungeonName, plusLevel = GetKeyLabel(mapID, level)

  local msg = dungeonName
  if plusLevel and plusLevel ~= "" then
    msg = msg .. " " .. plusLevel
  end

  if db.layout and db.layout.compact then
    Enqueue("KEY", "New Key:", msg)
  else
    Enqueue("KEY", "New Key", msg)
  end
end

local function Keys_SetBaseline()
  local mapID, level = GetOwnedKey()
  lastKeyMapID = mapID
  lastKeyLevel = level
  keyBaselineReady = true
end

local function CheckKeyAndNotify()
  local db = DB()
  if not db or not db.modules or not db.modules.keys then return end

  local mapID, level = GetOwnedKey()

  if not keyBaselineReady then
    lastKeyMapID = mapID
    lastKeyLevel = level
    keyBaselineReady = true
    return
  end

  if not mapID then
    lastKeyMapID = nil
    lastKeyLevel = nil
    return
  end

  if mapID ~= lastKeyMapID or level ~= lastKeyLevel then
    lastKeyMapID = mapID
    lastKeyLevel = level
    FireKeyToast(mapID, level)
  end
end

local function CheckKeyAndNotifyDelayed(delay)
  delay = tonumber(delay) or 0.15
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, function()
      CheckKeyAndNotify()
    end)
  else
    CheckKeyAndNotify()
  end
end

HKDT.Keys_SetBaseline    = Keys_SetBaseline
HKDT.CheckKeyAndNotify   = CheckKeyAndNotify
HKDT.CheckKeyAndNotifyDelayed = CheckKeyAndNotifyDelayed

-- ---------------------------------------------------------
-- [07.8.2] Keystone Watcher (polling) - the "it just works" fix
-- ---------------------------------------------------------
local keyWatchTicker = nil

local function Keys_StopWatcher()
  if keyWatchTicker and keyWatchTicker.Cancel then
    keyWatchTicker:Cancel()
  end
  keyWatchTicker = nil
end

local function Keys_StartWatcher()
  local db = DB()
  if not db or not db.modules or not db.modules.keys then
    Keys_StopWatcher()
    return
  end

  -- baseline once (no toast)
  Keys_SetBaseline()

  Keys_StopWatcher()
  if not C_Timer or not C_Timer.NewTicker then return end

  keyWatchTicker = C_Timer.NewTicker(0.85, function()
    local db2 = DB()
    if not db2 or not db2.modules or not db2.modules.keys then
      Keys_StopWatcher()
      return
    end
    CheckKeyAndNotify()
  end)
end

HKDT.Keys_StartWatcher = Keys_StartWatcher
HKDT.Keys_StopWatcher  = Keys_StopWatcher

-- ---------------------------------------------------------
-- Debug helpers (Key)
-- ---------------------------------------------------------
function HKDT.Debug_PrintOwnedKey()
  local mapID, level = GetOwnedKey()
  print("|cffEA4581HKDT|r OwnedKey:", tostring(mapID), tostring(level))
end

function HKDT.Debug_ForceKeyToast()
  local mapID, level = GetOwnedKey()
  if not mapID then
    print("|cffEA4581HKDT|r No keystone found in bags/API.")
    return
  end
  FireKeyToast(mapID, level)
end