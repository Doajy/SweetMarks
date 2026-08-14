-- SweetMarks
-- Popup keybind for quickly marking your current target, solo or in a group.
-- Visual style matches SweetLootHistory: flat dark panels, thin borders, single accent color.

BINDING_HEADER_SWEETMARKS = "SweetMarks"
BINDING_NAME_SWEETMARKS_TOGGLE = "Show/Toggle Mark Popup"

local ICON_NAMES = {
    "Star", "Circle", "Diamond", "Triangle",
    "Moon", "Square", "Cross", "Skull",
}

local ICON_SIZE = 28
local ICON_GAP = 5
local COLUMNS = 4
local PAD = 9
local HEADER_HEIGHT = 18

-- ===== Palette (matches SweetLootHistory) =====
local COLOR_BG          = { 0.06, 0.06, 0.08, 0.94 }
local COLOR_BORDER      = { 0.30, 0.30, 0.36, 1 }
local COLOR_HEADER      = { 0.13, 0.13, 0.16, 1 }
local COLOR_BTN         = { 0.16, 0.16, 0.20, 1 }
-- Alpha kept well under 1: this texture sits on the HIGHLIGHT draw layer,
-- which always renders above a button's OVERLAY-layer text/ARTWORK-layer
-- icons - opaque would hide them completely on hover instead of just tinting.
local COLOR_BTN_HOVER   = { 0.4, 0.4, 0.48, 0.5 }
local COLOR_ACCENT_LINE = { 0.35, 0.78, 0.98, 1 }

local function Flat(parent, layer)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    return tex
end

local function SetColor(tex, c)
    tex:SetVertexColor(c[1], c[2], c[3], c[4])
end

-- ===== Main frame =====

local iconsHeight = 2 * ICON_SIZE + ICON_GAP
local clearBtnHeight = 18
local ICON_GRID_GAP = 8
local frameWidth = PAD * 2 + COLUMNS * ICON_SIZE + (COLUMNS - 1) * ICON_GAP
local frameHeight = HEADER_HEIGHT + PAD + iconsHeight + ICON_GRID_GAP + clearBtnHeight + PAD

local frame = CreateFrame("Frame", "SweetMarksFrame", UIParent)
frame:SetWidth(frameWidth)
frame:SetHeight(frameHeight)
-- One strata above the Options window (also DIALOG) so the marks popup -
-- the thing you're actively holding a key for - never ends up hidden
-- behind Options just because Options was clicked into more recently.
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetToplevel(true)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
frame:SetBackdropColor(unpack(COLOR_BG))
frame:SetBackdropBorderColor(0.45, 0.45, 0.48, 1)
frame:EnableMouse(true)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:Hide()

-- Let Escape close the popup like a normal Blizzard dialog.
UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "SweetMarksFrame")

-- Manual drag: frame:StartMoving()/StopMovingOrSizing() caused repeatable
-- hard client crashes on this client build (ACCESS_VIOLATION, same native
-- instruction both times). This avoids those calls entirely, tracking the
-- cursor via OnUpdate and repositioning with plain SetPoint instead - the
-- same technique the minimap button already uses successfully below.
local dragStartCursorX, dragStartCursorY = 0, 0
local dragStartFrameX, dragStartFrameY = 0, 0

local function OnFrameDragUpdate()
    local scale = frame:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx = cx / scale
    cy = cy / scale
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
        dragStartFrameX + (cx - dragStartCursorX),
        dragStartFrameY + (cy - dragStartCursorY))
end

local function StartFrameDrag()
    local scale = frame:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    dragStartCursorX = cx / scale
    dragStartCursorY = cy / scale
    dragStartFrameX = frame:GetLeft() or 0
    dragStartFrameY = frame:GetBottom() or 0
    frame:SetScript("OnUpdate", OnFrameDragUpdate)
end

local function StopFrameDrag()
    frame:SetScript("OnUpdate", nil)
    local point, relativeTo, relPoint, x, y = frame:GetPoint()
    SweetMarksDB.point = point
    SweetMarksDB.relPoint = relPoint
    SweetMarksDB.x = x
    SweetMarksDB.y = y
end

-- Header bar
local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
header:SetHeight(HEADER_HEIGHT)

local headerBg = Flat(header)
headerBg:SetAllPoints(header)
SetColor(headerBg, COLOR_HEADER)

local headerDivider = Flat(header)
headerDivider:SetHeight(1)
headerDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
headerDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
SetColor(headerDivider, COLOR_BORDER)

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("CENTER", header, "CENTER", 0, 0)
title:SetTextColor(1, 1, 1, 1)
title:SetText("SweetMarks")

-- Only draggable in fixed-position mode (chosen in Options) and only while
-- unlocked - otherwise every show snaps back to the cursor anyway, so a drag
-- would just be undone the next time it opens.
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function()
    if SweetMarksDB and SweetMarksDB.fixedPosition and not SweetMarksDB.locked then
        StartFrameDrag()
    end
end)
header:SetScript("OnDragStop", StopFrameDrag)

