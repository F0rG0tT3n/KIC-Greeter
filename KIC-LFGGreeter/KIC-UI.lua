local _, KIC = ...

local UI = {}
KIC.UI = UI

local WINDOW_WIDTH = 700
local WINDOW_HEIGHT = 620
local LIST_WIDTH = 642
local ROW_HEIGHT = 30
local ROW_GAP = 2
local DEFAULT_MAX_GROUP_SIZE = 4
local MAX_GROUP_SIZE = 40
local DEFAULT_MESSAGE_DELAY_SECONDS = 1
local MAX_MESSAGE_DELAY_SECONDS = 60
local TAB_JOIN = "JOIN"
local TAB_TIMED = "TIMED"
local TAB_ABANDON = "ABANDON"
local TAB_OVERTIME = "OVERTIME"

local TAB_CONFIG = {
    [TAB_JOIN] = {
        listKey = "greetings",
        addLabel = "New join greeting",
        statusLabel = "Enabled join greetings",
    },
    [TAB_TIMED] = {
        listKey = "timedGreetings",
        addLabel = "New timed completion message",
        statusLabel = "Enabled timed messages",
        helpText = "Sent only when a Mythic+ keystone dungeon is completed within its time limit.",
    },
    [TAB_OVERTIME] = {
        listKey = "overtimeGreetings",
        addLabel = "New overtime completion message",
        statusLabel = "Enabled overtime messages",
        helpText = "Sent only when a Mythic+ keystone dungeon is completed after its timer expires.",
    },
    [TAB_ABANDON] = {
        listKey = "abandonGreetings",
        addLabel = "New successful abandon message",
        statusLabel = "Enabled abandon messages",
        helpText = "Sent only after a Mythic+ Vote to Abandon succeeds.",
    },
}

local initialized = false
local activeTab = TAB_JOIN
local optionsFrame
local minimapButton
local scrollFrame
local scrollChild
local statusText
local addInput
local addLabel
local maxGroupInput
local maxGroupLabel
local maxGroupHelp
local messageDelayInput
local outcomeHelp
local tabButtons = {}
local rows = {}
local editingRow

