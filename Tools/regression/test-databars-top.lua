-- test-databars-top.lua: the top bar's zones, saved placement, inset, fit matrix, migration and shared clock.
local D = dofile("Tools/regression/databars_env.lua")
local M = dofile("Tools/regression/minimap_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

local function near(a, b, pixel)
	assert(math.abs(a - b) <= (pixel or 0.001), tostring(a) .. " differs from " .. tostring(b))
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = M.Blizzard })
	local Layout, Layouts = K.Layout, K.Setup.Layouts
	local view = ns.Strip.view
	assert(view.zones.left and view.zones.centre and view.zones.right)
	assert(view.topBar and view.lineMode)
	assert(table.concat(ns.Strip.order, ",") == "fps,latency,gold,durability,time", "all five readouts default to the right zone")
	near(Layout.Get("databars.strip").width, Layout.RootSize())
	assert(view.items.fps.button._points[1][2] == view.zones.right)
	local Scene = dofile("Tools/render/scene.lua")
	for _, id in ipairs(ns.Strip.order) do
		local x, y, w, h = Scene.Rect(env, view.items[id].button)
		assert(x and y and w > 0 and h > 0, "the zone anchor must resolve the " .. id .. " text rectangle")
	end
	for _, artwork in ipairs({ "forged", "plain" }) do
		K.Options.Write("DataBars", "strip.artwork", artwork)
		assert((view.chrome:Material() ~= nil) == (artwork == "forged"))
		assert(view.chrome.visible)
		for _, texture in ipairs(view.art) do assert(texture:IsShown() == (artwork == "forged")) end
		near(view.art[1]:GetWidth(), K.Widgets.Snap(view.art[1], 18), K.Scale.Pixel(1))
	end
	K.Options.Write("DataBars", "strip.artwork", "forged")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 500)
	local preview = ns.Preview(parent).strip
	near(preview.frame:GetHeight(), 20)
	local _, _, _, x, y = preview.card:GetPoint()
	near(x, 0)
	near(y, 0)
	assert(table.concat(ns.Strip.Order({ slot1 = "fps", slot2 = "latency", slot3 = "gold", slot4 = "durability", slot5 = "time" }), ",") == "fps,latency,gold,durability,time")
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(100, 40)
	Layout.Register(frame, "minimap.main", { anchor = "TOPRIGHT", x = -17, y = -40 })
	assert(Layout.Update("minimap.main", { anchor = "TOPRIGHT", x = -33, y = -55 }))
	local function inset(want)
		near(Layouts.TopInset(), want)
		local _, _, _, _, drawnY = frame:GetPoint()
		near(drawnY, K.Scale.Snap(-55 - want), K.Scale.Pixel(1))
		local _, bottom, _, h = Layout.Rect("minimap.main")
		local rw, rh = Layout.RootSize()
		local _, guardBottom = Layouts.Rect({ key = "minimap.main", width = 100, height = 40 }, Layout.Get("minimap.main"), rw, rh)
		near(bottom, guardBottom, K.Scale.Pixel(1))
		near(bottom + h, rh - 55 - want, K.Scale.Pixel(1))
	end
	inset(10)
	local left, bottom, width, height = Layout.Rect("databars.strip")
	local rw, rh = Layout.RootSize()
	local anchor, barX, barY = Layout.Geometry.Position(left, bottom, width, height, rw, rh)
	assert(Layout.Update("databars.strip", { anchor = anchor, x = barX, y = barY }))
	inset(10)
	local signature = Layouts.ActionBarSignature()
	assert(Layout.Update("databars.strip", { anchor = "BOTTOM", x = 0, y = 80 }))
	inset(0)
	assert(signature ~= Layouts.ActionBarSignature(), "both scale caches include the bar placement")
	assert(Layout.Get("databars.strip").y == 80, "Layout honours the player's saved bar placement")
	assert(Layout.Update("databars.strip", { anchor = "TOP", x = 0, y = 0 }))
	inset(10)
	K.Options.Write("DataBars", "strip.height", 32)
	inset(22)
	K.Options.Write("DataBars", "strip.height", 12)
	inset(2)
	K.Options.Write("DataBars", "strip.enabled", false)
	inset(0)
	assert(not view.frame:IsShown())
	K.Options.Write("DataBars", "strip.enabled", true)
	inset(2)
	K.Options.Write("DataBars", "strip.placement", "rail")
	inset(0)
	assert(not view.topBar)
	K.Options.Write("DataBars", "strip.placement", "top")
	K.Options.Write("DataBars", "strip.height", 20)
	K.Options.Write("HudStyle", "style", "medallions")
	assert(not view.topBar and Layout.Get("databars.strip").anchor == "BOTTOMRIGHT", "Medallions retains the rail")
	near(Layouts.TopInset(), 0)
	K.Options.Write("HudStyle", "style", "frames")
	assert(view.topBar and Layout.Get("databars.strip").anchor == "TOP")
	inset(10)
	local saved = D.CoreEnv.DeepCopy(env.KstyleUIDB)
	saved.layouts.Default = saved.layouts.Default or {}
	saved.layouts.Default["databars.strip"] = { anchor = "BOTTOM", x = 0, y = 80 }
	local _, reloaded = D.New({ width = screen[1], height = screen[2], saved = saved })
	assert(reloaded.Layout.Get("databars.strip").anchor == "BOTTOM" and reloaded.Layout.Get("databars.strip").y == 80, "a saved moved bar survives login")
	near(reloaded.Setup.Layouts.TopInset(), 0)
	Load(M.Files(), env)
	K.Modules.Enable("Minimap")
	local clock = env._addons.KstyleUI_Minimap.Map.face.clock
	assert(not clock:IsShown(), "the default bar clock hides the minimap clock")
	local row = K.Options.Row("Minimap", "clock.shown")
	assert(row.disableWhen() and not row.shown(true))
	assert(row.help == "Hidden while the data bar shows the clock.")
	local O = dofile("Tools/regression/options_env.lua")
	Load(O.Files(), env)
	local options = env._addons.KstyleUI_Options
	local items = options.Model.SchemaItems("Minimap", { row }, "Minimap")
	local list = env.CreateFrame("Frame", nil, K.Scale.Root())
	list:SetSize(700, 300)
	list.view = list
	list.GetViewWidth = function() return 700 end
	local clockRow = options.Rows.Create(list)
	clockRow:SetSize(700, 48)
	options.Rows.Update(clockRow, items[1], nil, list)
	assert(not clockRow.controls.toggle:GetValue() and not clockRow.controls.toggle:IsEnabled(), "the hidden minimap clock paints OFF and disabled")
	K.Options.Write("DataBars", "strip.slot5", "time")
	assert(not clock:IsShown(), "the minimap foot yields to the bar's clock")
	K.Options.Write("DataBars", "strip.enabled", false)
	assert(clock:IsShown(), "turning the bar off returns the minimap clock")
	options.Rows.Update(clockRow, items[1], nil, list)
	assert(clockRow.controls.toggle:GetValue() and clockRow.controls.toggle:IsEnabled(), "the minimap clock row restores its saved value when the bar is off")
	K.Options.Write("DataBars", "strip.enabled", true)
	assert(not clock:IsShown())
	K.Options.Write("DataBars", "strip.slot5", "none")
	assert(clock:IsShown(), "turning only the bar's clock off returns the minimap clock")
	K.Options.Write("DataBars", "strip.slot5", "time")
	K.Modules.Disable("DataBars")
	assert(clock:IsShown(), "disabling DataBars also returns the minimap clock")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = D.New({ width = 1920, height = 1080, size = "auto", setup = function(e)
		e._physical = { 1920, 1080 }
		e.GetPhysicalScreenSize = function() return e._physical[1], e._physical[2] end
	end })
	for _, screen in ipairs({ { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 1920, 1080 } }) do
		env._physical = screen
		env.FireEvent("DISPLAY_SIZE_CHANGED")
		env.RunTimers()
		near(K.Layout.Get("databars.strip").width, K.Layout.RootSize())
	end
