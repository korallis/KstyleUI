-- minimap_icons.lua: druid map pins, tracking and an open addon drawer; RENDER_COMPACT_ICONS=1 shows the previous compact sizing.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local M = dofile("Tools/regression/minimap_env.lua")
local I = Hud.ICONS

return Common.Run(function()
	local pins = {}
	local env, K, ns = M.New(Common.ScreenOpts({
		enabled = true, zone = "Riverglades",
		settings = { compactIcons = os.getenv("RENDER_COMPACT_ICONS") == "1" },
		setup = function(e)
			Common.ForceScreen(e)
			e.UnitClass = function() return "Druid", "DRUID", 11 end
			e.RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
			local lib = M.FakeLibDBIcon(e)
			for index, icon in ipairs({ I.sunderArmor, I.whirlwind, I.charge, I.battleShout, I.bloodrage, I.shieldBlock }) do
				local button = lib:Add("Addon" .. index)
				button.icon:SetTexture(icon)
				button.icon:SetSize(17, 17)
				button.icon:SetPoint("CENTER", button, "CENTER")
			end
			for index, icon in ipairs({ I.charge, I.battleShout, I.shieldBlock }) do
				local pin = e.CreateFrame("Frame", nil, e.Minimap)
				pin:SetSize(16, 16)
				pins[index] = pin
				local art = pin:CreateTexture(nil, "ARTWORK")
				art:SetTexture(icon)
				art:SetAllPoints(pin)
			end
		end,
	}))
	M.Settle(env)
	for index, pin in ipairs(pins) do
		pin:SetPoint("CENTER", env.Minimap, "CENTER", (index - 2.5) * env.Minimap:GetWidth() * 0.2, 0)
	end
	local _, note = Hud.Terrain(env)
	env.Minimap:GetScript("OnEnter")(env.Minimap)
	M.W.Click(ns.Map.column.buttons.drawer)
	M.Settle(env)
	assert(ns.Map.drawer.panel:IsShown(), "open the drawer through its button")
	local scene = Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
	scene.log[#scene.log + 1] = note
	assert(not Common.Errors(env, K), Common.Errors(env, K))
	return scene
end)
