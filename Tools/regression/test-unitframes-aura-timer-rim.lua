-- test-unitframes-aura-timer-rim.lua: on Medallions the player's and target's aura rows grow up from their host, so each timer under a bottom-row icon must stay inside the host, clear of the portrait rim and the slab, at the four owner screens.
local Reach = dofile("Tools/regression/hud_reach_lib.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function overlaps(a, b)
	return a.left < b.right and b.left < a.right and a.bottom < b.top and b.bottom < a.top
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env = Reach.New(screen[1], screen[2], "medallions", "DPS")
	Reach.Populate(env)
	local root = env.KstyleUI.Scale.Root()
	local function rect(region)
		return assert(Geometry.Rect(region, root))
	end
	for _, kind in ipairs({ "player", "target" }) do
		local view = env._addons.KstyleUI_UnitFrames.Frames.Get(kind).views[1]
		assert(view.auras or kind == "player", "the target shows its aura row")
		if view.auras then
		local rim, slab = rect(view.medallion), rect(view.button)
		local buttons = view.auras.container._groups[kind == "player" and "buffs" or "debuffs"].active
		assert(#buttons > 0, kind .. ": the fixture shows auras")
		for i, button in ipairs(buttons) do
			local text = button._aura.timer
			text:SetSize(text:GetStringWidth(), text:GetStringHeight())
			local timer = rect(text)
			local label = string.format("%dx%d %s aura %d timer (bottom %.1f)", screen[1], screen[2], kind, i, timer.bottom)
			assert(not overlaps(timer, rim), label .. " overlaps the portrait rim (top " .. rim.top .. "): place the row's container above its timer lane inside the host (Auras.lua Flow)")
			assert(not overlaps(timer, slab), label .. " overlaps the slab (top " .. slab.top .. ")")
		end
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("ok Medallions aura timers clear the portrait rim and slab")