local function Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Notify(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100KIC Greeter:|r " .. message)
    end
end

local function GetDatabase()
    return KIC.GetDatabase and KIC.GetDatabase()
end

local function GetActiveList()
    local db = GetDatabase()
    local config = TAB_CONFIG[activeTab]

    return db and db[config.listKey], config
end

local function UpdateRowEnabledAppearance(row, enabled)
    if enabled then
        row.DisabledOverlay:Hide()
        row.Number:SetTextColor(1, 0.82, 0, 1)
        row.Text:SetTextColor(1, 1, 1, 1)
    else
        row.DisabledOverlay:Show()
        row.Number:SetTextColor(0.52, 0.52, 0.52, 1)
        row.Text:SetTextColor(0.58, 0.58, 0.58, 1)
    end
end

local function StopEditingRow(row, save)
    if not row or not row.Editing then
        return true
    end

    if save then
        local text = Trim(row.EditBox:GetText())

        if text == "" then
            Notify("A message cannot be empty.")
            return false
        end

        local db = GetDatabase()
        local entries = db and db[row.ListKey]
        local entry = entries and entries[row.EntryIndex]

        if entry then
            entry.text = text
            row.Text:SetText(text)
        end
    end

    row.Editing = false
    row.EditBox:Hide()
    row.Text:Show()
    row.Edit:SetText("Edit")

    if editingRow == row then
        editingRow = nil
    end

    return true
end

local function UpdateStatus()
    if not statusText then
        return
    end

    local entries, config = GetActiveList()
    local enabled = 0

    for _, entry in ipairs(entries) do
        if entry.enabled then
            enabled = enabled + 1
        end
    end

    statusText:SetText(string.format(
        "%s: %d / %d",
        config.statusLabel,
        enabled,
        #entries
    ))
end

local function CreateGreetingRow(index)
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    row.Background = background

    local disabledOverlay = row:CreateTexture(nil, "ARTWORK")
    disabledOverlay:SetAllPoints()
    disabledOverlay:SetColorTexture(0.34, 0.34, 0.34, 0.38)
    disabledOverlay:Hide()
    row.DisabledOverlay = disabledOverlay

    local number = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    number:SetPoint("LEFT", row, "LEFT", 8, 0)
    number:SetWidth(30)
    number:SetJustifyH("RIGHT")
    row.Number = number

    local toggle = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    toggle:SetSize(24, 24)
    toggle:SetPoint("RIGHT", row, "RIGHT", -7, 0)
    row.Toggle = toggle

    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(68, 22)
    remove:SetPoint("RIGHT", toggle, "LEFT", -7, 0)
    remove:SetText("Remove")
    row.Remove = remove

    local edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    edit:SetSize(52, 22)
    edit:SetPoint("RIGHT", remove, "LEFT", -6, 0)
    edit:SetText("Edit")
    row.Edit = edit

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", number, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.Text = text

    local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    editBox:SetHeight(22)
    editBox:SetPoint("LEFT", number, "RIGHT", 12, 0)
    editBox:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(220)
    editBox:Hide()
    row.EditBox = editBox

    toggle:SetScript("OnClick", function(self)
        local db = GetDatabase()
        local entries = db and db[row.ListKey]
        local entry = entries and entries[row.EntryIndex]

        if entry then
            local enabled = self:GetChecked() and true or false
            entry.enabled = enabled
            UpdateRowEnabledAppearance(row, enabled)
            UpdateStatus()
        end
    end)

    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Use this message")
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", GameTooltip_Hide)

    edit:SetScript("OnClick", function()
        if row.Editing then
            if StopEditingRow(row, true) then
                UI.Refresh()
            end
            return
        end

        if editingRow and editingRow ~= row then
            StopEditingRow(editingRow, false)
        end

        row.Editing = true
        editingRow = row
        row.EditBox:SetText(row.Text:GetText() or "")
        row.Text:Hide()
        row.EditBox:Show()
        row.Edit:SetText("Save")
        row.EditBox:SetFocus()
        row.EditBox:HighlightText()
    end)

    editBox:SetScript("OnEnterPressed", function()
        edit:Click()
    end)
    editBox:SetScript("OnEscapePressed", function()
        StopEditingRow(row, false)
    end)

    remove:SetScript("OnClick", function(self)
        local db = GetDatabase()
        local entries = db and db[row.ListKey]

        if entries and entries[row.EntryIndex] then
            table.remove(entries, row.EntryIndex)
            UI.Refresh()
        end
    end)

    rows[index] = row
    return row
end

function UI.Refresh()
    if not optionsFrame or not scrollChild then
        return
    end

    local db = GetDatabase()
    local entries, config = GetActiveList()

    if messageDelayInput then
        messageDelayInput:SetText(tostring(db.messageDelaySeconds))
    end

    for _, row in ipairs(rows) do
        StopEditingRow(row, false)
        row:Hide()
    end

    for index, entry in ipairs(entries) do
        local row = rows[index] or CreateGreetingRow(index)
        local y = -((index - 1) * (ROW_HEIGHT + ROW_GAP))
        local shade = index % 2 == 0 and 0.11 or 0.07

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
        row.Background:SetColorTexture(shade, shade, shade, 0.92)
        row.Number:SetText(index .. ".")
        row.Text:SetText(entry.text)
        row.EntryIndex = index
        row.ListKey = config.listKey
        row.Toggle.EntryIndex = index
        row.Toggle:SetChecked(entry.enabled)
        row.Remove.EntryIndex = index
        UpdateRowEnabledAppearance(row, entry.enabled)
        row:Show()
    end

    local contentHeight = #entries * (ROW_HEIGHT + ROW_GAP)
    scrollChild:SetHeight(math.max(1, contentHeight))

    if activeTab == TAB_JOIN then
        maxGroupLabel:Show()
        maxGroupInput:Show()
        maxGroupHelp:Show()
        outcomeHelp:Hide()
        maxGroupInput:SetText(tostring(db.maxGroupSize))
    else
        maxGroupLabel:Hide()
        maxGroupInput:Hide()
        maxGroupHelp:Hide()
        outcomeHelp:SetText(config.helpText)
        outcomeHelp:Show()
    end

    for tabKey, button in pairs(tabButtons) do
        local isActive = tabKey == activeTab
        local label = button:GetFontString()

        button:Enable()
        button:SetButtonState(isActive and "PUSHED" or "NORMAL", isActive)
        button.ActiveIndicator:SetShown(isActive)

        if label then
            if isActive then
                label:SetTextColor(1, 0.82, 0, 1)
            else
                label:SetTextColor(0.82, 0.82, 0.82, 1)
            end
        end
    end

    addLabel:SetText(config.addLabel)
    UpdateStatus()
end

local function CommitMaxGroupSize()
    if not maxGroupInput then
        return
    end

    local db = GetDatabase()
    local value = tonumber(maxGroupInput:GetText())

    if not value then
        maxGroupInput:SetText(tostring(
            db.maxGroupSize or DEFAULT_MAX_GROUP_SIZE
        ))
        return
    end

    value = math.floor(value)
    value = math.max(1, math.min(MAX_GROUP_SIZE, value))
    db.maxGroupSize = value
    maxGroupInput:SetText(tostring(value))
end

local function CommitMessageDelay()
    if not messageDelayInput then
        return
    end

    local db = GetDatabase()
    local value = tonumber(messageDelayInput:GetText())

    if not value then
        messageDelayInput:SetText(tostring(
            db.messageDelaySeconds or DEFAULT_MESSAGE_DELAY_SECONDS
        ))
        return
    end

    value = math.floor(value)
    value = math.max(0, math.min(MAX_MESSAGE_DELAY_SECONDS, value))
    db.messageDelaySeconds = value
    messageDelayInput:SetText(tostring(value))
end

local function AddGreeting()
    local text = Trim(addInput and addInput:GetText())

    if text == "" then
        Notify("Enter a message before adding it.")
        return
    end

    local entries = GetActiveList()
    entries[#entries + 1] = {
        text = text,
        enabled = true,
    }

    addInput:SetText("")
    addInput:ClearFocus()
    UI.Refresh()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if scrollFrame then
                scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
            end
        end)
    end
