-- test-render-databar-clock.lua: the independently rendered minimap sees the data bar's real module defaults and yields its clock.
local D = dofile("Tools/regression/databars_env.lua")
local _, K = D.New({ enable = false })
for style, list in pairs({ Medallions = "dockModules", Frames = "modules" }) do
	rawset(_G, "RENDER_HUD_STYLE", style)
	for _, screen in ipairs({ "1920x1080", "2560x1440", "5120x1440", "3840x2160" }) do
		rawset(_G, "RENDER_SCREEN", screen)
		local Hud = dofile("Tools/render/scenes/hud.lua")
		local settings = D.CoreEnv.DeepCopy(K.Store.Defaults("DataBars"))
		settings.enabled = true
		local _, minimap = Hud.Module("minimap", { dataBar = settings })
		assert(not minimap.Map.face.clock:IsShown(), "render: register the separately drawn DataBars module so the minimap yields its clock at " .. screen .. " in " .. style)
		for _, entry in ipairs(settings.strip[list]) do if entry.id == "time" then entry.shown = false end end
		local _, withoutClock = Hud.Module("minimap", { dataBar = settings })
		assert(withoutClock.Map.face.clock:IsShown(), "render: the minimap clock returns when the bar clock is off in " .. style)
	end
end
rawset(_G, "RENDER_SCREEN", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)
print("render databar clock ok: one clock at all four screens in Medallions and Frames")
