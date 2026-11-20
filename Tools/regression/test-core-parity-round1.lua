-- test-core-parity-round1.lua: the palette, inherited outline, name font, combat text size, attach points and offsets, match targets, per-element snap, grid light, profile extras, account sharing, presets, hotkeys, search picks, folding, CPU readout and game menu buttons, each off by default and switched on.
local O = dofile("Tools/regression/options_env.lua")
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local edit = { saved = { { layoutName = "Mine", layoutType = EditModeFake.ACCOUNT, systems = {} } }, active = 3 }
local env, K, ns = O.New({ saved = { version = 42, profiles = { Default = { Appearance = { font = "InterSemiBold" } }, Other = {} },
	layouts = { Default = { ["Parity.Bar"] = { attachTo = "Parity.Base", side = "below", offset = 4 } } } },
	setup = function(e)
		EditModeFake.Install(e, edit)
		e.C_EditMode.ConvertLayoutInfoToString = function(layout) return "L:" .. layout.layoutName end
		e.C_EditMode.ConvertStringToLayoutInfo = function(text) return { layoutName = text:sub(3), layoutType = EditModeFake.ACCOUNT, systems = {} } end
		e.GetSpecialization, e.GetNumSpecializations = nil, nil
		e.GameMenuFrame = e.CreateFrame("Frame", "GameMenuFrame", e.UIParent)
		e.PowerBarColor = { MANA = { r = 0, g = 0, b = 1 }, RAGE = { r = 1, g = 0, b = 0 } }
	end,
	before = function(e, k)
		k.Modules.Register(O.W.CoreEnv.Module("Chat", { defaults = { sample = 1 } }))
		k.Modules.Enable("Chat")
		for key, size in pairs({ ["Parity.Base"] = { 200, 40, 0 }, ["Parity.Bar"] = { 80, 20, -100 }, ["Parity.Side"] = { 60, 30, 200 } }) do
			local frame = e.CreateFrame("Frame", nil, k.Scale.Root())
			frame:SetSize(size[1], size[2])
			k.Layout.Register(frame, key, { anchor = "CENTER", x = 0, y = size[3] }, { module = "Chat", label = key, resizable = true })
		end
	end })
local Layout, Mode, Theme, Store = K.Layout, K.Layout.Mode, K.Theme, K.Store
local function row(page, label)
	return assert(O.Find(ns.Pages.Find(ns.Pages.List(), page).Items(), function(item) return item.label == label end), label)
end
local function near(a, b) return math.abs(a - b) < 0.51 end
local themed = 0
K.Callbacks.Register("ThemeChanged", "ParityRound1", function() themed = themed + 1 end)

-- Defaults: nothing changes until a player switches an option on.
local styleText = K.Widgets.StyleText
K.Appearance.Apply()
assert(themed == 0 and Theme.Palette("WARRIOR") == nil and Theme.Palette("MANA") == nil and Theme.outline == nil and K.Widgets.StyleText == styleText,
	"a default reload adds no palette, outline or theme change")
assert(K.Appearance.Get("outline") == "" and K.Appearance.Get("paletteDarken") == 0 and not row("General", "Use your names font for names in the world").get()
	and row("General", "Combat text size").get() == 1 and not row("General", "Remember search picks").get() and not row("General", "Double-click the header to fold").get()
	and not row("General", "KstyleUI settings button").get() and not row("General", "Layout Mode button").get()
	and not row("Elements", "Light the grid around the pointer").get() and env.GameMenuFrame:GetNumChildren() == 0, "every new option starts off")
local bl, bb, bw, bh = Layout.Rect("Parity.Base")
local l, b, w, h = Layout.Rect("Parity.Bar")
assert(near(l, bl + (bw - w) / 2) and near(b + h, bb - 4), "a v0.2.8 link keeps its place")

