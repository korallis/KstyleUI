-- EffectBursts.lua: the Medallions class-motif burst behind the player's medallion on a level-up.
local _, ns = ...

local Effects = ns.Effects

local OWNER = "EffectBursts"

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

ns.Events.Register(OWNER, "PLAYER_LEVEL_UP", function()
	local medallion = Effects.playerMedallion
	if not medallion then
		return
	end
	local _, class = UnitClass("player")
	medallion:Burst(not IsSecret(class) and class or nil)
end)
