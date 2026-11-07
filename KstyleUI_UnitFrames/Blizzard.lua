-- Blizzard.lua: hides Blizzard's player, target, focus, pet and boss frames through KstyleUI.Safe while KstyleUI's own frames replace them.
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
}
Blizzard.FRAMES = FRAMES

local logged = {}

function Blizzard.Apply(active)
	local Safe = K.Safe
	local hideAll = active and Settings.Module().hideBlizzard == true
	for _, entry in ipairs(FRAMES) do
		local hide = hideAll and Settings.Value(entry.kind, entry.setting or "enabled")
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