-- Class and power palette: on, darkened, shared and reset.
local native = { Theme.ClassColor("WARRIOR") }
local accent = { Theme.Accent() }
local sample = ns.Preview.Sample(env.UIParent)
local plainName = { sample.body:GetTextColor() }
K.Options.Write("Appearance", "classColors.WARRIOR", { r = 0.1, g = 0.2, b = 0.3 })
K.Options.Write("Appearance", "classColors." .. Theme.Class(), { r = 0.4, g = 0.5, b = 0.6 })
sample:Refresh()
local name = select(2, sample:GetRegions())
assert(select(1, Theme.Accent()) == accent[1] and select(1, name:GetTextColor()) == 0.4 and select(1, sample.body:GetTextColor()) == plainName[1], "the accent stays and the preview's name takes your class colour")
K.Options.Write("Appearance", "classColors." .. Theme.Class(), K.Options.Default("Appearance", "classColors." .. Theme.Class()))
sample:Refresh()
assert(select(1, name:GetTextColor()) ~= 0.4, "the preview name returns to its own colour")
themed = 1
local r, g, bl2 = Theme.ClassColor("WARRIOR")
assert(themed == 1 and r == 0.1 and g == 0.2 and bl2 == 0.3 and Theme.Palette("WARRIOR").r == 0.1, "a custom class colour reaches every class colour reader")
assert(Theme.Palette(env.Secret("WARRIOR")) == nil and select(1, Theme.ClassColor("MAGE")) ~= 0.1, "secret classes and other classes keep the game's colour")
K.Options.Write("Appearance", "powerColors.MANA", { r = 0.2, g = 0.4, b = 0.6 })
assert(Theme.Palette("MANA").b == 0.6, "a custom power colour reaches the power readers")
K.Options.Write("Appearance", "paletteDarken", 0.5)
assert(near(Theme.ClassColor("WARRIOR") * 100, 5) and near(Theme.Palette("RAGE").r * 100, 50), "darkening applies to custom and game colours")
K.Appearance.CopyPalette("Default")
local other = Store.Data().profiles.Other.Appearance
assert(other.classColors.WARRIOR.r == 0.1 and other.paletteDarken == 0.5, "use these colours in every profile copies the palette")
for _, key in ipairs({ "classColors.WARRIOR", "powerColors.MANA", "paletteDarken" }) do K.Options.Write("Appearance", key, K.Options.Default("Appearance", key)) end
assert(Theme.Palette("WARRIOR") == nil and Theme.Palette("RAGE") == nil and Theme.ClassColor("WARRIOR") == native[1], "resetting each swatch restores the game's colours")
K.Appearance.CopyPalette("Other", "Default")
assert(Theme.Palette("WARRIOR").r == 0.05 and K.Options.Read("Appearance", "paletteDarken") == 0.5, "copy colours from takes another profile's palette")
K.Appearance.CopyPalette("Default", "Other")
for _, key in ipairs({ "classColors.WARRIOR", "paletteDarken" }) do K.Options.Write("Appearance", key, K.Options.Default("Appearance", key)) end

-- The inherited outline swaps in only while chosen and restores the role flags.
local text = K.Widgets.FontString(env.UIParent)
K.Widgets.StyleText(text, "body")
assert(select(3, text:GetFont()) == "", "body text has no outline by default")
K.Options.Write("Appearance", "outline", "THICKOUTLINE")
assert(K.Widgets.StyleText ~= styleText, "an outline choice swaps the text styler")
K.Widgets.StyleText(text, "body")
assert(select(3, text:GetFont()) == "THICKOUTLINE", "inherited text takes the chosen outline")
K.Options.Write("Appearance", "outline", "")
K.Widgets.StyleText(text, "body")
assert(K.Widgets.StyleText == styleText and select(3, text:GetFont()) == "", "current style restores the original styler and flags")

