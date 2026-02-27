-- HKDToasts_Events.lua
local ADDON_NAME = ...
local HKDT = _G.HKDT or {}
_G.HKDT = HKDT

-- =========================================================
-- Minimal keystone text detector (NO language/accents logic)
-- =========================================================
local function HKDT_IsKeystoneText(msg)
  if type(msg) ~= "string" then return false end

  -- universal internal link token
  if msg:find("Hkeystone:") then
    return true
  end

  -- keep it simple (no PT/ES/FR/etc token lists)
  local low = msg:lower()
  if low:find("keystone") then return true end

  return false
end

-- =========================================================
-- Detect keystone from loot line
-- =========================================================

-- =========================================================
-- RPG Loot Feed approach: detect keystone from loot line
-- =========================================================

-- Extract item/keystone links from chat message
local function HKDT_ExtractItemLinksFromChat(msg)
  if type(msg) ~= "string" then return nil end

  local links = {}

  -- match ANY item link regardless of color prefix
  for link in msg:gmatch("|Hitem:[^|]+|h%[[^%]]+%]|h") do
    links[#links + 1] = link
  end

  for link in msg:gmatch("|Hkeystone:[^|]+|h%[[^%]]+%]|h") do
    links[#links + 1] = link
  end

  if #links == 0 then return nil end
  return links
end

-- Parse keystone from either |Hkeystone:...| or |Hitem:180653...|
local function HKDT_ParseKeystoneFromLink(link)
  if type(link) ~= "string" then return nil end

  -- Case A: keystone link
  local ksPayload = link:match("|Hkeystone:([^|]+)|h")
  if ksPayload then
    local parts = {}
    for p in ksPayload:gmatch("([^:]+)") do parts[#parts + 1] = p end
    local itemId = tonumber(parts[1])
    local mapId  = tonumber(parts[2])
    local level  = tonumber(parts[3])
    if mapId and level and level > 0 then
      return itemId, mapId, level
    end
    return nil
  end

  -- Case B: item link (loot lines often show |Hitem:180653...|)
  local fieldsStr = link:match("|Hitem:([^|]+)|h")
  if not fieldsStr then return nil end

  local fields = {}
  for f in (fieldsStr .. ":"):gmatch("(.-):") do
    fields[#fields + 1] = f
  end

  local itemId = tonumber(fields[1])
  if not itemId then return nil end

  -- Ensure it's a keystone if API exists
  if C_Item and C_Item.IsItemKeystoneByID then
    if not C_Item.IsItemKeystoneByID(itemId) then
      return nil
    end
  end

  -- fields[14] = numModifiers
  local numModifiers = tonumber(fields[14]) or 0
  local mapId, level

  -- Each modifier is 2 fields (type/value) after numModifiers
  for i = 1, numModifiers do
    local v = tonumber(fields[14 + i * 2])
    if v then
      if i == 1 then mapId = v end
      if i == 2 then level = v end
    end
  end

  if mapId and level and level > 0 then
    return itemId, mapId, level
  end

  return nil
end

-- Public helper: try to extract a keystone hint from ANY chat message
-- SAFE behavior: hint is ONLY a trigger to re-check OWNED KEY, never a toast source.
HKDT.TryKeystoneHintFromMessage = function(msg, delay)
  if type(msg) ~= "string" then return false end
  if not HKDT.DB or not (HKDT.DB.modules and HKDT.DB.modules.keys) then return false end

  local links = HKDT_ExtractItemLinksFromChat(msg)
  if not links then return false end

  for i = 1, #links do
    local itemId, mapId, level = HKDT_ParseKeystoneFromLink(links[i])
    if mapId and level then
      -- debug-only breadcrumb (OK to be empty after /reload until you capture one again)
      HKDT._KEY_LOOT_HINT = {
        t = GetTime(),
        itemId = itemId,
        mapId = mapId,
        level = level,
        raw = links[i],
        msg = msg,
      }

      -- ✅ IMPORTANT: do NOT apply hint directly; just re-check your real owned key.
      if HKDT.CheckKeyAndNotifyDelayed then
        HKDT.CheckKeyAndNotifyDelayed(delay or 0.10)
      elseif HKDT.CheckKeyAndNotify then
        HKDT.CheckKeyAndNotify()
      end

      return true
    end
  end

  return false
end

-- =========================================================
-- >>> HKDT: SECTION [08] EVENT ROUTER (REGISTRATION + DISPATCH)
-- =========================================================
local ev = CreateFrame("Frame")

function HKDT.UpdateEventRegistrations()
  if not ev then return end
  ev:UnregisterAllEvents()

  local DB = HKDT.DB

  ev:RegisterEvent("ADDON_LOADED")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")

  ev:RegisterEvent("CHAT_MSG_WHISPER")
  ev:RegisterEvent("CHAT_MSG_BN_WHISPER")

  ev:RegisterEvent("UPDATE_PENDING_MAIL")
  ev:RegisterEvent("MAIL_INBOX_UPDATE")

  ev:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")

   if DB and DB.modules and (DB.modules.bags or DB.modules.keys) then
    ev:RegisterEvent("BAG_UPDATE")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
  end

  if DB and DB.modules and DB.modules.keys then
    ev:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    ev:RegisterEvent("CHAT_MSG_SYSTEM")
    ev:RegisterEvent("UI_INFO_MESSAGE")
    ev:RegisterEvent("UI_ERROR_MESSAGE")

    -- ✅ NEW: Loot is the most reliable keystone-change hint
    ev:RegisterEvent("CHAT_MSG_LOOT")
  end

  if DB and DB.modules and DB.modules.friends then
    ev:RegisterEvent("FRIENDLIST_UPDATE")
    ev:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    ev:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
  end

  if DB and DB.modules and DB.modules.vault then
    ev:RegisterEvent("WEEKLY_REWARDS_UPDATE")
  end
end

ev:SetScript("OnEvent", function(_, event, ...)
  -- -------------------------------------------------------
  -- ADDON_LOADED
  -- -------------------------------------------------------
  if event == "ADDON_LOADED" then
    local name = ...

    -- hook receptacle when Challenges UI loads
    if name == "Blizzard_ChallengesUI" then
      if HKDT and HKDT.HookKeystoneReceptacle then
        HKDT.HookKeystoneReceptacle()
      end
      -- don't return; other addons may load too
    end

    -- bootstrap HKDToasts
    if name ~= ADDON_NAME then return end

    HKDT.DB = _G.HKDToastsDB or HKDT.DB or {}
    _G.HKDToastsDB = HKDT.DB

    if HKDT.CopyDefaults and HKDT.DEFAULTS then
      HKDT.DB = HKDT.CopyDefaults(HKDT.DEFAULTS, HKDT.DB)
      _G.HKDToastsDB = HKDT.DB
    end

    if HKDT.Mail_ResetState then HKDT.Mail_ResetState() end
    if HKDT.StartLoginMailCheck then HKDT.StartLoginMailCheck() end

    HKDT.UpdateEventRegistrations()

    if HKDT.ScheduleDailyReset then HKDT.ScheduleDailyReset() end
    if HKDT.EnsureReminderTicker then HKDT.EnsureReminderTicker() end

    if HKDT.RegisterEmbeddedFonts then
      HKDT.RegisterEmbeddedFonts()
    end

    if HKDT.RefreshLockChip then HKDT.RefreshLockChip() end
    if HKDT.RefreshAnchor then HKDT.RefreshAnchor() end

    if HKDT.Durability_SetBaseline then HKDT.Durability_SetBaseline() end
    if HKDT.Bags_SetBaseline then HKDT.Bags_SetBaseline() end
    if HKDT.Keys_SetBaseline then HKDT.Keys_SetBaseline() end

	-- Start keystone watcher automatically (fixes "only procs after unrelated bag changes")
    if HKDT.DB and HKDT.DB.modules and HKDT.DB.modules.keys then
      if HKDT.Keys_StartWatcher then HKDT.Keys_StartWatcher() end
    else
      if HKDT.Keys_StopWatcher then HKDT.Keys_StopWatcher() end
    end

    if HKDT.DB and HKDT.DB.modules and HKDT.DB.modules.friends then
      if HKDT.ApplyFriendToastSuppression then HKDT.ApplyFriendToastSuppression(true) end
    else
      if HKDT.ApplyFriendToastSuppression then HKDT.ApplyFriendToastSuppression(false) end
    end

    return
  end

  local DB = HKDT.DB
  if not DB then return end

  -- -------------------------------------------------------
  -- Keystone hint triggers (safe: hint only, no direct toast)
  -- -------------------------------------------------------
  if DB.modules and DB.modules.keys then
    if event == "CHAT_MSG_LOOT" then
      local msg = ...
      if HKDT.TryKeystoneHintFromMessage then
        HKDT.TryKeystoneHintFromMessage(msg, 0.20)
      end
      return
    elseif event == "CHAT_MSG_SYSTEM" then
      local msg = ...
      if HKDT.TryKeystoneHintFromMessage then
        HKDT.TryKeystoneHintFromMessage(msg, 0.25)
      end
    elseif event == "UI_INFO_MESSAGE" or event == "UI_ERROR_MESSAGE" then
      local _, msg = ...
      if HKDT.TryKeystoneHintFromMessage then
        HKDT.TryKeystoneHintFromMessage(msg, 0.25)
      end
    end
  end

  -- -------------------------------------------------------
  -- Combat
  -- -------------------------------------------------------
  if event == "PLAYER_REGEN_DISABLED" then
    HKDT.IN_COMBAT = true
    if HKDT.CancelFlushTicker then HKDT.CancelFlushTicker() end
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    HKDT.IN_COMBAT = false
    if C_Timer and C_Timer.After and HKDT.FlushPostCombatQueue then
      C_Timer.After(0.25, HKDT.FlushPostCombatQueue)
    elseif HKDT.FlushPostCombatQueue then
      HKDT.FlushPostCombatQueue()
    end
    return
  end

  -- -------------------------------------------------------
  -- Whispers
  -- -------------------------------------------------------
  if event == "CHAT_MSG_WHISPER" then
    local msg, author = ...
    if HKDT.HandleWhisper then
      HKDT.HandleWhisper(author, msg)
    elseif HKDT.Enqueue then
      HKDT.Enqueue("WHISPER", author, msg)
    end
    return
  end

  if event == "CHAT_MSG_BN_WHISPER" then
    local msg, author = ...
    local bnetIDAccount = nil
    for i = 1, select("#", ...) do
      local v = select(i, ...)
      if type(v) == "number" then
        bnetIDAccount = v
        break
      end
    end

    if HKDT.HandleBNWhisper then
      HKDT.HandleBNWhisper(author, msg, bnetIDAccount)
    elseif HKDT.Enqueue then
      HKDT.Enqueue("BNET", author, msg, { bnetIDAccount = bnetIDAccount })
    end
    return
  end

  -- -------------------------------------------------------
  -- Login/world
  -- -------------------------------------------------------
  if event == "PLAYER_LOGIN" then
    if HKDT.ApplyFriendToastSuppression then
      HKDT.ApplyFriendToastSuppression(DB.modules and DB.modules.friends)
    end
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    if HKDT.StartLoginMailCheck and not (HKDT.Mail_IsLoginChecked and HKDT.Mail_IsLoginChecked()) then
      HKDT.StartLoginMailCheck()
    end

    if HKDT.ApplyFriendToastSuppression then
      HKDT.ApplyFriendToastSuppression(DB.modules and DB.modules.friends)
    end

    if HKDT.Vault_StartRetry then
      HKDT.Vault_StartRetry()
    end

    if HKDT.Durability_SetBaseline then HKDT.Durability_SetBaseline() end
    if HKDT.Bags_SetBaseline then HKDT.Bags_SetBaseline() end
    if HKDT.Keys_SetBaseline then HKDT.Keys_SetBaseline() end

    return
  end

  -- -------------------------------------------------------
  -- Friends
  -- -------------------------------------------------------
  if event == "FRIENDLIST_UPDATE" then
    if HKDT.OnFriendListUpdate then HKDT.OnFriendListUpdate() end
    return
  end

  if event == "BN_FRIEND_ACCOUNT_ONLINE" then
    if HKDT.OnBNFriendOnline then HKDT.OnBNFriendOnline(...) end
    return
  end

  if event == "BN_FRIEND_ACCOUNT_OFFLINE" then
    if HKDT.OnBNFriendOffline then HKDT.OnBNFriendOffline(...) end
    return
  end

  -- -------------------------------------------------------
  -- Mail
  -- -------------------------------------------------------
  if event == "UPDATE_PENDING_MAIL" then
    if HKDT.OnPendingMailEvent then HKDT.OnPendingMailEvent() end
    return
  end

  if event == "MAIL_INBOX_UPDATE" then
    if HKDT.OnMailboxInboxUpdate then HKDT.OnMailboxInboxUpdate() end
    return
  end

  -- -------------------------------------------------------
  -- Vault
  -- -------------------------------------------------------
  if event == "WEEKLY_REWARDS_UPDATE" then
    if HKDT.CheckVaultAndNotify then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
          HKDT.CheckVaultAndNotify(false)
        end)
      else
        HKDT.CheckVaultAndNotify(false)
      end
    end
    return
  end

  -- -------------------------------------------------------
  -- Durability
  -- -------------------------------------------------------
  if event == "UPDATE_INVENTORY_DURABILITY" then
    if HKDT.CheckDurabilityAndNotify then HKDT.CheckDurabilityAndNotify() end
    return
  end

  -- -------------------------------------------------------
  -- Bags + Key poll
  -- -------------------------------------------------------

    if event == "BAG_UPDATE" then
    if DB.modules and DB.modules.keys then
      if HKDT.CheckKeyAndNotifyDelayed then
        HKDT.CheckKeyAndNotifyDelayed(0.10)
      elseif HKDT.CheckKeyAndNotify then
        HKDT.CheckKeyAndNotify()
      end
    end
    return
  end

  if event == "BAG_UPDATE_DELAYED" then
    if HKDT.CheckBagsAndNotify then HKDT.CheckBagsAndNotify() end

    if HKDT.CheckKeyAndNotifyDelayed then
      HKDT.CheckKeyAndNotifyDelayed(0.25)
    elseif HKDT.CheckKeyAndNotify then
      HKDT.CheckKeyAndNotify()
    end
    return
  end

  -- -------------------------------------------------------
  -- Dungeon completion
  -- -------------------------------------------------------
  if event == "CHALLENGE_MODE_COMPLETED" then
    if HKDT.CheckKeyAndNotifyDelayed then
      HKDT.CheckKeyAndNotifyDelayed(0.35)
    elseif HKDT.CheckKeyAndNotify then
      HKDT.CheckKeyAndNotify()
    end
    return
  end
end)

ev:RegisterEvent("ADDON_LOADED")
-- <<< HKDT: SECTION [08]