-- Small lock button: only meaningful in fixed-position mode (chosen in
-- Options) - locks/unlocks whether the popup can currently be dragged.
-- Hidden entirely in cursor mode instead of just dimmed, since it does
-- nothing there. Self-contained (only updates its own label) rather than
-- reaching into the options panel's widgets, defined later in the file.
local lockBtn = CreateFrame("Button", "SweetMarksLockButton", header)
lockBtn:SetWidth(HEADER_HEIGHT)
lockBtn:SetHeight(HEADER_HEIGHT)
lockBtn:SetPoint("RIGHT", header, "RIGHT", 0, 0)

local lockLabel = lockBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lockLabel:SetPoint("CENTER", 0, 0)
lockLabel:SetText("L")
lockLabel:SetTextColor(1, 1, 1, 0.85)

local function UpdateLockButtonVisual()
    if not (SweetMarksDB and SweetMarksDB.fixedPosition) then
        lockBtn:Hide()
        return
    end
    lockBtn:Show()
    if SweetMarksDB.locked then
        lockLabel:SetTextColor(COLOR_ACCENT_LINE[1], COLOR_ACCENT_LINE[2], COLOR_ACCENT_LINE[3], 1)
    else
        lockLabel:SetTextColor(1, 1, 1, 0.85)
    end
end

lockBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(lockBtn, "ANCHOR_TOP")
    if SweetMarksDB.locked then
        GameTooltip:SetText("Position locked")
        GameTooltip:AddLine("Click to unlock so you can drag the header again.", 0.8, 0.8, 0.8, 1)
    else
        GameTooltip:SetText("Position unlocked")
        GameTooltip:AddLine("Drag the header to move it, then click to lock it in place.", 0.8, 0.8, 0.8, 1)
    end
    GameTooltip:Show()
end)
lockBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
lockBtn:SetScript("OnClick", function()
    if not (SweetMarksDB and SweetMarksDB.fixedPosition) then
        return
    end
    SweetMarksDB.locked = not SweetMarksDB.locked
    SweetMarks_RefreshLockVisuals()
end)

-- Icon grid
local iconSlots = {}
local iconTextures = {}
for i = 1, 8 do
    local col = mod(i - 1, COLUMNS)
    local row = floor((i - 1) / COLUMNS)

    local slot = CreateFrame("Button", "SweetMarksButton" .. i, frame)
    slot:SetWidth(ICON_SIZE)
    slot:SetHeight(ICON_SIZE)
    slot:SetPoint("TOPLEFT", frame, "TOPLEFT",
        PAD + col * (ICON_SIZE + ICON_GAP),
        -(HEADER_HEIGHT + PAD) - row * (ICON_SIZE + ICON_GAP))

    local bg = Flat(slot)
    bg:SetAllPoints(slot)
    SetColor(bg, COLOR_BTN)

    local hl = Flat(slot, "HIGHLIGHT")
    hl:SetAllPoints(slot)
    SetColor(hl, COLOR_BTN_HOVER)

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(ICON_SIZE - 8)
    icon:SetHeight(ICON_SIZE - 8)
    icon:SetPoint("CENTER")
    -- Vanilla 1.12 packs all 8 marks into one sheet (no per-icon files like
    -- retail). SetRaidTargetIconTexture only slices coordinates - it never
    -- sets the file itself (Blizzard's XML pre-assigns that), so we must.
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    SetRaidTargetIconTexture(icon, i)

    local index = i
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            SweetMarks_Clear()
        else
            SweetMarks_Mark(index)
        end
    end)
    slot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(slot, "ANCHOR_TOP")
        GameTooltip:SetText(ICON_NAMES[index])
        GameTooltip:AddLine("Right-click to clear the mark.", 0.6, 0.85, 1, 1)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    iconSlots[i] = slot
    iconTextures[i] = icon
end

-- Clear button
local clearBtn = CreateFrame("Button", "SweetMarksClearButton", frame)
clearBtn:SetWidth(COLUMNS * ICON_SIZE + (COLUMNS - 1) * ICON_GAP)
clearBtn:SetHeight(clearBtnHeight)
clearBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, PAD)

local clearBg = Flat(clearBtn)
clearBg:SetAllPoints(clearBtn)
SetColor(clearBg, COLOR_BTN)

local clearHl = Flat(clearBtn, "HIGHLIGHT")
clearHl:SetAllPoints(clearBtn)
SetColor(clearHl, COLOR_BTN_HOVER)

local clearLabel = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
clearLabel:SetPoint("CENTER")
clearLabel:SetText("Clear Mark")
clearLabel:SetTextColor(1, 1, 1, 0.85)

clearBtn:SetScript("OnEnter", function()
    clearLabel:SetTextColor(COLOR_ACCENT_LINE[1], COLOR_ACCENT_LINE[2], COLOR_ACCENT_LINE[3], 1)
end)
clearBtn:SetScript("OnLeave", function()
    clearLabel:SetTextColor(1, 1, 1, 0.85)
end)
clearBtn:SetScript("OnClick", function()
    SweetMarks_Clear()
end)

-- Slim mode has no header, so it gets its own tiny drag/lock handle tucked
-- in the corner - same job the header does, just condensed. The "L"
-- disappears once locked so it doesn't clutter the icon row; the hotspot
-- and tooltip stay active either way.
local SLIM_HANDLE_SIZE = 11