end

do
	local env, K = D.New({ enable = false, saved = { version = 40, profiles = { Default = { DataBars = { enabled = false, strip = { enabled = false, placement = "rail" } } } } } })
	assert(not K.Store.Module("DataBars").enabled and K.Store.Module("DataBars").strip.enabled)
	assert(K.Store.Module("DataBars").strip.placement == "top")
	assert(env.KstyleUIDB.version == K.Store.DB_VERSION)
	local data = { profiles = { Default = {} }, layouts = { Default = { ["databars.strip"] = { anchor = "BOTTOM", x = 37, y = 80, width = 500, height = 22 } } } }
	K.Store.migrations[K.Store.DB_VERSION](data)
	assert(data.layouts.Default["databars.strip"] == nil, "migration resets the old rail geometry to the top bar")
	assert(data.layouts.Default["medallions:databars.strip"].x == 37, "the Medallions rail keeps its saved position")
end

do
	local env, K = D.New({ fit = true })
	local Layouts, Scale = K.Setup.Layouts, K.Scale
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		for _, arrangement in ipairs({ "centred", "spread" }) do
			K.Options.Write("Layout", "arrangement", arrangement)
			local width, height = Scale.CanvasWidth(screen[1], screen[2]), screen[2]
			for _, style in ipairs({ "frames", "orbs", "medallions" }) do
				for _, preset in ipairs(Layouts.Names()) do
					local on = Layouts.Enabled(preset)
					on["meters.damage"], on["meters.threat"] = preset ~= "Tank", preset == "Tank"
					local cap, fits = Layouts.ScaleLimit(width, height, preset, on, style)
					local scale = Scale.Auto(height, cap, fits)
					assert(fits(scale), table.concat({ style, preset, screen[1], height, arrangement }, " "))
					assert(Layouts.Fits(preset, width, height, scale, on, nil, style))
					local positions = Layouts.Positions(preset, style, Scale.AspectClass(width, height))
					positions["minimap.main"] = { anchor = "TOPRIGHT", x = -20, y = -38 }
					assert(Layouts.Fits(preset, width, height, scale, on, positions, style), "saved top anchors use the same inset in Fits")
					positions["databars.strip"] = { anchor = "BOTTOM", x = 0, y = 500, width = 100, height = 20 }
					near(Layouts.TopInset(style, on, positions["databars.strip"]), 0)
				end
			end
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("databars top ok: saved placements, inset, clock, migration and all styles/layouts/screens")