end

local function SelectTab(tabKey)
    if not TAB_CONFIG[tabKey] or tabKey == activeTab then
        return
    end

    if activeTab == TAB_JOIN then
        CommitMaxGroupSize()
    end

    if editingRow then
        StopEditingRow(editingRow, false)
    end

    activeTab = tabKey
    addInput:SetText("")
    addInput:ClearFocus()

    if scrollFrame then
        scrollFrame:SetVerticalScroll(0)
    end

    UI.Refresh()
end

local function SaveWindowPosition()
    if not optionsFrame then
        return
    end

    local db = GetDatabase()
    local point, _, relativePoint, x, y = optionsFrame:GetPoint(1)

    db.window.point = point
    db.window.relativePoint = relativePoint
    db.window.x = x
    db.window.y = y
end

local function RestoreWindowPosition()
    local db = GetDatabase()
    local window = db.window

    optionsFrame:ClearAllPoints()

    if type(window.point) == "string"
        and type(window.x) == "number"
        and type(window.y) == "number"
    then
        optionsFrame:SetPoint(
            window.point,
            UIParent,
            window.relativePoint or window.point,
            window.x,
            window.y
        )
    else
        optionsFrame:SetPoint("CENTER")
    end
end

local function AddTabSelectionIndicator(button)
    local indicator = button:CreateTexture(nil, "OVERLAY")
    indicator:SetColorTexture(1, 0.82, 0, 1)
    indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, 2)
    indicator:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 2)
    indicator:SetHeight(3)
    indicator:Hide()
    button.ActiveIndicator = indicator
