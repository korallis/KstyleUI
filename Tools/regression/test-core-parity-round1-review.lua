-- test-core-parity-round1-review.lua: the round 1 review's probes, switched on: one font call per outline, combat text with game text size, game menu widths, the shown attach point, picks per element, a still grid light, match cycles, import consent, Edit Mode presets and activation, account restore, hotkeys after rename and delete, the CPU readout, page resets and folding with secret measurements.
local O = dofile("Tools/regression/options_env.lua")
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local edit = { saved = { { layoutName = "Mine", layoutType = EditModeFake.ACCOUNT, systems = {} } }, active = 3 }
local env, K, ns = O.New({ saved = { version = 42, profiles = { Default = {}, Other = {} },
	layouts = { Default = { ["Parity.Bar"] = { attachTo = "Parity.Base", side = "below", offset = 4 } } } },
	setup = function(e)
		EditModeFake.Install(e, edit)
		e.C_EditMode.ConvertLayoutInfoToString = function(layout) return "L:" .. layout.layoutName end
		e.C_EditMode.ConvertStringToLayoutInfo = function(text) return { layoutName = text:sub(3), layoutType = EditModeFake.ACCOUNT, systems = {} } end
		e.GetSpecialization, e.GetNumSpecializations = nil, nil
		e.GameMenuFrame = e.CreateFrame("Frame", "GameMenuFrame", e.UIParent)
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
local Layout, Mode, Store = K.Layout, K.Layout.Mode, K.Store
local function page(id) return ns.Pages.Find(ns.Pages.List(), id) end
local function row(id, label)
	return assert(O.Find(page(id).Items(), function(item) return item.label == label end), label)
end
local function near(a, b) return math.abs(a - b) < 0.51 end

-- An outline is applied in the text's one font call.
local text = K.Widgets.FontString(env.UIParent)
K.Widgets.StyleText(text, "body")
K.Options.Write("Appearance", "outline", "OUTLINE")
local setFont, calls = text.SetFont, 0
text.SetFont = function(...) calls = calls + 1; return setFont(...) end
K.Widgets.StyleText(text, "body")
text.SetFont = setFont
assert(calls == 1 and select(3, text:GetFont()) == "OUTLINE", "one StyleText makes one SetFont call with the outline, not " .. calls)
K.Options.Write("Appearance", "outline", "")
assert(select(3, text:GetFont()) == "", "Current style restores the role flags")

-- An untouched Combat text size keeps what Game text size gave combat text before it existed.
env.CreateFont("CombatTextFont"):SetFont("Fonts\\FRIZQT__.TTF", 20, "")
env.GetFonts = function() return { "CombatTextFont" } end
row("General", "Game text size").set(1.25)
assert(select(2, env.CombatTextFont:GetFont()) == 25, "Game text size 125% makes 20 px combat text 25 px")
row("General", "Combat text size").set(1.2)
assert(near(select(2, env.CombatTextFont:GetFont()), 30), "Combat text size multiplies Game text size")
page("General").reset()
assert(select(2, env.CombatTextFont:GetFont()) == 20, "General reset restores the game's combat text")

-- Game menu buttons keep their width through a restyle.
row("General", "KstyleUI settings button").set(true)
row("General", "Layout Mode button").set(true)
local menu = env.GameMenuFrame:GetChildren()
local width = menu.options:GetWidth()
K.Widgets.RestyleAll()
assert(near(width, 200) and near(menu.options:GetWidth(), width) and near(menu.layout:GetWidth(), width), "the game menu buttons stay 200 wide, not " .. menu.options:GetWidth())
page("General").reset()

-- The target point the picker shows is the one the element joins.
local element = O.Find(ns.Pages.Elements(), function(item) return item.key == "Parity.Bar" end)
local items = ns.Pages.ElementItems(element, "Elements", 1)
local function item(label) return O.Find(items, function(i) return i.label == label end) end
item("Point on this element").set("TOPLEFT")
local x, y, tw, th = Layout.Rect("Parity.Base")
local l, b, _, h = Layout.Rect("Parity.Bar")
assert(item("Point on the other element").get() == "CENTER" and near(l - x, tw / 2) and near(b + h - y, th / 2),
	"a source point alone joins the target point the picker shows")
Layout.Set("Parity.Bar", "link", nil)

-- A recent pick is the element's own control.
local account = {}
local function attached()
	return ns.Window.Picks(ns.Model.Search({ page("Elements") }, "Attached X offset"), account)
end
O.Find(attached(), function(i) return i.element == "Parity.Bar" and i.label == "Attached X offset" end).set(6)
local results = attached()
assert(results[1].label == "Recent picks" and results[2].element == "Parity.Bar", "Recent picks returns Parity.Bar's control, not " .. tostring(results[2].element))
Layout.Set("Parity.Bar", "link", nil)

-- The grid light does nothing while the pointer is still.
K.Options.Write("Layout", "grid", true)
row("Elements", "Light the grid around the pointer").set(true)
assert(Layout.Enter())
local plate = Mode.Plate("Parity.Bar")
env._cursor = { 700, 650 }
plate:GetScript("OnDragStart")(plate, "LeftButton")
local update = Mode.Overlay():GetScript("OnUpdate")
update(Mode.Overlay(), 0.016)
local tint, lines, tints = K.Widgets.Tint, {}, 0
for _, region in ipairs({ Mode.Grid():GetRegions() }) do lines[region] = true end
K.Widgets.Tint = function(line, ...)
	if lines[line] then tints = tints + 1 end
	return tint(line, ...)
end
for _ = 1, 60 do update(Mode.Overlay(), 0.016) end
local still = tints
env._cursor = { 704, 650 }
update(Mode.Overlay(), 0.016)
K.Widgets.Tint = tint
plate:GetScript("OnDragStop")(plate)
Layout.Exit(true)
assert(still == 0 and tints > 0 and tints <= 10, "a still pointer tints nothing and a move tints each lit line once: " .. still .. " then " .. tints)

-- Mutual size matches settle at their own sizes.
Layout.Set("Parity.Base", "link", { width = "Parity.Side" })
Layout.Set("Parity.Side", "link", { width = "Parity.Base" })
for _, key in ipairs({ "Parity.Side", "Parity.Base" }) do
	Layout.Set(key, "extraWidth", 3)
	Layout.Set(key, "matchWidth", true)
end
local widths = {}
for i = 1, 3 do
	widths[i] = select(3, Layout.Rect("Parity.Base"))
	Layout.Restore("Parity.Base")
end
assert(near(widths[1], 200) and widths[2] == widths[1] and widths[3] == widths[1], "a match cycle keeps a stable size: " .. table.concat(widths, ", "))
Layout.Reset("Parity.Base")
Layout.Reset("Parity.Side")

-- With review off, an import leaves specializations and Edit Mode alone.
K.Specialization.Assign("role:HEALER", "Default")
local full = assert(K.Profiles.Export("everything", true, { specs = true, editMode = true }))
K.Options.Write("ProfileTools", "review", false)
local saves = edit.saves or 0
assert(ns.Pages.ReviewImport(full))
assert(K.Specialization.Profile("role:HEALER") == "Default" and (edit.saves or 0) == saves, "a direct import changes no specialization or Edit Mode layout")
Store.SetProfile("Default")
K.Options.Write("ProfileTools", "review", true)

-- An active built-in preset is shared; an unreadable one says so; a refused switch is reported.
edit.active = 1
local shared = Store.Decode(assert(K.Profiles.Export("everything", true, { editMode = true })))
assert(shared.editMode and table.concat(shared.editMode) ~= "", "an active built-in preset is shared")
edit.active = 3
local layouts = env.C_EditMode.GetLayouts
env.C_EditMode.GetLayouts = function() error("unreadable") end
local none, why = K.Profiles.Export("everything", true, { editMode = true })
env.C_EditMode.GetLayouts = layouts
assert(none == nil and why == "Edit Mode's active layout could not be read.", "an unreadable layout fails the export with a reason")
local activate, kprint, printed = env.C_EditMode.SetActiveLayout, K.Print, {}
env.C_EditMode.SetActiveLayout = function() error("activation refused") end
K.Print = function(message) printed[#printed + 1] = message end
assert(Store.Import(full, "No activation", { editMode = true }))
K.Print, env.C_EditMode.SetActiveLayout = kprint, activate
assert(printed[1] == "Edit Mode saved it but did not switch to it. Try again, or pick it in Edit Mode.", "a refused switch is reported, not " .. tostring(printed[1]))
Store.SetProfile("Default")

-- Restore after an account import puts back the other characters' choices; a failed backup stops it.
Store.Data().characters["Alt-Realm"] = "Default"
local exported = assert(K.Profiles.ExportAccount())
Store.Data().characters["Alt-Realm"] = "Other"
assert(K.Profiles.ImportAccount(exported) and Store.Data().characters["Alt-Realm"] ~= "Other")
assert(K.Profiles.Restore())
assert(Store.Data().characters["Alt-Realm"] == "Other", "Restore puts the alt back on Other, not " .. tostring(Store.Data().characters["Alt-Realm"]))
local backup, count = K.Profiles.Backup, #Store.ListProfiles()
K.Profiles.Backup = function() return false, "no room" end
assert(not K.Profiles.ImportAccount(exported) and #Store.ListProfiles() == count, "an account import stops when its backup fails")
K.Profiles.Backup = backup
Store.SetProfile("Default")

-- A hotkey follows a renamed profile, frees a deleted one and never creates one.
assert(Store.CreateProfile("Keyed"))
K.Profiles.SetHotkey(2, "Keyed")
assert(Store.RenameProfile("Keyed", "Keyed again"))
env.KstyleUI_Profile2:GetScript("OnClick")(env.KstyleUI_Profile2)
assert(Store.ProfileName() == "Keyed again" and Store.Data().profiles.Keyed == nil, "a hotkey follows its renamed profile")
Store.SetProfile("Default")
assert(Store.DeleteProfile("Keyed again") and K.Profiles.Hotkey(2) == "", "deleting a profile frees its hotkey")
Store.Account().profileKeys = { [2] = "Gone" }
env.KstyleUI_Profile2:GetScript("OnClick")(env.KstyleUI_Profile2)
assert(Store.ProfileName() == "Default" and Store.Data().profiles.Gone == nil, "a hotkey to a missing profile changes nothing")
Store.Account().profileKeys = nil

-- The CPU readout counts the Options addon, offers no summed peak and stays off when the profiler can't say.
env.C_AddOnProfiler = { IsEnabled = function() return true end, GetAddOnMetric = function(name) return name == "KstyleUI_Options" and 7 or 0 end }
assert(ns.Pages.Cpu(1) == "KstyleUI: 7.00 ms", "the readout counts KstyleUI_Options")
for _, option in ipairs(row("About", "CPU readout").options) do assert(option.value ~= 4, "no Peak: per-addon peaks come from different frames") end
local off = "The game's addon profiler is off, so there is no CPU readout."
env.C_AddOnProfiler.IsEnabled = function() error("refused") end
assert(ns.Pages.Cpu(1) == off, "a failing IsEnabled shows no readout")
env.C_AddOnProfiler.IsEnabled = nil
assert(ns.Pages.Cpu(1) == off, "a missing IsEnabled shows no readout")

-- Page resets clear the grid light and the folded rail sections.
row("Elements", "Light the grid around the pointer").set(true)
page("Elements").reset()
assert(not row("Elements", "Light the grid around the pointer").get(), "Elements reset turns the grid light off")
Store.Account().optionsRailFolded = { General = true }
page("General").reset()
assert(Store.Account().optionsRailFolded == nil, "General reset unfolds the rail's sections")

-- Folding checks every measurement before it changes the window.
assert(K.Options.Open("General"))
env.RunTimers()
local win = ns.Window.Frame()
local scale = win.GetEffectiveScale
for _, value in ipairs({ env.Secret(1), 0 }) do
	win.GetEffectiveScale = function() return value end
	local ok, err = pcall(ns.Window.SetFolded, true)
	win.GetEffectiveScale = scale
	assert(ok and not ns.Window.State().folded, "an unusable scale leaves the window open: " .. tostring(err))
end

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("core parity round 1 review ok: outline, combat text, game menu, attach point, picks, grid light, match cycle, consent, Edit Mode, account restore, hotkeys, CPU, resets, folding")
