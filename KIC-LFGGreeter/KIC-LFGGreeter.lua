local GREETING = "hi"
local GREETING_DELAY_SECONDS = 1

local events = CreateFrame("Frame")
local loggedIn = false
local greetedCurrentGroup = false
local groupGeneration = 0

local function IsChatMessagingLocked()
    return C_ChatInfo
        and C_ChatInfo.InChatMessagingLockdown
        and C_ChatInfo.InChatMessagingLockdown()
end

local function GetGroupChatType()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    return "PARTY"
end

local function SendGreeting(expectedGeneration)
    if expectedGeneration ~= groupGeneration then
        return
    end

    if greetedCurrentGroup or not IsInGroup() or IsInRaid() then
        return
    end

    -- The GROUP_FORMED and GROUP_JOINED events are not sufficient to tell who
    -- initiated the party. At this point the roster has settled: if the player
    -- is the leader, their invitation created the group, so stay silent.
    greetedCurrentGroup = true

    if UnitIsGroupLeader("player") then
        return
    end

    if IsChatMessagingLocked() then
        return
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(GREETING, GetGroupChatType())
    elseif SendChatMessage then
        -- Compatibility fallback for older Retail clients.
        SendChatMessage(GREETING, GetGroupChatType())
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GROUP_FORMED")
events:RegisterEvent("GROUP_JOINED")
events:RegisterEvent("GROUP_LEFT")

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        loggedIn = true
        greetedCurrentGroup = IsInGroup()
        return
    end

    if not loggedIn then
        return
    end

    groupGeneration = groupGeneration + 1

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
