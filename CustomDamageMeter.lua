-- Create the frame for the Damage Meter
local DamageMeterFrame = CreateFrame("Frame", "DamageMeterFrame", UIParent)
DamageMeterFrame:SetSize(300, 150)
DamageMeterFrame:SetPoint("CENTER")
DamageMeterFrame:Hide()

local title = DamageMeterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", DamageMeterFrame, "TOP", 0, -10)
title:SetText("Damage Meter")

-- Text area for displaying DPS
local dpsText = DamageMeterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dpsText:SetPoint("CENTER", DamageMeterFrame, "CENTER", 0, 0)
dpsText:SetText("Current DPS: 0")

-- Rotation suggestion text
local rotationText = DamageMeterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
rotationText:SetPoint("BOTTOM", DamageMeterFrame, "BOTTOM", 0, 20)
rotationText:SetText("Rotation Advice: ")

-- Variables for tracking damage and time
local totalDamage = 0
local combatStartTime = 0
local playerClass, playerSpec

-- Table to store DPS data for each class and spec
local dpsData = {}

-- Table to store player's spell history during combat
local spellHistory = {}

-- Table to store damage done by each spell
local spellDamage = {}

-- Table to store the best rotations (determined by highest DPS)
local bestRotations = {}

-- Table to store usable spells for the player's current spec
local usableSpells = {}

-- Function to get player class and spec
local function GetPlayerClassAndSpec()
    local className = UnitClass("player") -- Get player's class
    local specIndex = GetSpecialization() -- Gets the player's current spec index (1, 2, or 3)
    return className, specIndex
end

-- Function to detect all available and usable skills based on current spec
local function GetAvailableSkills()
    -- Reset usable spells
    usableSpells = {}

    -- Loop through the player's spellbook
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSpells do
            local spellName, _ = GetSpellBookItemName(j, BOOKTYPE_SPELL)
            if spellName and IsUsableSpell(spellName) then
                -- Add usable spells to the list
                table.insert(usableSpells, spellName)
            end
        end
    end
end

-- Function to store DPS for the current class and spec
local function StoreDPS(dps)
    local className, specIndex = GetPlayerClassAndSpec()
    
    if not dpsData[className] then
        dpsData[className] = {}
    end
    
    -- Store DPS for the current class and spec
    dpsData[className][specIndex] = dps
end

-- Function to build and update the best rotation database based on the combat log
local function UpdateBestRotation()
    local className, specIndex = GetPlayerClassAndSpec()

    -- Initialize bestRotations table for class and spec if not present
    if not bestRotations[className] then
        bestRotations[className] = {}
    end
    if not bestRotations[className][specIndex] then
        bestRotations[className][specIndex] = {rotation = {}, totalDPS = 0}
    end

    -- Calculate total DPS for current combat
    local totalSpellDamage = 0
    for spell, damage in pairs(spellDamage) do
        totalSpellDamage = totalSpellDamage + damage
    end
    
    -- If this combat's total damage is higher than the best so far, update the best rotation
    if totalSpellDamage > bestRotations[className][specIndex].totalDPS then
        bestRotations[className][specIndex].rotation = spellHistory
        bestRotations[className][specIndex].totalDPS = totalSpellDamage
    end
end

-- Function to get the best rotation for the player's current class and spec
local function GetBestRotation()
    local className, specIndex = GetPlayerClassAndSpec()
    if bestRotations[className] and bestRotations[className][specIndex] then
        return bestRotations[className][specIndex].rotation
    else
        return {}
    end
end

-- Function to track spell casts in real-time
local function TrackSpells(spellName, damage)
    -- Add the spell to the player's spell history
    table.insert(spellHistory, spellName)
    
    -- Track the damage done by the spell
    if not spellDamage[spellName] then
        spellDamage[spellName] = 0
    end
    spellDamage[spellName] = spellDamage[spellName] + damage
end

-- Function to compare the player's rotation to the best one
local function CompareRotation(spellHistory)
    local bestRotation = GetBestRotation()

    -- Compare player's spell history with the best rotation
    local suggestion = "Your rotation looks good!"

    for i, spell in ipairs(bestRotation) do
        if not spellHistory[i] or spellHistory[i] ~= spell then
            suggestion = "Try using " .. spell .. " more often."
            break
        end
    end

    return suggestion
end

