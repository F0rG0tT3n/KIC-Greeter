local _, KIC = ...

local GREETING_DELAY_SECONDS = 1
local TIMED_GREETING_DELAY_SECONDS = 1
local CHAT_UNLOCK_RETRY_SECONDS = 0.5
local CHAT_UNLOCK_MAX_ATTEMPTS = 10
local DEFAULT_MAX_GROUP_SIZE = 5
local MAX_GROUP_SIZE = 40

local DB
local loggedIn = false
local greetedCurrentGroup = false
local groupGeneration = 0
local completionGeneration = 0

local function CopyDefaultMessages(defaults)
    local messages = {}

    for _, text in ipairs(defaults) do
        messages[#messages + 1] = {
            text = text,
            enabled = true,
        }
    end

    return messages
end

local function NormalizeMessages(messages)
    local normalized = {}

    for _, entry in ipairs(messages) do
        local text
        local enabled = true

        if type(entry) == "string" then
            text = entry
        elseif type(entry) == "table" then
            text = entry.text
            enabled = entry.enabled ~= false
        end

        if type(text) == "string" and text:find("%S") then
            normalized[#normalized + 1] = {
                text = text,
                enabled = enabled,
            }
        end
    end

    return normalized
end

local function InitializeDatabase()
    if type(KICLFGGreeterDB) ~= "table" then
        KICLFGGreeterDB = {}
    end

    DB = KICLFGGreeterDB

    if type(DB.greetings) ~= "table" then
        DB.greetings = CopyDefaultMessages(KIC.DEFAULT_GREETINGS)
    else
        DB.greetings = NormalizeMessages(DB.greetings)
    end

    if type(DB.timedGreetings) ~= "table" then
        DB.timedGreetings = CopyDefaultMessages(KIC.DEFAULT_TIMED_GREETINGS)
    else
        DB.timedGreetings = NormalizeMessages(DB.timedGreetings)
    end

    if type(DB.window) ~= "table" then
        DB.window = {}
    end

    DB.maxGroupSize = math.floor(
        tonumber(DB.maxGroupSize) or DEFAULT_MAX_GROUP_SIZE
    )
    DB.maxGroupSize = math.max(1, math.min(MAX_GROUP_SIZE, DB.maxGroupSize))
    DB.minimapAngle = tonumber(DB.minimapAngle) or 225
end

function KIC.GetDatabase()
    return DB
end

local function GetEnabledMessages(messages)
    local enabledMessages = {}

    for _, entry in ipairs(messages) do
        if entry.enabled and type(entry.text) == "string" then
            enabledMessages[#enabledMessages + 1] = entry.text
        end
    end

    return enabledMessages
end

local function IsChatMessagingLocked()
    return C_ChatInfo
        and C_ChatInfo.InChatMessagingLockdown
        and C_ChatInfo.InChatMessagingLockdown()
end

local function GetGroupChatType()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    end

    return "PARTY"
end

local function SendGroupChatMessage(message)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, GetGroupChatType())
    elseif SendChatMessage then
        -- Compatibility fallback for older Retail clients.
        SendChatMessage(message, GetGroupChatType())
    end
end

local function SendGreeting(expectedGeneration)
    if expectedGeneration ~= groupGeneration then
        return
    end

    if greetedCurrentGroup or not IsInGroup() then
        return
    end

    -- The group events alone are not sufficient to tell who initiated the
    -- party. Once the roster has settled, a leader is the player whose invite
    -- formed the group, so that case remains silent.
    greetedCurrentGroup = true

    local groupSize = GetNumGroupMembers()

    if UnitIsGroupLeader("player")
        or groupSize > DB.maxGroupSize
        or IsChatMessagingLocked()
    then
        return
    end

    local greetings = GetEnabledMessages(DB.greetings)

    if #greetings == 0 then
        return
    end

    local greeting = greetings[math.random(#greetings)]

    SendGroupChatMessage(greeting)
end

local function SendTimedGreeting(expectedGeneration, attempt)
    if expectedGeneration ~= completionGeneration then
        return
    end

    if IsChatMessagingLocked() then
        if attempt < CHAT_UNLOCK_MAX_ATTEMPTS and C_Timer and C_Timer.After then
            C_Timer.After(CHAT_UNLOCK_RETRY_SECONDS, function()
                SendTimedGreeting(expectedGeneration, attempt + 1)
            end)
        end

        return
    end

    if not IsInGroup() then
        return
    end

    local greetings = GetEnabledMessages(DB.timedGreetings)

    if #greetings == 0 then
        return
    end

    SendGroupChatMessage(greetings[math.random(#greetings)])
end

local function HandleChallengeModeCompleted()
    if not C_ChallengeMode
        or not C_ChallengeMode.GetChallengeCompletionInfo
    then
        return
    end

    local info = C_ChallengeMode.GetChallengeCompletionInfo()

    if not info or not info.onTime or info.practiceRun then
        return
    end

    completionGeneration = completionGeneration + 1
    local expectedGeneration = completionGeneration

    if C_Timer and C_Timer.After then
        C_Timer.After(TIMED_GREETING_DELAY_SECONDS, function()
            SendTimedGreeting(expectedGeneration, 0)
        end)
    else
        SendTimedGreeting(expectedGeneration, CHAT_UNLOCK_MAX_ATTEMPTS)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GROUP_FORMED")
events:RegisterEvent("GROUP_JOINED")
events:RegisterEvent("GROUP_LEFT")
events:RegisterEvent("CHALLENGE_MODE_COMPLETED")

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        InitializeDatabase()
        loggedIn = true
        greetedCurrentGroup = IsInGroup()

        if KIC.UI then
            KIC.UI.Initialize()
        end

        return
    end

    if not loggedIn then
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        HandleChallengeModeCompleted()
        return
    end

    groupGeneration = groupGeneration + 1
    completionGeneration = completionGeneration + 1

    if event == "GROUP_LEFT" then
        greetedCurrentGroup = false
        return
    end

    if greetedCurrentGroup then
        return
    end

    local expectedGeneration = groupGeneration

    if C_Timer and C_Timer.After then
        C_Timer.After(GREETING_DELAY_SECONDS, function()
            SendGreeting(expectedGeneration)
        end)
    else
        SendGreeting(expectedGeneration)
    end
end)
