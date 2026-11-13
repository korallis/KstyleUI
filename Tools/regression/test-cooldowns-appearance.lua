-- test-cooldowns-appearance.lua: reference sizes and timer placement survive restyles without reading engine visibility or cooldown values.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local env, K, ns = C.New({ setup = C.Game })
C.Enable(env, K)
local essential = ns.Mirror.Row("essential")
local icon = essential.icons[1]
local function appearance()
	assert(icon.opts.size == 36.7 and ns.Settings.current.essential.spacing == 4.6, "the essential row keeps the measured size and pitch")
	local p = icon.countdown._points[1]
	local half = K.Widgets.Border(icon) / 2 + 1e-6
	assert(p[1] == "CENTER" and p[2] == icon and p[3] == "CENTER" and math.abs(p[4]) <= half and math.abs(p[5] + K.Widgets.Snap(icon, 1)) <= half, "the essential timer is optically centred, not raised for a charge band")
	local _, size = icon.countdown:GetFont()
	assert(size == K.Widgets.FontSize(icon.countdown, 16.5), "the number role's bold face uses the picture's smaller size")
	assert(W.LastCall(icon.cooldown, "SetCountdownFormatter")[1] == nil, "the engine draws native unitless seconds, never Lua string operations on secrets")
	local c = icon.count._points[1]
	assert(c[1] == "BOTTOMRIGHT" and c[3] == "BOTTOMRIGHT", "charges remain in the bottom right")
	assert(icon.chrome.shadowOn == false and icon.procGlow == nil, "there is no socket shadow or proc halo")
	assert(not icon.readyGlow:IsPlaying(), "ready spells have no default halo")
	local er, eg, eb, ea = K.Widgets.Rgba("slotRim")
	local edge = icon.chrome.edge
	assert(W.Near(edge[1], er) and W.Near(edge[2], eg) and W.Near(edge[3], eb) and W.Near(edge[4], ea), "quiet mode rests on the slot's lit rim, not the class colour")
end
appearance()
ns.Style.SetProc(icon, true)
local r, g, b = K.Tokens.Color("giltLit")
assert(icon.chrome.proc == true, "the proc rim is delegated to shared chrome, not redrawn locally")
if icon.chrome.line then
	assert(W.SameRGB(icon.chrome.line[1], r, g, b), "the shared chrome draws the gold outer proc rim")
end
icon:Restyle()
appearance()
K.Callbacks.Fire("ScaleChanged")
appearance()
ns.Style.SetProc(icon, false)
appearance()
K.Options.Write("Cooldowns", "accent", "custom")
K.Options.Write("Cooldowns", "accentColor", { r = 1, g = 0, b = 0 })
assert(icon.accent and icon.accent[1] == 1 and icon.accent[2] == 0, "the custom accent option remains available")
K.Options.Write("Cooldowns", "accent", "class")
assert(icon.accent == nil, "the class accent option remains available")
K.Options.Write("Cooldowns", "accent", "quiet")
appearance()

local cfg = ns.Settings.current.buffs
local buffs = ns.Row.New(K.Scale.Root(), "buffs", cfg)
buffs:SetCount(2)
assert(cfg.size == 27.6 and cfg.spacing == 3.4 and ns.Grid.Capacity(cfg) == 6, "buffs keep six slots at the measured 27.6 size")
local x1 = ns.Grid.Offset(1, 2, cfg)
local x2 = ns.Grid.Offset(2, 2, cfg)
local width = ns.Grid.Size(cfg)
assert(math.abs(x2 + cfg.size - width) < 1e-6 and math.abs(x2 - x1 - 31) < 1e-6, "a short row ends at the right edge in configured left-to-right order")
buffs.icons[1].countdown:SetText("8s")
buffs.icons[2].countdown:SetText("14s")
assert(buffs.icons[1]._points[1][4] < buffs.icons[2]._points[1][4], "configured 8s remains left of 14s without sorting by duration")
local function below(button)
	local p = button.countdown._points[1]
	assert(p[1] == "TOP" and p[3] == "BOTTOM" and p[5] < 0, "tracked buff timers are below the icon")
	assert(button.countdown:GetFont() == K.Tokens.Font("timer"), "the kit's tracked timers use the timer role, the medium that fits the picture")
