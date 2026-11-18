-- composed_rails.lua: quest, guide, meter and data strip in one environment, so their docking is exercised together.
local Common = dofile("Tools/render/scenes/_common.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local M = dofile("Tools/regression/meters_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

return Common.Run(function()
	local R = Boot(Common.SCREEN)
	local env, K = R.env, R.K
	M.Game(env, {})
	D.Game(env, { fps = 162, latencyHome = 15, latencyWorld = 15, money = 2616, faction = false, level = 60 })
	D.Blizzard(env)
	D.Menus(env, { backpack = 133633 })
	Load(D.Files(), env)
	Load(M.Files(), env)
	local style = (os.getenv("RENDER_HUD_STYLE") or "Medallions"):lower()
	K.Options.Write("HudStyle", "style", style)
	K.Modules.Enable("DataBars")
	K.Modules.Enable("Meters")
	K.Options.Write("Meters", "threat.shown", true)
	R.settle()
	R.rxp.activeItemFrame.buttonList[1].icon:SetTexture(132794)
	R.rxp.targeting.activeTargetFrame.enemyTargetButtons[1].icon:SetTexture(136188)
	local meters = env._addons.KstyleUI_Meters
	local list = meters.Damage.list
	list:SetTitleSwitch("Damage", "Healing", 1)
	for i, row in ipairs({ { "Lightning Bolt", 412 }, { "Flame Shock", 188 }, { "Earth Shock", 134 } }) do
		list:SetRow(i, row[1], "SHAMAN", "friendly", row[2], 412, tostring(row[2]), "20%")
	end
	list:Finish(3)
	local scene = Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(env, K)
	if err then scene.log[#scene.log + 1] = err end
	return scene
end)
