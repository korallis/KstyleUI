-- test-core-parity-followup.lua: lazy mover shortcuts, session hiding, named imports, native fonts and page search preserve defaults and upgrade safety.
local O = dofile("Tools/regression/options_env.lua")
local env, K, ns = O.New({ saved = { version = 42, profiles = { Default = {
	Appearance = { font = "InterSemiBold", uiScaleAuto = false, uiScale = 0.8 },
} }, layouts = { Default = {} } }, before = function(e, k)
	k.Modules.Register(O.W.CoreEnv.Module("Chat", { defaults = { sample = 1 } }))
	k.Modules.Enable("Chat")
	local frame = e.CreateFrame("Frame", nil, k.Scale.Root())
	frame:SetSize(120, 40)
	k.Layout.Register(frame, "Parity.Chat", { anchor = "CENTER", x = 300, y = 50 }, { module = "Chat", label = "Chat mover", scalable = true })
end })
local Layout, Mode = K.Layout, K.Layout.Mode
local function row(page, label)
	return assert(O.Find(ns.Pages.Find(ns.Pages.List(), page).Items(), function(item) return item.label == label end), label)
end
assert(K.Appearance.Get("font") == "InterSemiBold" and K.Appearance.Get("uiScale") == 0.8, "v0.2.8 appearance is unchanged")
assert(not K.Store.Account().moverOptions and not K.Store.Account().optionsSearchPage, "new conveniences default off")
local attach, tooltip = K.Widgets.AttachTooltip
K.Widgets.AttachTooltip = function(frame, builder)
	if frame.key == "Parity.Chat" then tooltip = builder end
	return attach(frame, builder)
