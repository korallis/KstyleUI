-- Loot.lua: faster auto loot, which takes every unlocked slot at once when the game itself auto loots, so the loot window never waits on its item-by-item pace.
local _, ns = ...

local THROTTLE = 0.3
local AUTO_LOOT_CVAR = "autoLootDefault"
local AUTO_LOOT_KEY = "AUTOLOOTTOGGLE"

local lastPass

local function AutoLoot(autoloot)
	if not ns.IsSecret(autoloot) and type(autoloot) == "boolean" then
		return autoloot
	end
	return ns.True(GetCVarBool(AUTO_LOOT_CVAR)) ~= ns.True(IsModifiedClick(AUTO_LOOT_KEY))
end

local function OnReady(_, autoloot)
	if not ns.Get("fastLoot") or not AutoLoot(autoloot) then
		return
	end
	local now = GetTime()
	if lastPass and now - lastPass < THROTTLE then
		return
	end
	lastPass = now
	for slot = ns.Number(GetNumLootItems()) or 0, 1, -1 do
		local locked = select(6, GetLootSlotInfo(slot))
		if not ns.IsSecret(locked) and locked ~= true then
			LootSlot(slot)
		end
	end
end

ns.AddPart({
	name = "loot",
	events = { LOOT_READY = OnReady },
	Stop = function()
		lastPass = nil
	end,
})