end
below(buffs.icons[1])
buffs.icons[1]:Restyle()
below(buffs.icons[1])

local engine = env._viewers.BuffIconCooldownViewer._items[1]
local function forbidden()
	error("an engine region's visibility is secret")
end
engine.Icon.IsShown, engine.Icon.IsVisible = forbidden, forbidden
engine.Applications.Applications.IsShown = forbidden
engine.Cooldown:GetCountdownFontString().IsShown = forbidden
ns.Reskin.Refresh()
below({ countdown = engine.Cooldown:GetCountdownFontString() })
assert(K.Skin.Parts(engine).backdrop.inset == 0, "the reskin does not enlarge the engine's square icon footprint")

local utility = env._viewers.UtilityCooldownViewer._items[1].Cooldown:GetCountdownFontString()
local utilityRow = ns.Row.New(K.Scale.Root(), "utility", ns.Settings.current.utility)
utilityRow:SetCount(1)
assert(utilityRow.icons[1].countdown:GetFont() == K.Tokens.Font("timer"), "the utility timers read in the timer role")
assert(engine.Cooldown:GetCountdownFontString():GetFont() == K.Tokens.Font("timer") and icon.countdown:GetFont() == K.Tokens.Font("number"), "tracked timers take the medium, the essential row keeps the number role")
assert(#W.Calls(utility, "ClearAllPoints") == 0 and #W.Calls(utility, "SetPoint") == 0, "the reskin leaves utility countdown anchors to the engine")

local Geometry = dofile("Tools/regression/geometry.lua")
for _, wrap in ipairs({ "up", "down" }) do
	for _, timer in ipairs({ true, false }) do
		K.Options.Write("Cooldowns", "buffs.columns", 2)
		K.Options.Write("Cooldowns", "buffs.rows", 3)
		K.Options.Write("Cooldowns", "buffs.wrap", wrap)
		K.Options.Write("Cooldowns", "buffs.timer", timer)
		local grid = ns.Settings.current.buffs
		local row = ns.Row.New(K.Scale.Root(), "buffs", grid)
		row.holder:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 0, 0)
		row:SetCount(7)
		local band = timer and grid.timerSize + 4 or 0
		assert(grid.cellHeight == grid.size + band, "each buff cell reserves its own timer band")
		local _, height = ns.Grid.Size(grid)
		assert(math.abs(height - (3 * (grid.size + band) + 2 * grid.spacing)) < 1e-6, "the holder includes every row's timer band")
		local visual = {}
		for i = 1, 6, 2 do
			visual[#visual + 1] = assert(Geometry.Rect(row.icons[i], K.Scale.Root()))
		end
		table.sort(visual, function(first, second) return first.top > second.top end)
		for i = 1, 2 do
			assert(visual[i].bottom - band > visual[i + 1].top, "each timer band clears the next row in either wrap direction")
		end
		local chip = assert(Geometry.Rect(row.chip, K.Scale.Root()))
		local beside = visual[wrap == "up" and 1 or 3]
		assert(math.abs(chip.top - beside.top) < 1e-6 and math.abs(chip.bottom - beside.bottom) < 1e-6, "the overflow chip aligns with icons, not the timer band")
	end
end

local chosen = K.Tokens.FontPath("SourceSans3Regular")
K.Options.Write("Cooldowns", "timerFont", chosen)
K.Options.Write("Cooldowns", "timerOutline", "OUTLINE")
K.Options.Write("Cooldowns", "buffs.timerSize", 14)
local customRow = ns.Row.New(K.Scale.Root(), "buffs", ns.Settings.current.buffs)
customRow:SetCount(1)
ns.Reskin.Refresh()
for _, text in ipairs({ customRow.icons[1].countdown, engine.Cooldown:GetCountdownFontString() }) do
	local path, size, flags = text:GetFont()
	assert(path == chosen and flags == "OUTLINE", "an explicit font and outline override the lighter kit role in both paths")
	assert(W.Near(size, K.Widgets.FontSize(text, 14)), "the chosen buff timer size is retained")
end
print("cooldowns appearance ok")