end

local function CreateOptionsFrame()
    if optionsFrame then
        return
    end

    local frame = CreateFrame(
        "Frame",
        "KICLFGGreeterOptionsFrame",
        UIParent,
        "BackdropTemplate"
    )
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.03, 0.98)
    frame:SetBackdropBorderColor(0.72, 0.58, 0.10, 1)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)
    frame:SetScript("OnShow", function(self)
        self:Raise()
        UI.Refresh()
    end)
    frame:Hide()
    optionsFrame = frame

    RestoreWindowPosition()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -15)
    title:SetText("KIC Greeter")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Configure automatic group chat messages.")
    subtitle:SetTextColor(0.72, 0.72, 0.72)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    messageDelayInput = CreateFrame(
        "EditBox",
        nil,
        frame,
        "InputBoxTemplate"
    )
    messageDelayInput:SetSize(44, 22)
    messageDelayInput:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -45, -14)
    messageDelayInput:SetAutoFocus(false)
    messageDelayInput:SetNumeric(true)
    messageDelayInput:SetMaxLetters(2)
    messageDelayInput:SetText(tostring(GetDatabase().messageDelaySeconds))
    messageDelayInput:SetScript("OnEnterPressed", function(self)
        CommitMessageDelay()
        self:ClearFocus()
    end)
    messageDelayInput:SetScript("OnEditFocusLost", CommitMessageDelay)

    local messageDelayLabel = frame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    messageDelayLabel:SetPoint(
        "RIGHT",
        messageDelayInput,
        "LEFT",
        -8,
        0
    )
    messageDelayLabel:SetText("Message delay (sec):")

    local joinTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    joinTab:SetSize(132, 24)
    joinTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -61)
    joinTab:SetText("Join Greetings")
    AddTabSelectionIndicator(joinTab)
    joinTab:SetScript("OnClick", function()
        SelectTab(TAB_JOIN)
    end)
    tabButtons[TAB_JOIN] = joinTab

    local timedTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    timedTab:SetSize(142, 24)
    timedTab:SetPoint("LEFT", joinTab, "RIGHT", 6, 0)
    timedTab:SetText("Timed Mythic+")
    AddTabSelectionIndicator(timedTab)
    timedTab:SetScript("OnClick", function()
        SelectTab(TAB_TIMED)
    end)
    tabButtons[TAB_TIMED] = timedTab

    local abandonTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    abandonTab:SetSize(162, 24)
    abandonTab:SetPoint("LEFT", timedTab, "RIGHT", 6, 0)
    abandonTab:SetText("Abandoned Mythic+")
    AddTabSelectionIndicator(abandonTab)
    abandonTab:SetScript("OnClick", function()
        SelectTab(TAB_ABANDON)
    end)
    tabButtons[TAB_ABANDON] = abandonTab

    local overtimeTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    overtimeTab:SetSize(162, 24)
    overtimeTab:SetPoint("LEFT", abandonTab, "RIGHT", 6, 0)
    overtimeTab:SetText("Overtime Mythic+")
    AddTabSelectionIndicator(overtimeTab)
    overtimeTab:SetScript("OnClick", function()
        SelectTab(TAB_OVERTIME)
    end)
    tabButtons[TAB_OVERTIME] = overtimeTab

    maxGroupLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxGroupLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -103)
    maxGroupLabel:SetText("Maximum group size:")

    maxGroupInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    maxGroupInput:SetSize(44, 22)
    maxGroupInput:SetPoint("LEFT", maxGroupLabel, "RIGHT", 10, 0)
    maxGroupInput:SetAutoFocus(false)
    maxGroupInput:SetNumeric(true)
    maxGroupInput:SetMaxLetters(2)
    maxGroupInput:SetText(tostring(GetDatabase().maxGroupSize))
    maxGroupInput:SetScript("OnEnterPressed", function(self)
        CommitMaxGroupSize()
        self:ClearFocus()
    end)
    maxGroupInput:SetScript("OnEditFocusLost", CommitMaxGroupSize)

    maxGroupHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maxGroupHelp:SetPoint("LEFT", maxGroupInput, "RIGHT", 10, 0)
    maxGroupHelp:SetText("Greet only when the total member count is at or below this value.")
    maxGroupHelp:SetTextColor(0.72, 0.72, 0.72)

    outcomeHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    outcomeHelp:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -105)
    outcomeHelp:SetTextColor(0.72, 0.72, 0.72)
    outcomeHelp:Hide()

    local header = CreateFrame("Frame", nil, frame)
    header:SetSize(LIST_WIDTH, 22)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -137)

    local numberHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numberHeader:SetPoint("LEFT", header, "LEFT", 8, 0)
    numberHeader:SetWidth(30)
    numberHeader:SetJustifyH("RIGHT")
    numberHeader:SetText("#")

    local textHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textHeader:SetPoint("LEFT", numberHeader, "RIGHT", 8, 0)
    textHeader:SetText("Message")

    local editHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editHeader:SetPoint("RIGHT", header, "RIGHT", -121, 0)
    editHeader:SetText("Edit")

    local removeHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    removeHeader:SetPoint("RIGHT", header, "RIGHT", -43, 0)
    removeHeader:SetText("Remove")

    local useHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    useHeader:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    useHeader:SetText("Use")

    scrollFrame = CreateFrame(
        "ScrollFrame",
        "KICLFGGreeterGreetingScrollFrame",
        frame,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 112)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(LIST_WIDTH, 1)
    scrollFrame:SetScrollChild(scrollChild)

    addLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 78)
    addLabel:SetText("New join greeting")

    addInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    addInput:SetSize(550, 24)
    addInput:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 47)
    addInput:SetAutoFocus(false)
    addInput:SetMaxLetters(220)
    addInput:SetScript("OnEnterPressed", AddGreeting)
    addInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addButton:SetSize(92, 24)
    addButton:SetPoint("LEFT", addInput, "RIGHT", 8, 0)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", AddGreeting)

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 20)
    statusText:SetTextColor(0.72, 0.72, 0.72)

    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
