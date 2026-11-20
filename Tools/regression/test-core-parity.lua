-- test-core-parity.lua: Layout controls, selected sharing and window rows preserve the v0.2.8 profile and apply through Options.
local O = dofile("Tools/regression/options_env.lua")
local saved = { version = 42, profiles = { Default = {
	Appearance = { typeSet = "Folio", font = "InterSemiBold", fontScale = 1.1, uiScaleAuto = false, uiScale = 0.8 },
	Layout = { grid = false, gridSize = 16, snap = true, snapDistance = 8, showCoordinates = false, preset = "DPS" },
	ProfileTools = { review = true, backups = true },
} }, layouts = { Default = { ["Parity.A"] = { anchor = "CENTER", x = 200, y = 50 } } } }
local env, K, ns = O.New({ saved = saved, before = function(e, k)
	for _, name in ipairs({ "Chat", "ActionBars", "Auras" }) do
		k.Modules.Register(O.W.CoreEnv.Module(name, { defaults = { sample = 1 } }))
	end
	for _, key in ipairs({ "Parity.A", "Parity.B" }) do
		local frame = e.CreateFrame("Frame", nil, k.Scale.Root())
		frame:SetSize(120, 40)
		k.Layout.Register(frame, key, { anchor = "CENTER", x = 200, y = 50 }, { resizable = true, scalable = true })
	end
end })
local Layout, Mode = K.Layout, K.Layout.Mode
assert(K.Appearance.Get("font") == "InterSemiBold" and K.Appearance.Get("uiScale") == 0.8, "v0.2.8 appearance survives")
assert(Layout.Get("Parity.A").x == 200 and not Layout.Get("Parity.A").matchHeight, "v0.2.8 position and size survive")
assert(Layout.Setting("gridAlpha") == 0.07 and Layout.Setting("nudgeStep") == 10 and Layout.Setting("overlap") == "alt", "absent controls preserve the old interaction")
assert(K.Store.Module("ProfileTools").scaleWarning, "import size warning defaults on without changing the HUD")
assert(Layout.Enter())
Mode.Select("Parity.A")
env.IsShiftKeyDown = function() return true end
local overlay, x = Mode.Overlay(), Layout.Get("Parity.A").x
local function key() overlay:GetScript("OnKeyDown")(overlay, "RIGHT") end
key()
assert(math.abs(Layout.Get("Parity.A").x - x - K.Scale.Pixel(10)) < 0.001, "default Shift nudge is still ten pixels")
K.Options.Write("Layout", "nudgeStep", 100)
x = Layout.Get("Parity.A").x
key()
assert(math.abs(Layout.Get("Parity.A").x - x - K.Scale.Pixel(100)) < 0.001, "chosen Shift distance applies")
env.IsShiftKeyDown = nil
x = Layout.Get("Parity.A").x
key()
assert(math.abs(Layout.Get("Parity.A").x - x - K.Scale.Pixel(1)) < 0.001, "missing modifier API leaves plain arrows usable")
env.IsShiftKeyDown = function() return env.Secret(true) end
x = Layout.Get("Parity.A").x
key()
assert(math.abs(Layout.Get("Parity.A").x - x - K.Scale.Pixel(1)) < 0.001, "secret modifier cannot be compared or change the nudge")
env.IsShiftKeyDown = nil
for name, fallback in pairs({ gridAlpha = 0.07, nudgeStep = 10, overlap = "alt" }) do
	local settings, previous = K.Store.Module("Layout"), K.Store.Module("Layout")[name]
	settings[name] = env.Secret(1)
	assert(Layout.Setting(name) == fallback, "secret saved control falls back: " .. name)
	settings[name] = previous
end
K.Options.Write("Layout", "grid", true)
K.Options.Write("Layout", "gridAlpha", 0.3)
local alpha = false
for _, region in ipairs(Mode.Grid()._regions) do
	if region._alpha == 0.3 then alpha = true end
end
assert(alpha, "grid brightness applies to drawn lines")
K.Options.Write("Layout", "gridAlpha", 0)
for _, region in ipairs(Mode.Grid()._regions) do assert(region._alpha ~= 0.3, "grid brightness can be turned off") end
assert(Layout.Update("Parity.A", { x = 200, y = 50 }))
local l, b, w, h = Layout.Rect("Parity.A")
local scale = K.Scale.Root():GetEffectiveScale()
env._cursor = { (l + w / 2 + K.Scale.Origin()) * scale, (b + h / 2) * scale }
local plate = Mode.Plate("Parity.A")
local function wheel() plate:GetScript("OnMouseWheel")(plate, 1) end
K.Options.Write("Layout", "overlap", "scroll")
wheel()
assert(Mode.Selected() == "Parity.B", "scroll selects the stacked mover")
for method, api in pairs({ alt = "IsAltKeyDown", shift = "IsShiftKeyDown", ctrl = "IsControlKeyDown" }) do
	K.Options.Write("Layout", "overlap", method)
	env[api] = function() return true end
	Mode.Select("Parity.A")
	wheel()
	assert(Mode.Selected() == "Parity.B", method .. " cycling applies")
	env[api] = nil