local slimHandle = CreateFrame("Button", "SweetMarksSlimLockButton", frame)
slimHandle:SetWidth(SLIM_HANDLE_SIZE)
slimHandle:SetHeight(SLIM_HANDLE_SIZE)
slimHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
slimHandle:SetFrameLevel(frame:GetFrameLevel() + 20)
slimHandle:EnableMouse(true)
slimHandle:Hide()

local slimHandleLabel = slimHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
slimHandleLabel:SetPoint("CENTER", 0, 0)
slimHandleLabel:SetTextColor(1, 1, 1, 0.7)
slimHandleLabel:SetText("L")

local function UpdateSlimHandleVisual()
    if not (SweetMarksDB and SweetMarksDB.slim and SweetMarksDB.fixedPosition) then
        slimHandle:Hide()
        return
    end
    slimHandle:Show()
    if SweetMarksDB.locked then
        slimHandleLabel:SetText("")
    else
        slimHandleLabel:SetText("L")
    end
end

-- Shared by both the header's lock button and this handle, defined after
-- both exist so it can safely update either one regardless of which file
-- section it's called from (global lookup happens at call time, not here).
function SweetMarks_RefreshLockVisuals()
    UpdateLockButtonVisual()
    UpdateSlimHandleVisual()
end

slimHandle:SetScript("OnEnter", function()
    GameTooltip:SetOwner(slimHandle, "ANCHOR_BOTTOMRIGHT")
    if SweetMarksDB and SweetMarksDB.locked then
        GameTooltip:SetText("Position locked")
        GameTooltip:AddLine("Click to unlock so you can drag it again.", 0.8, 0.8, 0.8, 1)
    else
        GameTooltip:SetText("Position unlocked")
        GameTooltip:AddLine("Drag to move it, click to lock it in place.", 0.8, 0.8, 0.8, 1)
    end
    GameTooltip:Show()
end)
slimHandle:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
slimHandle:SetScript("OnClick", function()
    if not (SweetMarksDB and SweetMarksDB.fixedPosition) then
        return
    end
    SweetMarksDB.locked = not SweetMarksDB.locked
    SweetMarks_RefreshLockVisuals()
end)

slimHandle:RegisterForDrag("LeftButton")
slimHandle:SetScript("OnDragStart", function()
    if SweetMarksDB and SweetMarksDB.fixedPosition and not SweetMarksDB.locked then
        StartFrameDrag()
    end
end)
slimHandle:SetScript("OnDragStop", StopFrameDrag)

-- Slim mode: single row of smaller icons, no title bar or Clear Mark button.
-- Slot/icon sizes and the frame itself are resized and re-anchored on
-- demand rather than kept as two pre-built layouts, since re-running this
-- is cheap and it stays correct if the base sizing constants ever change.
local SLIM_SCALE = 0.8
local SLIM_ICON_SIZE = ICON_SIZE * SLIM_SCALE
local SLIM_ICON_GAP = ICON_GAP * SLIM_SCALE
local SLIM_ICON_INSET = 8 * SLIM_SCALE
local slimFrameWidth = PAD * 2 + 8 * SLIM_ICON_SIZE + 7 * SLIM_ICON_GAP
local slimFrameHeight = PAD * 2 + SLIM_ICON_SIZE

function SweetMarks_ApplySlim(isSlim)
    if isSlim then
        header:Hide()
        clearBtn:Hide()
    else
        header:Show()
        clearBtn:Show()
    end
    SweetMarks_RefreshLockVisuals()

    for i = 1, 8 do
        local slot = iconSlots[i]
        local icon = iconTextures[i]
        slot:ClearAllPoints()

        if isSlim then
            slot:SetWidth(SLIM_ICON_SIZE)
            slot:SetHeight(SLIM_ICON_SIZE)
            slot:SetPoint("TOPLEFT", frame, "TOPLEFT",
                PAD + (i - 1) * (SLIM_ICON_SIZE + SLIM_ICON_GAP), -PAD)
            icon:SetWidth(SLIM_ICON_SIZE - SLIM_ICON_INSET)
            icon:SetHeight(SLIM_ICON_SIZE - SLIM_ICON_INSET)
        else
            local col = mod(i - 1, COLUMNS)
            local row = floor((i - 1) / COLUMNS)
            slot:SetWidth(ICON_SIZE)
            slot:SetHeight(ICON_SIZE)
            slot:SetPoint("TOPLEFT", frame, "TOPLEFT",
                PAD + col * (ICON_SIZE + ICON_GAP),
                -(HEADER_HEIGHT + PAD) - row * (ICON_SIZE + ICON_GAP))
            icon:SetWidth(ICON_SIZE - 8)
            icon:SetHeight(ICON_SIZE - 8)
        end
    end

    if isSlim then
        frame:SetWidth(slimFrameWidth)
        frame:SetHeight(slimFrameHeight)
    else
        frame:SetWidth(frameWidth)
        frame:SetHeight(frameHeight)
    end
end

-- ===== Options panel (separate window, opened via /sm options) =====

local OPTIONS_WIDTH = 250
local OPTIONS_HEIGHT = 396

