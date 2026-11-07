-- bad.lua: one example of each secret-lint finding kind. Never loaded by the game.
local hp = UnitHealth("player") if hp < 100 then end
local power = UnitPower("player") local half = power / 2
local name = UnitCastingInfo("target") local size = #name
local aura = C_UnitAuras.GetAuraDataByIndex("player", 1) local seen = {} seen[aura.spellId] = true
local inRange = UnitInRange("party1") if inRange then end
local frame = CreateFrame("Frame") frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