end

function UI.Toggle()
    CreateOptionsFrame()

    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local function PositionMinimapButton()
    if not minimapButton or not Minimap then
        return
    end

    local db = GetDatabase()
    local radians = math.rad(db.minimapAngle)
    local radius = 80

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(radians) * radius,
        math.sin(radians) * radius
    )
end

local function UpdateMinimapButtonFromCursor()
    local minimapX, minimapY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    GetDatabase().minimapAngle = math.deg(Atan2(
        cursorY - minimapY,
        cursorX - minimapX
    ))

    PositionMinimapButton()
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "KICLFGGreeterMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0.06, 0.06, 0.06, 1)
    button.icon = background

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", background, "CENTER")
    label:SetText("G")
    label:SetTextColor(1, 0.82, 0, 1)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(22, 22)
    highlight:SetPoint("CENTER", background, "CENTER")
    highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    highlight:SetVertexColor(1, 0.82, 0, 0.18)

    button:SetScript("OnClick", UI.Toggle)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", UpdateMinimapButtonFromCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateMinimapButtonFromCursor()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("KIC Greeter")
        GameTooltip:AddLine("Left-click: Open greeting settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move minimap button", 0.72, 0.72, 0.72)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    minimapButton = button
    PositionMinimapButton()
end

function UI.Initialize()
    if initialized then
        return
    end

    initialized = true
    CreateMinimapButton()
end

SLASH_KICLFGGREETER1 = "/kicgreet"
SlashCmdList.KICLFGGREETER = function()
    UI.Toggle()
end