local optionsFrame = CreateFrame("Frame", "SweetMarksOptionsFrame", UIParent)
optionsFrame:SetWidth(OPTIONS_WIDTH)
optionsFrame:SetHeight(OPTIONS_HEIGHT)
optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
optionsFrame:SetFrameStrata("DIALOG")
optionsFrame:SetToplevel(true)
optionsFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
optionsFrame:SetBackdropColor(unpack(COLOR_BG))
optionsFrame:SetBackdropBorderColor(0.45, 0.45, 0.48, 1)
optionsFrame:EnableMouse(true)
optionsFrame:SetMovable(true)
optionsFrame:Hide()

UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "SweetMarksOptionsFrame")

local optHeader = CreateFrame("Frame", nil, optionsFrame)
optHeader:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 1, -1)
optHeader:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -1, -1)
optHeader:SetHeight(HEADER_HEIGHT)

local optHeaderBg = Flat(optHeader)
optHeaderBg:SetAllPoints(optHeader)
SetColor(optHeaderBg, COLOR_HEADER)

local optHeaderDivider = Flat(optHeader)
optHeaderDivider:SetHeight(1)
optHeaderDivider:SetPoint("BOTTOMLEFT", optHeader, "BOTTOMLEFT", 0, 0)
optHeaderDivider:SetPoint("BOTTOMRIGHT", optHeader, "BOTTOMRIGHT", 0, 0)
SetColor(optHeaderDivider, COLOR_BORDER)

local optTitle = optHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optTitle:SetPoint("CENTER", optHeader, "CENTER", 0, 0)
optTitle:SetTextColor(1, 1, 1, 1)
optTitle:SetText("SweetMarks Options")

optHeader:EnableMouse(true)
optHeader:RegisterForDrag("LeftButton")
optHeader:SetScript("OnDragStart", function() optionsFrame:StartMoving() end)
optHeader:SetScript("OnDragStop", function() optionsFrame:StopMovingOrSizing() end)

local optCloseBtn = CreateFrame("Button", nil, optHeader)
optCloseBtn:SetWidth(HEADER_HEIGHT)
optCloseBtn:SetHeight(HEADER_HEIGHT)
optCloseBtn:SetPoint("RIGHT", optHeader, "RIGHT", 0, 0)
local optCloseLabel = optCloseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
optCloseLabel:SetPoint("CENTER", 0, 0)
optCloseLabel:SetText("X")
optCloseLabel:SetTextColor(1, 1, 1, 0.85)
optCloseBtn:SetScript("OnEnter", function() optCloseLabel:SetTextColor(1, 0.4, 0.4, 1) end)
optCloseBtn:SetScript("OnLeave", function() optCloseLabel:SetTextColor(1, 1, 1, 0.85) end)
optCloseBtn:SetScript("OnClick", function() optionsFrame:Hide() end)

local optHelpBtn = CreateFrame("Button", nil, optHeader)
optHelpBtn:SetWidth(14)
optHelpBtn:SetHeight(14)
optHelpBtn:SetPoint("LEFT", optHeader, "LEFT", 6, 0)
optHelpBtn:SetFrameLevel(optHeader:GetFrameLevel() + 10)
optHelpBtn:EnableMouse(true)

local optHelpBg = Flat(optHelpBtn)
optHelpBg:SetAllPoints(optHelpBtn)
SetColor(optHelpBg, COLOR_BTN)

local optHelpLabel = optHelpBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
optHelpLabel:SetPoint("CENTER", 0, 0)
optHelpLabel:SetText("?")
optHelpLabel:SetTextColor(0.6, 0.85, 1, 1)

optHelpBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(optHelpBtn, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("How SweetMarks works", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Hold your keybind to open the mark popup, then click an icon to mark your current target.", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine("Clear Mark (or right-click any icon) removes the mark from your current target only.", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("At Cursor: the popup opens under your mouse and closes as soon as you release the key.", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine("Fixed Position: the popup opens in a set spot and stays open until you press the key again. Drag its header to move it (or use the Reposition arrows below), and use the lock button to stop it moving by accident.", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Slim popup: shows just a single smaller row of icons, no title bar or Clear Mark button.", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Mark unit under mouse: targets whatever's under your cursor the instant the popup opens, so you can mark it without clicking it first. Only works over the 3D world or nameplates, not unit frames.", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("The minimap button reopens this Options window.", 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
end)
optHelpBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Fixed-position toggle switch: same CheckButton control/click path as
-- before (proven stable), just restyled as a sliding track+thumb instead of
-- a square checkbox, with one label whose text swaps between the two modes.
-- The switch is centered directly (fixed width, trivial); its label sits on
-- its own row below and is centered independently via CENTER anchoring, so
-- it stays truly centered no matter how long "At Cursor" vs "Fixed Position"
-- is, instead of just centering an invisible box with the content packed
-- to one side inside it.
local SWITCH_WIDTH = 44
local SWITCH_HEIGHT = 18

local switchDesc = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
switchDesc:SetPoint("TOP", optionsFrame, "TOP", 0, -(HEADER_HEIGHT + 12))
switchDesc:SetTextColor(1, 1, 1, 1)
switchDesc:SetText("Where the popup opens")

local fixedCheck = CreateFrame("CheckButton", "SweetMarksFixedPositionSwitch", optionsFrame)
fixedCheck:SetWidth(SWITCH_WIDTH)
fixedCheck:SetHeight(SWITCH_HEIGHT)
fixedCheck:SetPoint("TOP", switchDesc, "BOTTOM", 0, -10)
fixedCheck:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
fixedCheck:SetBackdropColor(unpack(COLOR_BTN))
fixedCheck:SetBackdropBorderColor(unpack(COLOR_BORDER))

local switchThumb = fixedCheck:CreateTexture(nil, "ARTWORK")
switchThumb:SetTexture("Interface\\Buttons\\WHITE8x8")
switchThumb:SetWidth(SWITCH_WIDTH / 2 - 4)
switchThumb:SetHeight(SWITCH_HEIGHT - 4)

local switchLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
switchLabel:SetPoint("TOP", fixedCheck, "BOTTOM", 0, -4)

-- Explicit SetWidth (not just LEFT+RIGHT anchors) so long lines reliably
-- word-wrap here instead of overflowing the panel.
local HINT_WIDTH = OPTIONS_WIDTH - 24

local fixedHint = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
fixedHint:SetWidth(HINT_WIDTH)
fixedHint:SetPoint("TOP", switchLabel, "BOTTOM", 0, -10)
fixedHint:SetJustifyH("CENTER")
fixedHint:SetText("Off: hold to show, release to hide.\nOn: press to toggle - drag header to move.")

-- Slim popup + Lock position checkboxes side by side, so it's clear the
-- lock mainly pairs with the slim popup (whose own lock handle is tiny).
-- Both labels are constant text (never change at runtime), so a fixed-width
-- row can be centered safely here without the wobble a variable-length
-- label would cause.
local SLIM_LOCK_ROW_WIDTH = 216
local slimLockRow = CreateFrame("Frame", nil, optionsFrame)
slimLockRow:SetWidth(SLIM_LOCK_ROW_WIDTH)
slimLockRow:SetHeight(16)
slimLockRow:SetPoint("TOP", fixedHint, "BOTTOM", 0, -14)

local slimCheck = CreateFrame("CheckButton", nil, optionsFrame)
slimCheck:SetWidth(16)
slimCheck:SetHeight(16)
slimCheck:SetPoint("LEFT", slimLockRow, "LEFT", 0, 0)
slimCheck:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
slimCheck:SetBackdropColor(unpack(COLOR_BTN))
slimCheck:SetBackdropBorderColor(unpack(COLOR_BORDER))
slimCheck:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
local slimCheckHl = slimCheck:GetHighlightTexture()
slimCheckHl:SetVertexColor(1, 1, 1, 0.08)
slimCheck:SetCheckedTexture("Interface\\Buttons\\WHITE8x8")
local slimCheckedTex = slimCheck:GetCheckedTexture()
slimCheckedTex:ClearAllPoints()
slimCheckedTex:SetPoint("TOPLEFT", slimCheck, "TOPLEFT", 3, -3)
slimCheckedTex:SetPoint("BOTTOMRIGHT", slimCheck, "BOTTOMRIGHT", -3, 3)
slimCheckedTex:SetVertexColor(unpack(COLOR_ACCENT_LINE))

local slimLabel = slimCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
slimLabel:SetPoint("LEFT", slimCheck, "RIGHT", 6, 0)
slimLabel:SetText("Slim Popup")

-- Lock position - mirrors SweetMarksDB.locked directly (checked = locked),
-- and only shows up in Fixed Position mode, same as the on-frame lock
-- controls it stays in sync with.
local lockCheck = CreateFrame("CheckButton", nil, optionsFrame)
lockCheck:SetWidth(16)
lockCheck:SetHeight(16)
lockCheck:SetPoint("LEFT", slimLockRow, "LEFT", 110, 0)
lockCheck:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
lockCheck:SetBackdropColor(unpack(COLOR_BTN))
lockCheck:SetBackdropBorderColor(unpack(COLOR_BORDER))
lockCheck:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
local lockCheckHl = lockCheck:GetHighlightTexture()
lockCheckHl:SetVertexColor(1, 1, 1, 0.08)
lockCheck:SetCheckedTexture("Interface\\Buttons\\WHITE8x8")
local lockCheckedTex = lockCheck:GetCheckedTexture()
lockCheckedTex:ClearAllPoints()
lockCheckedTex:SetPoint("TOPLEFT", lockCheck, "TOPLEFT", 3, -3)
lockCheckedTex:SetPoint("BOTTOMRIGHT", lockCheck, "BOTTOMRIGHT", -3, 3)
lockCheckedTex:SetVertexColor(unpack(COLOR_ACCENT_LINE))

local lockCheckLabel = lockCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
lockCheckLabel:SetPoint("LEFT", lockCheck, "RIGHT", 6, 0)
lockCheckLabel:SetText("Lock Position")

local slimHint = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
slimHint:SetWidth(HINT_WIDTH)
slimHint:SetPoint("TOP", slimLockRow, "BOTTOM", 0, -10)
slimHint:SetJustifyH("CENTER")
slimHint:SetText("Slim popup: all 8 icons in one smaller row, no title bar or Clear Mark button. Lock position: stops the popup being dragged.")

slimCheck:SetScript("OnClick", function()
    local isSlim = this:GetChecked() and true or false
    SweetMarksDB.slim = isSlim
    SweetMarks_ApplySlim(isSlim)
end)

local function UpdateLockCheckboxVisual()
    if not (SweetMarksDB and SweetMarksDB.fixedPosition) then
        lockCheck:Hide()
        lockCheckLabel:Hide()
        return
    end
    lockCheck:Show()
    lockCheckLabel:Show()
    lockCheck:SetChecked(SweetMarksDB.locked)
end

lockCheck:SetScript("OnEnter", function()
    GameTooltip:SetOwner(lockCheck, "ANCHOR_TOP")
    GameTooltip:SetText("Lock Position")
    GameTooltip:AddLine("Stops the popup being dragged - handy for the slim popup, whose own lock handle is tiny.", 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
end)
lockCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
lockCheck:SetScript("OnClick", function()
    SweetMarksDB.locked = this:GetChecked() and true or false
    SweetMarks_RefreshLockVisuals()
end)

local function UpdateSwitchVisual(isFixed)
    switchThumb:ClearAllPoints()
    if isFixed then
        switchThumb:SetPoint("RIGHT", fixedCheck, "RIGHT", -2, 0)
        SetColor(switchThumb, COLOR_ACCENT_LINE)
        switchLabel:SetText("Fixed Position")
    else
        switchThumb:SetPoint("LEFT", fixedCheck, "LEFT", 2, 0)
        SetColor(switchThumb, COLOR_BORDER)
        switchLabel:SetText("At Cursor")
    end
end

fixedCheck:SetScript("OnClick", function()
    local isFixed = this:GetChecked() and true or false
    SweetMarksDB.fixedPosition = isFixed
    UpdateSwitchVisual(isFixed)
    SweetMarks_RefreshLockVisuals()
    UpdateLockCheckboxVisual()
    SweetMarks_UpdateNudgeVisual()
end)

-- Mouseover marking - grabs whatever's under your mouse as your target the
-- moment the popup opens (only works over the 3D world/nameplates, not
-- unit frames, per vanilla's own mouseover limitations). Off by default
-- since it's a real gameplay side effect (changes your actual target).
local mouseoverCheck = CreateFrame("CheckButton", nil, optionsFrame)
mouseoverCheck:SetWidth(16)
mouseoverCheck:SetHeight(16)
mouseoverCheck:SetPoint("TOP", slimHint, "BOTTOM", 0, -14)
mouseoverCheck:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
mouseoverCheck:SetBackdropColor(unpack(COLOR_BTN))
mouseoverCheck:SetBackdropBorderColor(unpack(COLOR_BORDER))
mouseoverCheck:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
local mouseoverCheckHl = mouseoverCheck:GetHighlightTexture()
mouseoverCheckHl:SetVertexColor(1, 1, 1, 0.08)
mouseoverCheck:SetCheckedTexture("Interface\\Buttons\\WHITE8x8")
local mouseoverCheckedTex = mouseoverCheck:GetCheckedTexture()
mouseoverCheckedTex:ClearAllPoints()
mouseoverCheckedTex:SetPoint("TOPLEFT", mouseoverCheck, "TOPLEFT", 3, -3)
mouseoverCheckedTex:SetPoint("BOTTOMRIGHT", mouseoverCheck, "BOTTOMRIGHT", -3, 3)
mouseoverCheckedTex:SetVertexColor(unpack(COLOR_ACCENT_LINE))

local mouseoverCheckLabel = mouseoverCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
mouseoverCheckLabel:SetPoint("TOP", mouseoverCheck, "BOTTOM", 0, -4)
mouseoverCheckLabel:SetText("Mark unit under mouse")

local mouseoverHint = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
mouseoverHint:SetWidth(HINT_WIDTH)
mouseoverHint:SetPoint("TOP", mouseoverCheckLabel, "BOTTOM", 0, -6)
mouseoverHint:SetJustifyH("CENTER")
mouseoverHint:SetText("Targets whatever's under your cursor when the popup opens, so you don't have to click it first. Only works over the 3D world or nameplates, not unit frames.")

mouseoverCheck:SetScript("OnEnter", function()
    GameTooltip:SetOwner(mouseoverCheck, "ANCHOR_TOP")
    GameTooltip:SetText("Mark unit under mouse")
    GameTooltip:AddLine("Changes your actual target to whatever's under your mouse the instant the popup opens.", 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
end)
mouseoverCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
mouseoverCheck:SetScript("OnClick", function()
    SweetMarksDB.mouseoverMark = this:GetChecked() and true or false
end)

-- Reposition buttons - a safe stand-in for dragging, which crashes this
-- client. Nudges the popup by a fixed step using plain SetPoint, never
-- StartMoving/StopMovingOrSizing. Only meaningful in Fixed Position mode,
-- since At Cursor always re-centers on the mouse when it opens anyway.
local NUDGE_STEP = 10

local nudgeHeading = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nudgeHeading:SetPoint("TOP", mouseoverHint, "BOTTOM", 0, -14)
nudgeHeading:SetTextColor(1, 1, 1, 1)
nudgeHeading:SetText("Reposition")

local function NudgeFrame(dx, dy)
    local point, relativeTo, relPoint, x, y = frame:GetPoint()
    x = (x or 0) + dx
    y = (y or 0) + dy
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo or UIParent, relPoint, x, y)
    SweetMarksDB.point = point
    SweetMarksDB.relPoint = relPoint
    SweetMarksDB.x = x
    SweetMarksDB.y = y
end

local NUDGE_BTN_SIZE = 22
local NUDGE_GAP = 4
local NUDGE_ROW_WIDTH = 4 * NUDGE_BTN_SIZE + 3 * NUDGE_GAP

local nudgeRow = CreateFrame("Frame", nil, optionsFrame)
nudgeRow:SetWidth(NUDGE_ROW_WIDTH)
nudgeRow:SetHeight(NUDGE_BTN_SIZE)
nudgeRow:SetPoint("TOP", nudgeHeading, "BOTTOM", 0, -8)

local nudgeButtons = {}

local function CreateNudgeButton(xOffset, label, tooltipText, dx, dy)
    local btn = CreateFrame("Button", nil, optionsFrame)
    btn:SetWidth(NUDGE_BTN_SIZE)
    btn:SetHeight(NUDGE_BTN_SIZE)
    btn:SetPoint("LEFT", nudgeRow, "LEFT", xOffset, 0)

    local bg = Flat(btn)
    bg:SetAllPoints(btn)
    SetColor(bg, COLOR_BTN)

    local hl = Flat(btn, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    SetColor(hl, COLOR_BTN_HOVER)

    local glyph = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    glyph:SetPoint("CENTER")
    glyph:SetText(label)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        NudgeFrame(dx, dy)
    end)

    table.insert(nudgeButtons, btn)
    return btn
end

CreateNudgeButton(0, "<", "Move left", -NUDGE_STEP, 0)
CreateNudgeButton(NUDGE_BTN_SIZE + NUDGE_GAP, "^", "Move up", 0, NUDGE_STEP)
CreateNudgeButton(2 * (NUDGE_BTN_SIZE + NUDGE_GAP), "v", "Move down", 0, -NUDGE_STEP)
CreateNudgeButton(3 * (NUDGE_BTN_SIZE + NUDGE_GAP), ">", "Move right", NUDGE_STEP, 0)

-- Global (not local) so fixedCheck's OnClick - defined earlier in the file,
-- before these widgets exist - can call it safely: global lookups resolve
-- at call time, unlike local upvalues which need the closure defined after
-- the local they capture.
function SweetMarks_UpdateNudgeVisual()
    if not (SweetMarksDB and SweetMarksDB.fixedPosition) then
        nudgeHeading:Hide()
        for i = 1, table.getn(nudgeButtons) do
            nudgeButtons[i]:Hide()
        end
        return
    end
    nudgeHeading:Show()
    for i = 1, table.getn(nudgeButtons) do
        nudgeButtons[i]:Show()
    end
end

local function ResetPosition()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    SweetMarksDB.point = nil
    SweetMarksDB.relPoint = nil
    SweetMarksDB.x = nil
    SweetMarksDB.y = nil
end

local resetBtn = CreateFrame("Button", nil, optionsFrame)
resetBtn:SetWidth(OPTIONS_WIDTH - 24)
resetBtn:SetHeight(20)
resetBtn:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 12)

local resetBg = Flat(resetBtn)
resetBg:SetAllPoints(resetBtn)
SetColor(resetBg, COLOR_BTN)

local resetHl = Flat(resetBtn, "HIGHLIGHT")
resetHl:SetAllPoints(resetBtn)
SetColor(resetHl, COLOR_BTN_HOVER)

local resetLabel = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
resetLabel:SetPoint("CENTER")
resetLabel:SetText("Reset Position")
resetLabel:SetTextColor(1, 1, 1, 0.85)

resetBtn:SetScript("OnEnter", function()
    resetLabel:SetTextColor(COLOR_ACCENT_LINE[1], COLOR_ACCENT_LINE[2], COLOR_ACCENT_LINE[3], 1)
end)
resetBtn:SetScript("OnLeave", function()
    resetLabel:SetTextColor(1, 1, 1, 0.85)
end)
resetBtn:SetScript("OnClick", ResetPosition)

-- ===== Minimap button =====
-- Same construction SweetLootHistory uses (angle-based drag around the
-- Minimap's edge), just with a real icon texture instead of a text glyph.

local minimapButton = CreateFrame("Button", "SweetMarksMinimapButton", Minimap)
minimapButton:SetWidth(31)
minimapButton:SetHeight(31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mmBackground = minimapButton:CreateTexture(nil, "BACKGROUND")
mmBackground:SetWidth(20)
mmBackground:SetHeight(20)
mmBackground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
mmBackground:SetPoint("TOPLEFT", 7, -5)

-- Skull raid mark, sliced from the same sheet the popup itself uses - a
-- direct symbol of what this addon actually does, not just a generic icon.
local mmIcon = minimapButton:CreateTexture(nil, "ARTWORK")
mmIcon:SetWidth(20)
mmIcon:SetHeight(20)
mmIcon:SetPoint("CENTER", 1, -1)
mmIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
SetRaidTargetIconTexture(mmIcon, 8)

local mmBorder = minimapButton:CreateTexture(nil, "OVERLAY")
mmBorder:SetWidth(53)
mmBorder:SetHeight(53)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetPoint("TOPLEFT", 0, 0)

function SweetMarks_SetMinimapAngle(angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnMinimapDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.atan2(py - my, px - mx)
    SweetMarksDB.minimapAngle = angle
    SweetMarks_SetMinimapAngle(angle)
end

minimapButton:SetMovable(true)
minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function() this:SetScript("OnUpdate", OnMinimapDragUpdate) end)
minimapButton:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)

minimapButton:SetScript("OnClick", function()
    SweetMarks_ToggleOptions()
end)

minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("SweetMarks")
    GameTooltip:AddLine("Click to open options", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

function SweetMarks_ToggleOptions()
    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        fixedCheck:SetChecked(SweetMarksDB.fixedPosition)
        UpdateSwitchVisual(SweetMarksDB.fixedPosition and true or false)
        slimCheck:SetChecked(SweetMarksDB.slim)
        mouseoverCheck:SetChecked(SweetMarksDB.mouseoverMark)
        UpdateLockCheckboxVisual()
        SweetMarks_UpdateNudgeVisual()
        optionsFrame:Show()
    end
end

-- ===== Saved variables =====

local dbLoader = CreateFrame("Frame")
dbLoader:RegisterEvent("ADDON_LOADED")
dbLoader:SetScript("OnEvent", function()
    if arg1 ~= "SweetMarks" then return end
    SweetMarksDB = SweetMarksDB or {}
    if SweetMarksDB.fixedPosition == nil then
        SweetMarksDB.fixedPosition = false
    end
    if SweetMarksDB.locked == nil then
        SweetMarksDB.locked = false
    end
    if SweetMarksDB.slim == nil then
        SweetMarksDB.slim = false
    end
    if SweetMarksDB.mouseoverMark == nil then
        SweetMarksDB.mouseoverMark = false
    end
    SweetMarks_ApplySlim(SweetMarksDB.slim)
    if SweetMarksDB.point then
        frame:ClearAllPoints()
        frame:SetPoint(SweetMarksDB.point, UIParent, SweetMarksDB.relPoint, SweetMarksDB.x, SweetMarksDB.y)
    end
    SweetMarksDB.minimapAngle = SweetMarksDB.minimapAngle or math.rad(45)
    SweetMarks_SetMinimapAngle(SweetMarksDB.minimapAngle)
end)

-- ===== Behavior =====

function SweetMarks_Mark(index)
    if not UnitExists("target") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200SweetMarks:|r No target selected.")
        return
    end
    SetRaidTarget("target", index)
end

function SweetMarks_Clear()
    if UnitExists("target") then
        SetRaidTarget("target", 0)
    end
end

local function SweetMarks_PositionAtCursor()
    local scale = frame:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x = x / scale
    y = y / scale

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- Called from Bindings.xml on key-down. Cursor mode: opens at the mouse
-- (paired with SweetMarks_Hide on key-up for hold-to-show). Fixed-position
-- mode doesn't hide on release, so key-down toggles it open/closed instead.
function SweetMarks_Show()
    -- Grab whatever's under the mouse right now, before it moves onto the
    -- popup to click an icon - "mouseover" only reflects the 3D world/
    -- nameplates in vanilla, and only while the cursor is actually there,
    -- so this is the one moment it's usable. Turns it into your real
    -- target so the normal marking flow (which always acts on "target")
    -- needs no other changes.
    if SweetMarksDB and SweetMarksDB.mouseoverMark and UnitExists("mouseover") then
        TargetUnit("mouseover")
    end

    if SweetMarksDB and SweetMarksDB.fixedPosition then
        if SweetMarksFrame:IsShown() then
            SweetMarksFrame:Hide()
        else
            SweetMarksFrame:Show()
        end
        return
    end

    SweetMarks_PositionAtCursor()
    SweetMarksFrame:Show()
end

-- Called from Bindings.xml on key-up: closes the popup, except in
-- fixed-position mode where it stays open until toggled again.
function SweetMarks_Hide()
    if SweetMarksDB and SweetMarksDB.fixedPosition then
        return
    end
    SweetMarksFrame:Hide()
end

SLASH_SWEETMARKS1 = "/sweetmarks"
SLASH_SWEETMARKS2 = "/sm"
SlashCmdList["SWEETMARKS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "options" or msg == "option" then
        SweetMarks_ToggleOptions()
        return
    end
    -- No hold/release from a chat command, so just flip visibility for testing.
    if SweetMarksFrame:IsShown() then
        SweetMarks_Hide()
    else
        SweetMarks_Show()
    end
end

SLASH_SWEETMARKSOPTIONS1 = "/smoptions"
SlashCmdList["SWEETMARKSOPTIONS"] = function()
    SweetMarks_ToggleOptions()
end
