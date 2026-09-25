local _, KIC = ...

local DEFAULT_MESSAGE_DELAY_SECONDS = 1
local MAX_MESSAGE_DELAY_SECONDS = 60
local RESTORED_GROUP_CHECK_SECONDS = 10
local CHAT_UNLOCK_RETRY_SECONDS = 0.5
local CHAT_UNLOCK_MAX_ATTEMPTS = 10
local DEFAULT_MAX_GROUP_SIZE = 4
local MAX_GROUP_SIZE = 40

local DB
local loggedIn = false
local greetedCurrentGroup = false
local restoredGroupMembers
local groupGeneration = 0
local outcomeGenerations = {
    timedGreetings = 0,
    overtimeGreetings = 0,
    abandonGreetings = 0,
}

local function CopyDefaultMessages(defaults)
    local messages = {}

    for _, default in ipairs(defaults) do
        local text = default
        local enabled = true

        if type(default) == "table" then
            text = default.text
            enabled = default.enabled ~= false
        end

        messages[#messages + 1] = {
            text = text,
            enabled = enabled,
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

    if type(DB.overtimeGreetings) ~= "table" then
        DB.overtimeGreetings = CopyDefaultMessages(
            KIC.DEFAULT_OVERTIME_GREETINGS
        )
    else
        DB.overtimeGreetings = NormalizeMessages(DB.overtimeGreetings)
    end

    if type(DB.abandonGreetings) ~= "table" then
        DB.abandonGreetings = CopyDefaultMessages(KIC.DEFAULT_ABANDON_GREETINGS)
    else
        DB.abandonGreetings = NormalizeMessages(DB.abandonGreetings)
    end

    if type(DB.window) ~= "table" then
        DB.window = {}
    end

    DB.maxGroupSize = math.floor(
        tonumber(DB.maxGroupSize) or DEFAULT_MAX_GROUP_SIZE
    )
    DB.maxGroupSize = math.max(1, math.min(MAX_GROUP_SIZE, DB.maxGroupSize))
    DB.messageDelaySeconds = math.floor(
        tonumber(DB.messageDelaySeconds) or DEFAULT_MESSAGE_DELAY_SECONDS
    )
    DB.messageDelaySeconds = math.max(
        0,
        math.min(MAX_MESSAGE_DELAY_SECONDS, DB.messageDelaySeconds)
    )
    DB.minimapAngle = tonumber(DB.minimapAngle) or 225
end

function KIC.GetDatabase()
    return DB
end

local function GetOtherGroupMemberGUIDs()
    local guids = {}

    if not IsInGroup() then
        return guids
    end

    local playerGUID = UnitGUID("player")
    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid()
        and GetNumGroupMembers()
        or math.max(0, GetNumGroupMembers() - 1)

    for index = 1, count do
        local guid = UnitGUID(prefix .. index)

        if guid and guid ~= playerGUID then
            guids[#guids + 1] = guid
        end
    end

    return guids
end

local function ClearRestoredGroupSnapshot()
    restoredGroupMembers = nil

    if DB then
        DB.logoutPlayerGUID = nil
        DB.logoutGroupMembers = nil
    end
end

local function CaptureLogoutGroupSnapshot()
    if not DB or not IsInGroup() then
        ClearRestoredGroupSnapshot()
        return
    end

    local members = {}

    for _, guid in ipairs(GetOtherGroupMemberGUIDs()) do
        members[guid] = true
    end

    if not next(members) then
        ClearRestoredGroupSnapshot()
        return
    end

    DB.logoutPlayerGUID = UnitGUID("player")
    DB.logoutGroupMembers = members
end

local function RestoredGroupMatchesCurrentGroup()
    if not restoredGroupMembers or not IsInGroup() then
        return false
    end

    for _, guid in ipairs(GetOtherGroupMemberGUIDs()) do
        if restoredGroupMembers[guid] then
            return true
        end
    end

    return false
end

local function MarkRestoredGroupAsGreeted()
    if not RestoredGroupMatchesCurrentGroup() then
        return false
    end

    greetedCurrentGroup = true
    ClearRestoredGroupSnapshot()
    return true
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

    if MarkRestoredGroupAsGreeted() then
        return
    end

    ClearRestoredGroupSnapshot()

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

local function SendOutcomeGreeting(listKey, expectedGeneration, attempt)
    if expectedGeneration ~= outcomeGenerations[listKey] then
        return
    end

    if IsChatMessagingLocked() then
        if attempt < CHAT_UNLOCK_MAX_ATTEMPTS and C_Timer and C_Timer.After then
            C_Timer.After(CHAT_UNLOCK_RETRY_SECONDS, function()
                SendOutcomeGreeting(listKey, expectedGeneration, attempt + 1)
            end)
        end

        return
    end

    if not IsInGroup() then
        return
    end

    local greetings = GetEnabledMessages(DB[listKey])

    if #greetings == 0 then
        return
    end

    SendGroupChatMessage(greetings[math.random(#greetings)])
end

local function QueueOutcomeGreeting(listKey)
    outcomeGenerations[listKey] = outcomeGenerations[listKey] + 1
    local expectedGeneration = outcomeGenerations[listKey]

    if C_Timer and C_Timer.After then
        C_Timer.After(DB.messageDelaySeconds, function()
            SendOutcomeGreeting(listKey, expectedGeneration, 0)
        end)
    else
        SendOutcomeGreeting(
            listKey,
            expectedGeneration,
            CHAT_UNLOCK_MAX_ATTEMPTS
        )
    end
end

local function HandleChallengeModeCompleted()
    if not C_ChallengeMode
        or not C_ChallengeMode.GetChallengeCompletionInfo
    then
        return
    end

    local info = C_ChallengeMode.GetChallengeCompletionInfo()

    if not info or info.practiceRun then
        return
    end

    QueueOutcomeGreeting(
        info.onTime and "timedGreetings" or "overtimeGreetings"
    )
end

local function HandleInstanceAbandonVoteFinished(votePassed)
    if votePassed then
        QueueOutcomeGreeting("abandonGreetings")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("GROUP_FORMED")
events:RegisterEvent("GROUP_JOINED")
events:RegisterEvent("GROUP_LEFT")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
events:RegisterEvent("INSTANCE_ABANDON_VOTE_FINISHED")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitializeDatabase()
        loggedIn = true
        greetedCurrentGroup = IsInGroup()

        if DB.logoutPlayerGUID == UnitGUID("player")
            and type(DB.logoutGroupMembers) == "table"
        then
            restoredGroupMembers = DB.logoutGroupMembers
        else
            ClearRestoredGroupSnapshot()
        end

        if greetedCurrentGroup then
            ClearRestoredGroupSnapshot()
        elseif restoredGroupMembers and C_Timer and C_Timer.After then
            C_Timer.After(RESTORED_GROUP_CHECK_SECONDS, function()
                if not MarkRestoredGroupAsGreeted() then
                    ClearRestoredGroupSnapshot()
                end
            end)
        end

        if KIC.UI then
            KIC.UI.Initialize()
        end

        return
    end

    if not loggedIn then
        return
    end

    if event == "PLAYER_LOGOUT" then
        CaptureLogoutGroupSnapshot()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        MarkRestoredGroupAsGreeted()
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        HandleChallengeModeCompleted()
        return
    end

    if event == "INSTANCE_ABANDON_VOTE_FINISHED" then
        HandleInstanceAbandonVoteFinished(...)
        return
    end

    groupGeneration = groupGeneration + 1

    for listKey, generation in pairs(outcomeGenerations) do
        outcomeGenerations[listKey] = generation + 1
    end

    if event == "GROUP_LEFT" then
        greetedCurrentGroup = false
        ClearRestoredGroupSnapshot()
        return
    end

    if greetedCurrentGroup then
        return
    end

    if MarkRestoredGroupAsGreeted() then
        return
    end

    local expectedGeneration = groupGeneration

    if C_Timer and C_Timer.After then
        C_Timer.After(DB.messageDelaySeconds, function()
            SendGreeting(expectedGeneration)
        end)
    else
        SendGreeting(expectedGeneration)
    end
end)