end
assert(Layout.Enter())
K.Widgets.AttachTooltip = attach
local plate = assert(Mode.Plate("Parity.Chat"))
plate:GetScript("OnDoubleClick")(plate, "LeftButton")
assert(Layout.IsActive(), "double-click keeps the old behaviour by default")
local tip = { lines = {}, AddTitle = function() end, AddCaption = function() end }
function tip:AddLine(text) self.lines[#self.lines + 1] = text end
tooltip(tip, plate)
assert(table.concat(tip.lines, "\n"):find("Alt + scroll", 1, true), "default mover tooltip names the actual overlap shortcut")
Mode.Refresh()
local saved = K.Options.Copy(K.Store.Layout())
env.IsShiftKeyDown = function() return true end
plate:GetScript("OnClick")(plate, "RightButton")
assert(not plate:IsShown() and Mode.Toolbar().restore:IsShown(), "Shift right-click hides only the mover and reveals Restore")
assert(K.Options.Equal(saved, K.Store.Layout()), "hiding never changes positions or element visibility")
Mode.Refresh()
assert(not plate:IsShown(), "refresh keeps session-hidden movers hidden")
O.W.Click(Mode.Toolbar().restore)
assert(plate:IsShown() and not Mode.Toolbar().restore:IsShown(), "Restore shows the mover")
plate:GetScript("OnClick")(plate, "RightButton")
Layout.Exit(true)
assert(Layout.Enter() and plate:IsShown(), "reopening Layout Mode restores hidden movers")
env.IsShiftKeyDown = nil
row("Elements", "Double-click movers for settings").set(true)
assert(K.Store.Account().moverOptions, "mover shortcut writes")
env._combat = true
plate:GetScript("OnDoubleClick")(plate, "LeftButton")
assert(Layout.IsActive(), "shortcut cannot open settings or alter secure frames in combat")
env._combat = false
plate:GetScript("OnDoubleClick")(plate, "LeftButton")
assert(not Layout.IsActive() and ns.Window.State().page == "Chat", "shortcut applies and opens the mover's module")
row("Elements", "Double-click movers for settings").set(false)
assert(Layout.Enter())
plate:GetScript("OnDoubleClick")(plate, "LeftButton")
assert(Layout.IsActive(), "shortcut can be disabled")
Layout.Exit(true)
assert(K.Options.Open("General"))
local searchOnly = row("General", "Search current page only")
searchOnly.set(true)
local search = ns.Window.Parts().search
search:SetText("profile")
search:GetScript("OnTextChanged")(search, true)
env.RunTimers()
for _, item in ipairs(ns.Window.State().items) do assert(item.page == nil or item.page == "General", "page search cannot leak other pages") end
searchOnly.set(false)
env.RunTimers()
assert(O.Find(ns.Window.State().items, function(item) return item.page == "Profiles" end), "turning page search off restores global results")
K.Options.Open("General")
Layout.Update("Options.Window", { anchor = "TOPLEFT", x = 140, y = -90, width = 1200, height = 760, scale = 0.9, alphaCombat = 0.75, alphaIdle = 0.5 })
for _, label in ipairs({ "Width", "Height", "Scale", "Opacity in combat", "Opacity out of combat" }) do
	assert(row("General", label).help:lower():find("settings window", 1, true), "window help describes its control: " .. label)
end
row("General", "Reset window size and opacity").buttons[1].onClick()
local position = Layout.Get("Options.Window")
assert(position.anchor == "TOPLEFT" and position.x == 140 and position.y == -90, "window reset keeps its position")
assert(position.width == 1040 and position.height == 680 and position.scale == 1 and position.alphaCombat == 1 and position.alphaIdle == 1, "window reset restores dimensions and opacity")
local native = { GameFontNormal = "Fonts\\FRIZQT__.TTF", ChatFontNormal = "Fonts\\ARIALN.TTF", SystemFont_Med1 = "Fonts\\FRIZQT___CYR.TTF" }
for name, path in pairs(native) do env[name] = { GetFont = function() return path end } end
local fonts = assert(K.Options.Row("Appearance", "font")).options()
for _, label in ipairs({ "Blizzard Default", "Blizzard Chat", "System Default" }) do
	local entry = assert(O.Find(fonts, function(item) return item.label == label end), label)
	K.Options.Write("Appearance", "font", entry.value)
	assert(K.Theme.FontFace() == entry.value, label .. " writes and applies")
	assert(K.Widgets.Text(K.Scale.Root(), "body"):GetFont() == entry.value, label .. " reaches actual addon text")
end
env.ChatFontNormal.GetFont = function() return env.Secret("Fonts\\ARIALN.TTF") end
fonts = K.Options.Row("Appearance", "font").options()
assert(not O.Find(fonts, function(item) return item.label == "Blizzard Chat" end), "secret native font paths are omitted")
env.ChatFontNormal = nil
env.SystemFont_Med1.GetFont = function() error("font unavailable") end
assert(pcall(K.Options.Row("Appearance", "font").options), "missing or refused native fonts leave bundled choices usable")
K.Options.Write("Appearance", "font", "InterSemiBold")
K.Options.Open("Profiles")
local exported = assert(K.Store.Export())
K.Options.Write("Chat", "sample", 3)
local before = K.Store.Export()
assert(ns.Pages.ReviewImport(exported))
assert(K.Store.Export() == before, "named import review is read only")
local host = K.Widgets.DialogHost()
host.editBox:SetText("Raid night")
O.W.Click(host.visibleButtons[2])
assert(K.Store.ProfileName() == "Raid night" and K.Options.Read("Chat", "sample") == 1, "review's optional name is applied with imported settings")
O.W.Click(host.visibleButtons[1])
assert(ns.Pages.ReviewImport(exported))
host.editBox:SetText("Raid night")
O.W.Click(host.visibleButtons[2])
assert(K.Store.ProfileName() == "Raid night (2)", "duplicate import names remain unique")
O.W.Click(host.visibleButtons[1])
assert(ns.Pages.ReviewImport(exported))
host.editBox:SetText("")
O.W.Click(host.visibleButtons[2])
assert(K.Store.ProfileName():find("Default", 1, true), "blank name keeps the imported profile name")
O.W.Click(host.visibleButtons[1])
local read = K.Store.Module
K.Store.Module = function(section)
	if section == "Appearance" then return { uiScaleAuto = env.Secret(false), uiScale = env.Secret(0.8) } end
	return read(section)
end
assert(not K.Profiles.Preview(exported).warning, "secret current scale cannot be compared in import review")
K.Store.Module = read
row("Elements", "Double-click movers for settings").set(true)
row("General", "Search current page only").set(true)
local upgraded = K.Options.Copy(K.Store.Data())
local _, again = O.New({ saved = upgraded, load = false })
assert(not again.Store.Profile().OptionsWindow and not again.Store.Profile().OptionsMovers, "Editor preferences add no unregistered profile sections")
assert(again.Store.Decode(assert(again.Store.Export())), "A profile exported before Options loads must decode after reload")
assert(again.Store.Account().moverOptions and again.Store.Account().optionsSearchPage, "saved mover preference is available before Options loads")
assert(again.Appearance.Get("font") == "InterSemiBold", "named imported profile survives reload")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("core parity follow-up ok: unchanged defaults, v0.2.8, mover conveniences, search, native fonts, named imports and reset")
