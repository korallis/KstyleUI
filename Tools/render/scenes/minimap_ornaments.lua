-- minimap_ornaments.lua: the minimap face on the whole screen in the state RENDER_STATE names, for the ornament before and after pairs: rest (the face alone), hover (the pointer over the map, its button column showing) and open (the addon drawer opened from the column with six LibDBIcon buttons). The default is open.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local I = Hud.ICONS

local ADDONS = {
	{ "Bagnon", I.sunderArmor },
	{ "Details", I.whirlwind },
	{ "Questie", I.charge },
	{ "RestedXP", I.battleShout },
	{ "WeakAuras", I.bloodrage },
	{ "Pawn", I.shieldBlock },
}
local LIB_ICON = 17

return Common.Run(function()
	local state = os.getenv("RENDER_STATE") or "open"
	assert(state == "rest" or state == "hover" or state == "open", "RENDER_STATE must be rest, hover or open, not " .. state)
	local M = dofile("Tools/regression/minimap_env.lua")
	local lib
	local env, K, ns = M.New({
		enabled = true,
		zone = "Riverglades",
		setup = function(env)
			Common.ForceScreen(env)
			env._clock = { hour = 14, minute = 32, realmHour = 9, realmMinute = 5 }
			lib = M.FakeLibDBIcon(env)
			for _, addon in ipairs(ADDONS) do
				local button = lib:Add(addon[1])
				button.icon:SetTexture(addon[2])
				button.icon:SetSize(LIB_ICON, LIB_ICON)
				button.icon:SetPoint("CENTER", button, "CENTER")
			end
		end,
	})
	M.Settle(env)
	local _, note = Hud.Terrain(env)
	if state ~= "rest" then
		ns.Map.holder._mouseOver = true
		env.Minimap:GetScript("OnEnter")(env.Minimap)
		M.Settle(env)
	end
	if state == "open" then
		M.W.Click(ns.Map.column.buttons.drawer)
		M.Settle(env)
		assert(ns.Map.drawer.panel:IsShown(), "the drawer is open")
	end
	local scene = Common.Scene.Build(env)
	scene.log[#scene.log + 1] = note
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "minimap_ornaments error: " .. err
	end
	return scene
end)