end
K.Options.Write("Layout", "overlap", "off")
Mode.Select("Parity.A")
wheel()
assert(Mode.Selected() == "Parity.A" and Layout.Get("Parity.A").scale > 1, "cycling off retains wheel scaling")
Layout.Exit(true)
local function items(page) return ns.Pages.Find(ns.Pages.List(), page).Items() end
local function row(page, label) return assert(O.Find(items(page), function(item) return item.label == label end), label) end
assert(K.Options.Open("Profiles"))
row("Profiles", "Share scope").set("modules")
assert(not row("Profiles", "Chat").get(), "selected modules start unchecked")
row("Profiles", "Chat").set(true)
row("Profiles", "Action Bars").set(true)
row("Profiles", "Include layout").set(false)
K.Options.Write("Chat", "sample", 2)
K.Options.Write("ActionBars", "sample", 3)
K.Options.Write("Auras", "sample", 4)
local text = assert(ns.Pages.ExportProfile())
K.Options.Write("Chat", "sample", 8)
K.Options.Write("ActionBars", "sample", 9)
K.Options.Write("Auras", "sample", 10)
local before = K.Store.Export()
local positions = K.Options.Copy(K.Store.Layout())
local review = assert(K.Profiles.Preview(text))
assert(K.Store.Export() == before and #review.changes == 2, "review is read only and names only selected modules")
assert(K.Store.Import(review.text))
assert(K.Options.Read("Chat", "sample") == 2 and K.Options.Read("ActionBars", "sample") == 3 and K.Options.Read("Auras", "sample") == 10, "only selected settings apply")
assert(K.Options.Equal(K.Store.Layout(), positions), "no-layout bundle preserves positions")
local selected = { Chat = true, ActionBars = true }
text = assert(K.Profiles.Export(selected, true))
Layout.Set("Parity.A", "x", 300)
assert(K.Store.Import(assert(K.Profiles.Preview(text)).text))
assert(K.Options.Equal(K.Store.Layout(), positions), "included layout applies")
assert(not K.Profiles.Export({}, false) and not K.Profiles.Export({ Unknown = true }, false), "empty and unknown selections are rejected")
assert(not K.Profiles.Preview(text, { Auras = true }), "cannot invent a module absent from a bundle")
local single = assert(K.Profiles.Export("Chat"))
assert(K.Profiles.Preview(single, { Chat = true }, true), "selected import accepts the existing single-module format")
assert(not K.Profiles.Preview(single, { Auras = true }), "single-module format cannot import an unshared module")
local settings = assert(K.Profiles.Export("everything", false))
assert(K.Profiles.Preview(settings, { Chat = true }, true), "selected import accepts the existing settings-only format")
K.Options.Write("Appearance", "uiScale", 0.9)
local appearance = assert(K.Profiles.Export("Appearance"))
K.Options.Write("Appearance", "uiScale", 0.8)
assert(K.Profiles.Preview(appearance).warning, "changed imported size is explained")
K.Options.Write("ProfileTools", "scaleWarning", false)
assert(not K.Profiles.Preview(appearance).warning, "size warning can be switched off")
K.Options.Write("ProfileTools", "scaleWarning", true)
assert(not K.Profiles.Preview(text).warning, "unselected appearance produces no size warning")
row("Profiles", "Selected modules").buttons[1].onClick()
assert(row("Profiles", "Appearance").get() and row("Profiles", "Auras").get(), "Select all includes appearance and registered modules")
row("Profiles", "Selected modules").buttons[2].onClick()
assert(not row("Profiles", "Appearance").get() and not row("Profiles", "Auras").get(), "Clear leaves no selected module")
local warn = row("Profiles", "Warn about imported interface size")
warn.set(false)
assert(not warn.get() and not K.Profiles.Preview(appearance).warning, "warning row writes and applies")
assert(K.Options.Open("General"))
local width = row("General", "Width")
assert(width.element == "Options.Window" and width.defer, "window uses the existing deferred element rows")
width.set(1200)
assert(Layout.Get("Options.Window").width == 1200, "General window width applies")
row("General", "Height").set(760)
row("General", "Scale").set(0.9)
assert(Layout.Get("Options.Window").height == 760 and Layout.Get("Options.Window").scale == 0.9, "General window height and scale apply")
row("General", "Opacity in combat").set(0.75)
row("General", "Opacity out of combat").set(0.5)
assert(Layout.Get("Options.Window").alphaIdle == 0.5 and Layout.Get("Options.Window").alphaCombat == 0.75, "General window opacities apply")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("core parity ok: v0.2.8 defaults, layout controls, selected sharing, import warning and window rows")
