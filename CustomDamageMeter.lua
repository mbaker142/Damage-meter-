-- Create the frame for the Damage Meter
local DamageMeterFrame = CreateFrame("Frame", "DamageMeterFrame", UIParent)
DamageMeterFrame:SetSize(300, 150)
DamageMeterFrame:SetPoint("CENTER")
DamageMeterFrame:Hide()

local title = DamageMeterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", DamageMeterFrame, "TOP", 0, -10)
title:SetText("Damage Meter")

local dpsText = DamageMeterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dpsText:SetPoint("CENTER", DamageMeterFrame, "CENTER")
dpsText:SetText("Current DPS: 0")

local rotationText = DamageMeterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
rotationText:SetPoint("BOTTOM", DamageMeterFrame, "BOTTOM", 0, 20)
rotationText:SetText("Rotation Advice: ")

local totalDamage, combatStartTime, dpsData, spellHistory, spellDamage, bestRotations = 0, 0, {}, {}, {}, {}
local playerClass, playerSpec = UnitClass("player"), GetSpecialization()

local function GetUsableSpells()
    local spells = {}
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSpells do
            local spellName = GetSpellBookItemName(j, BOOKTYPE_SPELL)
            if spellName and IsUsableSpell(spellName) then
                spells[#spells + 1] = spellName
            end
        end
    end
    return spells
end

local function StoreDPS(dps)
    if not dpsData[playerClass] then dpsData[playerClass] = {} end
    dpsData[playerClass][playerSpec] = dps
end

local function UpdateBestRotation()
    local totalSpellDamage = 0
    for _, damage in pairs(spellDamage) do totalSpellDamage = totalSpellDamage + damage end

    if not bestRotations[playerClass] then bestRotations[playerClass] = {} end
    if not bestRotations[playerClass][playerSpec] or totalSpellDamage > bestRotations[playerClass][playerSpec].totalDPS then
        bestRotations[playerClass][playerSpec] = { rotation = spellHistory, totalDPS = totalSpellDamage }
    end
end

local function CompareRotation()
    local bestRotation = bestRotations[playerClass] and bestRotations[playerClass][playerSpec] and bestRotations[playerClass][playerSpec].rotation or {}
    for i, spell in ipairs(bestRotation) do
        if not spellHistory[i] or spellHistory[i] ~= spell then
            return "Try using " .. spell .. " more often."
        end
    end
    return "Your rotation looks good!"
end

local function TrackDamage(spellName, damage)
    spellHistory[#spellHistory + 1] = spellName
    spellDamage[spellName] = (spellDamage[spellName] or 0) + damage
end

local function OnEvent(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName, _, amount = CombatLogGetCurrentEventInfo()
        if sourceGUID == UnitGUID("player") then
            local damage = subEvent == "SPELL_DAMAGE" and amount or (subEvent == "SWING_DAMAGE" and select(12, CombatLogGetCurrentEventInfo()) or 0)
            totalDamage = totalDamage + damage
            TrackDamage(spellName, damage)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        combatStartTime = GetTime()
        totalDamage, spellHistory, spellDamage = 0, {}, {}
        DamageMeterFrame:Show()
    elseif event == "PLAYER_REGEN_ENABLED" then
        local dps = totalDamage / (GetTime() - combatStartTime)
        dpsText:SetText(string.format("Current DPS: %.2f", dps))
        StoreDPS(dps)
        UpdateBestRotation()
        rotationText:SetText("Rotation Advice: " .. CompareRotation())
        DamageMeterFrame:Hide()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        playerSpec = GetSpecialization()
    end
end

DamageMeterFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
DamageMeterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
DamageMeterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
DamageMeterFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
DamageMeterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
DamageMeterFrame:SetScript("OnEvent", OnEvent)

CustomDamageMeter = {
    isEnabled = true,
    damageData = {},
    Toggle = function(self)
        self.isEnabled = not self.isEnabled
        print("Damage tracking " .. (self.isEnabled and "started." or "stopped."))
    end,
}

local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(_, event, ...) 
    if CustomDamageMeter.isEnabled then OnEvent(nil, event, ...) end 
end)