-- Name font and combat text size touch only their own fonts.
env.UNIT_NAME_FONT, env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF"
env.CreateFont("GameFontNormal"):SetFont("Fonts\\FRIZQT__.TTF", 12, "")
env.CreateFont("CombatTextFont"):SetFont("Fonts\\FRIZQT__.TTF", 20, "")
env.GetFonts = function() return { "GameFontNormal", "CombatTextFont" } end
row("General", "Use your names font for names in the world").set(true)
assert(env.UNIT_NAME_FONT == K.Tokens.Font("names") and env.STANDARD_TEXT_FONT == "Fonts\\FRIZQT__.TTF", "the names font changes world names only")
row("General", "Combat text size").set(1.5)
assert(select(2, env.CombatTextFont:GetFont()) == 30 and select(2, env.GameFontNormal:GetFont()) == 12, "combat text size scales only the combat text font")
row("General", "Combat text size").set(1)
row("General", "Use your names font for names in the world").set(false)
assert(select(2, env.CombatTextFont:GetFont()) == 20 and env.UNIT_NAME_FONT == "Fonts\\FRIZQT__.TTF", "turning both off restores the game's fonts")

-- Attach points, sideways offsets and independent match targets.
assert(Layout.Set("Parity.Bar", "link", { point = "TOPLEFT", target = "BOTTOMRIGHT", x = 5, y = -3 }))
bl, bb, bw, bh = Layout.Rect("Parity.Base")
l, b, w, h = Layout.Rect("Parity.Bar")
assert(near(l, bl + bw + 5) and near(b + h, bb - 3), "point pairs join the chosen points with their offsets")
local move = Layout.Movement("Parity.Bar", l + 10, b, w, h)
assert(move.link and near(move.link.x, 15) and move.offset == nil, "dragging a point link moves its offsets")
assert(Layout.Set("Parity.Bar", "link", { x = 7 }))
l, b, w, h = Layout.Rect("Parity.Bar")
assert(near(l, bl + (bw - w) / 2 + 7) and near(b + h, bb - 4), "a sideways offset shifts a side link")
assert(not Layout.Set("Parity.Bar", "link", { point = "MIDDLE" }) and not Layout.Set("Parity.Bar", "link", { x = 1e9 }), "bad links are refused")
assert(Layout.Set("Parity.Side", "matchWidth", true) and Layout.Set("Parity.Side", "link", { width = "Parity.Base" }))
assert(near(select(3, Layout.Rect("Parity.Side")), bw), "match width works from another element without attaching")
assert(Layout.Set("Parity.Base", "matchWidth", true) and Layout.Set("Parity.Base", "link", { width = "Parity.Side" }))
assert(Layout.Set("Parity.Side", "width", 90), "a match cycle settles without looping")
Layout.Reset("Parity.Base")
Layout.Reset("Parity.Side")
Layout.Set("Parity.Bar", "link", nil)
l, b, w, h = Layout.Rect("Parity.Bar")
assert(Layout.Get("Parity.Bar").link == nil and near(l, bl + (bw - w) / 2) and near(b + h, bb - 4), "clearing the link restores the side placement")

-- Per-element snap and the grid light only work while dragging.
local function Cursor(x, y)
	local scale = K.Scale.Root():GetEffectiveScale()
	env._cursor = { (x + K.Scale.Origin()) * scale, y * scale }
end
K.Options.Write("Layout", "grid", true)
assert(Layout.Enter())
local plate = Mode.Plate("Parity.Side")
local function drag(x, y)
	local sl, sb = Layout.Rect("Parity.Side")
	Cursor(sl, sb)
	plate:GetScript("OnDragStart")(plate, "LeftButton")
	Cursor(sl + x, sb + y)
	Mode.Overlay():GetScript("OnUpdate")(Mode.Overlay(), 0.016)
