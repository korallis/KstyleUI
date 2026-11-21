-- Blizzard.lua: hides Blizzard's player, target, focus, pet and boss frames through KstyleUI.Safe while KstyleUI's own frames replace them, and plays the target-lost sound their hidden target frame cannot.
local _, ns = ...

local K = KstyleUI
local Settings = ns.Settings

local Blizzard = {}
ns.Blizzard = Blizzard

local FRAMES = {
	{ kind = "player", names = { "PlayerFrame" } },
	{ kind = "target", names = { "TargetFrame" } },
	{ kind = "focus", names = { "FocusFrame" } },
	{ kind = "pet", names = { "PetFrame" } },
	{ kind = "boss", names = { "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame", "Boss4TargetFrame", "Boss5TargetFrame" } },
	{ kind = "player", setting = "castbar", names = { "PlayerCastingBarFrame" } },
	{ kind = "pet", setting = "castbar", framed = true, names = { "PetCastingBarFrame" } },
}
Blizzard.FRAMES = FRAMES

local logged = {}

function Blizzard.Apply(active)
	local Safe = K.Safe
	local hideAll = active and Settings.Module().hideBlizzard == true
	for _, entry in ipairs(FRAMES) do
		local hide = hideAll and Settings.Value(entry.kind, entry.setting or "enabled") and (not entry.framed or Settings.Value(entry.kind, "enabled"))
		for _, name in ipairs(entry.names) do
			local frame = _G[name]
			if hide then
				Safe.HideBlizzard(frame)
			elseif frame ~= nil then
				Safe.RestoreBlizzard(frame)
			end
			if frame == nil and not logged[name] then
				logged[name] = true
				K.DevTest.Log(Settings.MODULE, name .. " is missing on this client; nothing to hide")
			end
		end
	end
end

local hadTarget = false

function Blizzard.TargetSound()
	local had = hadTarget
	hadTarget = UnitExists("target") and true or false
	if hadTarget or not had or not Settings.Module().targetSounds or not (PlaySound and SOUNDKIT and SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT) then return end
	local frame = TargetFrame
	local loose = IsTargetLoose and IsTargetLoose()
	if frame and K.Safe.IsHidden(frame) and not (issecretvalue and issecretvalue(loose)) and loose ~= true then
		PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, nil, true)
	end
end