-- Event listener function for tracking damage and spells
local function OnEvent(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName, _, amount = CombatLogGetCurrentEventInfo()
        
        if subEvent == "SPELL_DAMAGE" and sourceGUID == UnitGUID("player") then
            totalDamage = totalDamage + amount
            TrackSpells(spellName, amount)  -- Track spell casts and their damage in real-time
        elseif subEvent == "SWING_DAMAGE" and sourceGUID == UnitGUID("player") then
            local swingDamage = select(12, CombatLogGetCurrentEventInfo())
            totalDamage = totalDamage + swingDamage
            TrackSpells("Auto Attack", swingDamage)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat starts
        combatStartTime = GetTime()
        totalDamage = 0
        spellHistory = {}  -- Reset spell history at the start of each combat
        spellDamage = {}    -- Reset spell damage tracking
        DamageMeterFrame:Show()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ends
        local combatDuration = GetTime() - combatStartTime
        local dps = totalDamage / combatDuration
        dpsText:SetText(string.format("Current DPS: %.2f", dps))
        
        -- Store DPS for the current class and spec
        StoreDPS(dps)

        -- Compare the player's spell history to the best rotation
        UpdateBestRotation()  -- Update the best rotation database
        local advice = CompareRotation(spellHistory)
        rotationText:SetText("Rotation Advice: " .. advice)

        DamageMeterFrame:Hide()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Update available skills when the player's spec changes
        GetAvailableSkills()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Get available skills when the player enters the world (after login or reload)
        GetAvailableSkills()
    end
end

-- Register events for combat tracking and spec changes
DamageMeterFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
DamageMeterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
DamageMeterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
DamageMeterFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
DamageMeterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
DamageMeterFrame:SetScript("OnEvent", OnEvent)

-- Get player's class and specialization on login/reload
playerClass, playerSpec = GetPlayerClassAndSpec()


-- Declare the addon table
CustomDamageMeter = {}

-- Variable to track if the addon is enabled or disabled
CustomDamageMeter.isEnabled = true

-- Variable to hold damage data
CustomDamageMeter.damageData = {}

-- Function to toggle the addon on and off
function CustomDamageMeter:Toggle()
    self.isEnabled = not self.isEnabled
    if self.isEnabled then
        CustomDamageMeterFrameStatus:SetText("Addon is enabled")
        -- Start damage tracking
        self:StartTracking()
    else
        CustomDamageMeterFrameStatus:SetText("Addon is disabled")
        -- Stop damage tracking
        self:StopTracking()
    end
end

-- Function to start damage tracking
function CustomDamageMeter:StartTracking()
    self.damageData = {} -- Reset the damage data
    self:UpdateOutput()  -- Update the output display
    print("Damage tracking started.")
end

-- Function to stop damage tracking
function CustomDamageMeter:StopTracking()
    print("Damage tracking stopped.")
    -- Here, you might want to output or log the damage data
end

-- Function to update the output display
function CustomDamageMeter:UpdateOutput()
    local outputText = ""
    for name, data in pairs(self.damageData) do
        outputText = outputText .. name .. ": " .. data.totalDamage .. " damage\n"
    end

    if outputText == "" then
        outputText = "No damage dealt yet."
    end

    CustomDamageMeterOutput:SetText(outputText)
end

-- Event handler for combat log updates
local function OnCombatLogEvent(_, event, ...)
    if not CustomDamageMeter.isEnabled then return end

    local timestamp, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName, spellSchool, amount = ...
    
    -- Check if the event is a damage event from the player
    if eventType == "SPELL_DAMAGE" and sourceGUID == UnitGUID("player") then
        -- Initialize player damage data if it doesn't exist
        if not CustomDamageMeter.damageData[sourceName] then
            CustomDamageMeter.damageData[sourceName] = { totalDamage = 0, spellCount = {} }
        end

        -- Update total damage
        CustomDamageMeter.damageData[sourceName].totalDamage = CustomDamageMeter.damageData[sourceName].totalDamage + amount

        -- Update spell damage count
        if not CustomDamageMeter.damageData[sourceName].spellCount[spellName] then
            CustomDamageMeter.damageData[sourceName].spellCount[spellName] = 0
        end
        CustomDamageMeter.damageData[sourceName].spellCount[spellName] = CustomDamageMeter.damageData[sourceName].spellCount[spellName] + amount

        -- Update the output display with new data
        CustomDamageMeter:UpdateOutput()

        -- Debug output to show damage dealt
        print(sourceName .. " dealt " .. amount .. " damage with " .. spellName)
    end
end

-- Event to show the frame when the player logs in
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    CustomDamageMeter:ShowFrame()
end)

-- Function to show the addon frame
function CustomDamageMeter:ShowFrame()
    CustomDamageMeterFrame:Show()
end

-- Function to hide the addon frame
function CustomDamageMeter:HideFrame()
    CustomDamageMeterFrame:Hide()
end

-- Register for combat log events
local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", OnCombatLogEvent)