end
Layout.Set("Parity.Side", "link", { snap = "none" })
local before = { Layout.Rect("Parity.Side") }
drag(3, 0)
local after = { Layout.Rect("Parity.Side") }
assert(near(after[1], before[1] + 3), "Never moves without snapping")
plate:GetScript("OnDragStop")(plate)
row("Elements", "Light the grid around the pointer").set(true)
drag(2, 0)
local lit = 0
for _, region in ipairs({ Mode.Grid():GetRegions() }) do if region:IsShown() and select(4, region:GetVertexColor()) > K.Layout.Setting("gridAlpha") + 0.05 then lit = lit + 1 end end
assert(lit > 0, "grid lines near the pointer light up while dragging")
plate:GetScript("OnDragStop")(plate)
lit = 0
for _, region in ipairs({ Mode.Grid():GetRegions() }) do if region:IsShown() and select(4, region:GetVertexColor()) > K.Layout.Setting("gridAlpha") + 0.05 and select(1, region:GetVertexColor()) == 1 then lit = lit + 1 end end
assert(lit == 0, "the grid dims again when the drag ends")
Layout.Exit(true)
Layout.Reset("Parity.Side")
K.Options.Write("Layout", "grid", false)

-- Specialization assignments and the Edit Mode layout travel only when included.
K.Specialization.Assign("role:HEALER", "Default")
K.Specialization.Assign("role:TANK", "Other")
K.Specialization.Assign("role:DAMAGER", "Other")
Store.SetProfile("Default")
local plain = assert(K.Profiles.Export("everything", true))
assert(Store.Decode(plain).specs == nil and Store.Decode(plain).editMode == nil, "exports leave extras out by default")
local full = assert(K.Profiles.Export("everything", true, { specs = true, editMode = true }))
local decoded = Store.Decode(full)
assert(#decoded.specs == 1 and decoded.specs[1] == "role:HEALER" and table.concat(decoded.editMode) == "L:Mine", "included extras carry the spec keys and the Edit Mode layout")
assert(not K.Profiles.Preview(full).text:find("editMode", 1, true) or Store.Decode(K.Profiles.Preview(full).text).editMode == nil, "review strips extras unless included")
local preview = K.Profiles.Preview(full, "everything", true, { specs = true, editMode = true })
assert(Store.Decode(preview.text).editMode and table.concat(preview.changes, ","):find("Edit Mode", 1, true), "review lists the included extras")
local saves = edit.saves or 0
assert(Store.Import(preview.text, "Shared"))
assert(K.Specialization.Profile("role:HEALER") == "Shared" and edit.saves == saves + 1 and EditModeFake.Named(edit, "KstyleUI Shared"), "import assigns the specs and adds the Edit Mode layout")
assert(Store.Account().editModeBackup and Store.Account().editModeBackup.name == "Before import", "the Edit Mode change has a recovery backup")

-- Every profile shares as one string and keeps the recipient's profiles.
local account = assert(K.Profiles.ExportAccount())
local count = #Store.ListProfiles()
assert(K.Profiles.ImportAccount(account), "an account string imports")
assert(#Store.ListProfiles() >= count * 2 - 1 and Store.Data().profiles.Other, "every profile is added and the others stay")
assert(not K.Profiles.ImportAccount("KSA1:bad"), "a damaged account string is refused")

-- Presets make a new profile; hotkeys switch after combat.
assert(#K.Profiles.Presets() >= 6, "the preset browser lists each role and HUD style")
local made, name = K.Profiles.FromPreset("Healer:orbs", "Healer orbs")
assert(made and Store.ProfileName() == name and K.HudStyle.Saved() == "orbs", "a preset creates and fills a new profile")
Store.SetProfile("Default")
K.Profiles.SetHotkey(2, "Other")
assert(env.KstyleUI_Profile2 and K.Profiles.Hotkey(2) == "Other", "a hotkey slot makes its binding button")
env.SetCombat(true)
env.KstyleUI_Profile2:GetScript("OnClick")(env.KstyleUI_Profile2)
assert(Store.ProfileName() == "Default", "a hotkey waits for combat to end")
env.SetCombat(false)
assert(Store.ProfileName() == "Other", "then switches the profile")
K.Profiles.SetHotkey(2, "")
assert(Store.Account().profileKeys == nil, "None frees the slot")
Store.SetProfile("Default")

-- Search picks, rail folding, window folding, the CPU readout and the game menu buttons.
assert(K.Options.Open("General"))
env.RunTimers()
row("General", "Remember search picks").set(true)
local function search(text)
	local box = ns.Window.Parts().search
	box:SetText(text)
	box:GetScript("OnTextChanged")(box, true)
end
search("snap")
local function results() return ns.Window.State().items end
local pick = O.Find(results(), function(item) return item.label == "Snap distance" end)
pick.set(10)
search("")
search("snap")
assert(results()[1].label == "Recent picks" and results()[2].label == "Snap distance", "remembered picks list first")
row("General", "Clear search picks").buttons[1].onClick()
search("")
search("snap")
assert(results()[1].label ~= "Recent picks", "clearing forgets the picks")
search("")
env.RunTimers()
local rail = ns.Window.Parts().rail
local function sections() for _, entry in ipairs(rail.items) do if entry.section then return true end end end
local general = O.Find(rail.rows, function(r2) return r2.entry and r2.entry.id == "General" end)
assert(sections(), "the open page lists its sections")
general.onClick(general, "RightButton")
assert(not sections() and Store.Account().optionsRailFolded.General, "right-clicking a page folds its sections")
general = O.Find(rail.rows, function(r2) return r2.entry and r2.entry.id == "General" end)
general.onClick(general, "RightButton")
assert(sections() and Store.Account().optionsRailFolded == nil, "right-clicking again unfolds them")
local win = ns.Window.Frame()
local height = win:GetHeight()
env.GetTime = function() return 1 end
win.header:GetScript("OnMouseUp")(win.header, "LeftButton")
win.header:GetScript("OnMouseUp")(win.header, "LeftButton")
assert(win:GetHeight() == height, "double-click does nothing while folding is off")
row("General", "Double-click the header to fold").set(true)
local top = win:GetTop()
win.header:GetScript("OnMouseUp")(win.header, "LeftButton")
win.header:GetScript("OnMouseUp")(win.header, "LeftButton")
assert(win:GetHeight() < height / 4 and near(win:GetTop(), top), "a double-click folds the window to its header in place")
win.header:GetScript("OnMouseUp")(win.header, "LeftButton")
win.header:GetScript("OnMouseUp")(win.header, "LeftButton")
assert(near(win:GetHeight(), height), "a second double-click opens it at its saved size")
env.C_AddOnProfiler = { IsEnabled = function() return true end, GetAddOnMetric = function(addon, metric) return addon == "KstyleUI" and metric + 1 or 0.25 end }
K.Options.Open("About")
row("About", "CPU readout").set(1)
assert(O.Find(ns.Pages.Find(ns.Pages.List(), "About").Items(), function(item) return item.label == "KstyleUI: 2.25 ms" end), "the readout sums KstyleUI's addons")
row("About", "CPU readout").set("")
assert(not O.Find(ns.Pages.Find(ns.Pages.List(), "About").Items(), function(item) return tostring(item.label):find("ms$") end), "Off removes the readout")
row("General", "KstyleUI settings button").set(true)
row("General", "Layout Mode button").set(true)
local menu = env.GameMenuFrame:GetChildren()
assert(menu and menu.options:IsShown() and menu.layout:IsShown() and select(2, menu.layout:GetPoint(1)) == menu.options, "both game menu buttons show, stacked")
row("General", "KstyleUI settings button").set(false)
assert(not menu.options:IsShown() and menu.layout:IsShown() and select(2, menu.layout:GetPoint(1)) == menu, "one button moves to the top")
ns.Pages.Find(ns.Pages.List(), "General").reset()
assert(not menu.layout:IsShown() and Store.Account().gameMenuLayout == nil and Store.Account().optionsFold == nil, "General reset turns every new account option off")

local _, again = O.New({ saved = K.Options.Copy(Store.Data()), load = false })
assert(again.Store.Decode(assert(again.Store.Export())), "a profile exported after these options decodes before Options loads")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("core parity round 1 ok: palette, outline, game fonts, attach points, match targets, snap, grid light, extras, account, presets, hotkeys, picks, folding, CPU, game menu")
