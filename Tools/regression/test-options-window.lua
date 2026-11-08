-- test-options-window.lua: the settings window loads on demand, builds every page from the schemas and Layout elements, and its controls, search, profiles, preview and Escape work.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local Module = W.CoreEnv.Module

local function FakeLayout(env)
	local layout = { elements = {}, stored = {}, sets = {}, resets = {} }
	function layout.Register(frame, key, position, opts)
		layout.elements[#layout.elements + 1] = { frame = frame, key = key, position = position, opts = opts or {} }
	end
	function layout.Elements()
		local out = {}
		for i, element in ipairs(layout.elements) do
			out[i] = { key = element.key, label = element.opts.label, module = element.opts.module, opts = element.opts }
		end
		return out
	end
	function layout.Get(key)
		layout.stored[key] = layout.stored[key] or {}
		return layout.stored[key]
	end
	function layout.Set(key, field, value)
		layout.sets[#layout.sets + 1] = { key = key, field = field, value = value }
		layout.Get(key)[field] = value
	end
	function layout.Reset(key)
		layout.resets[#layout.resets + 1] = key
		layout.stored[key] = {}
	end
	layout.SHOWN_OPTIONS = {
		{ value = "always", label = "Always" },
		{ value = "noCombat", label = "Out of combat only" },
		{ value = "special", label = "A rule only Layout knows" },
	}
	function layout.Enter()
		layout.entered = (layout.entered or 0) + 1
	end
	env._fakeLayout = layout
	return layout
end

local previewBuilds, previewRefreshes = 0, 0

local function boot(withLayout)
	return O.New({
		setup = function(env)
			env._pickerColour = { 0.2, 0.4, 0.6 }
			env.ColorPickerFrame = {
				SetupColorPickerAndShow = function(_, info)
					env._picker = info
				end,
				GetColorRGB = function()
					return env._pickerColour[1], env._pickerColour[2], env._pickerColour[3]
				end,
				GetColorAlpha = function()
					return 1
				end,
			}
		end,
		before = function(env, K)
			if withLayout then
				K.Layout = FakeLayout(env)
			else
				K.Layout = nil
			end
			K.Modules.Register(Module("UnitFrames", {
				defaults = { portraits = true, size = 20, style = "solid", colour = { r = 1, g = 0.5, b = 0 }, label = "Player", font = (K.Tokens.Font("body")) },
			}))
			local schema = {
				{ type = "header", label = "Player frame" },
				{ type = "toggle", key = "portraits", label = "Show portraits", help = "Show a portrait on the player frame." },
				{ type = "slider", key = "size", label = "Portrait size", help = "Sets the size of the portrait.", min = 10, max = 40, step = 1 },
				{ type = "dropdown", key = "style", label = "Health bar style", help = "Choose the appearance of the health bar.", options = {
					{ value = "solid", label = "Solid" }, { value = "glass", label = "Glass" },
				} },
				{ type = "color", key = "colour", label = "Ring colour", help = "The portrait ring colour.", showWhen = function(s) return s.portraits end },
				{ type = "text", key = "label", label = "Frame label", help = "Text on the frame.", maxLetters = 16 },
				{ type = "font", key = "font", label = "Frame font", help = "The font of the frame's text." },
			}
			schema.preview = function(parent)
				previewBuilds = previewBuilds + 1
				local frame = env.CreateFrame("Frame", nil, parent)
				frame.Refresh = function()
					previewRefreshes = previewRefreshes + 1
				end
				return frame
			end
			K.Options.Register("UnitFrames", schema)
			K.Modules.Register(Module("Minimap", { defaults = {} }))
		end,
	})
end

local function settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function rowFor(ns, label)
	local parts = ns.Window.Parts()
	local items = ns.Window.State().items
	local index
	for i, item in ipairs(items) do
		if item.label == label then
			index = i
			break
		end
	end
	assert(index, "no row labelled " .. label)
	parts.content:ScrollToIndex(index, true)
	for _, row in ipairs(parts.content.rows) do
		if row.index == index and row:IsShown() then
			return row
		end
	end
	error("row " .. label .. " is not on screen")
end

local function rowWhere(ns, fn)
	local parts = ns.Window.Parts()
	local _, index = O.Find(ns.Window.State().items, fn)
	assert(index, "no matching row")
	parts.content:ScrollToIndex(index, true)
	for _, row in ipairs(parts.content.rows) do
		if row.index == index and row:IsShown() then
			return row
		end
	end
	error("the matching row is not on screen")
end

local function labels(ns)
	return O.Labels(ns.Window.State().items)
end

local function has(list, label)
	for _, value in ipairs(list) do
		if value == label then
			return true
		end
	end
	return false
end

local env, K, ns = boot(true)
local layout = env._fakeLayout

-- Opening: on-demand load, motion, Layout registration and the page list ------------------------

do
	assert(env._addons.KstyleUI_Options and ns.Window, "the settings addon loaded")
	assert(K.Options.Open() == true)
	local win = ns.Window.Frame()
	assert(win and win:IsShown(), "Open shows the window")
	settle(env)
	assert(win:GetAlpha() == 1, "the window fades in to full alpha")
	assert(win:GetFrameStrata() == "HIGH", "the window sits in the HIGH strata")
	assert(win.chrome and win.chrome.shapeName == "window", "the settings window, a titled window, wears the window grade's 12-unit chamfer, not the panel's 8")
	local element = O.Find(layout.elements, function(e) return e.key == "Options.Window" end)
	assert(element and element.frame == win, "the window registers with Layout")
	assert(element.opts.resizable and element.opts.scalable and element.opts.module == "Options", "the window is resizable and scalable")
	assert(element.opts.minWidth < element.opts.maxWidth and element.opts.minHeight < element.opts.maxHeight)

	local pages = O.Labels(ns.Window.Parts().rail:GetData())
	assert(table.concat(pages, "|") == "General|Elements|Unit Frames|Minimap|Profiles|About", "rail pages: " .. table.concat(pages, "|"))
	assert(ns.Window.State().page == "General", "the window opens on General")
end

-- General: the core's appearance and widget settings ---------------------------------------------

do
	local list = labels(ns)
	assert(has(list, "Accent colour") and has(list, "Interface size") and has(list, "Panel opacity"), "General holds the Appearance and Widgets rows")
	assert(not has(list, "Custom accent"), "a row hidden by showWhen is left out")
	local size = O.Find(ns.Window.State().items, function(item) return item.label == "Interface size" end)
	assert(size.defer == true, "the interface size applies on release, so the window does not rescale under the pointer")
	local row = rowFor(ns, "Interface sounds")
	local toggle = row.controls.toggle
	assert(toggle and toggle:IsShown() and toggle:GetValue() == true, "a toggle row shows its value")
	W.Click(toggle)
	settle(env)
	assert(K.Store.Module("Widgets").sounds == false, "clicking the toggle writes the setting")
	assert(ns.Window.Parts().preview.current ~= ns.Window.Parts().preview.placeholder, "General shows the kit sample preview")
end

-- A module page: enable switch, controls, showWhen, preview -----------------------------------------

do
	K.Options.Open("UnitFrames")
	settle(env)
	assert(ns.Window.State().page == "UnitFrames", "Open(page) selects the page")
	local list = labels(ns)
	assert(list[1] == "Unit Frames" and list[2] == "Enable Unit Frames", "a module page starts with its enable switch")
	assert(has(list, "Ring colour"), "showWhen shows the row while portraits are on")
	assert(previewBuilds == 1, "the module's preview builder ran once")

	local dropdown = rowFor(ns, "Health bar style").controls.dropdown
	assert(dropdown:GetValue() == "solid")
	dropdown:SetValue("glass")
	settle(env)
	assert(K.Store.Module("UnitFrames").style == "glass", "choosing an option writes the setting")
	assert(previewRefreshes >= 1, "the preview refreshes after a setting changes")

	local slider = rowFor(ns, "Portrait size").controls.slider
	assert(slider:GetValue() == 20 and slider.min == 10 and slider.max == 40)
	local hides = #W.Calls(slider, "Hide")
	slider:SetScript("OnUpdate", function() end)
	slider:SetValue(32)
	env.RunTimers()
	assert(K.Store.Module("UnitFrames").size == 32, "moving the slider writes the setting")
	assert(#W.Calls(slider, "Hide") == hides, "the refresh after a write never hides the slider being dragged")
	slider:SetScript("OnUpdate", nil)
	settle(env)

	local font = rowFor(ns, "Frame font").controls.font
	assert(#font:GetOptions() >= 3, "a font row lists KstyleUI's fonts, not just the stored one")
	assert(font:GetValue() == K.Tokens.Font("body"))

	local swatch = rowFor(ns, "Ring colour").controls.color.swatch
	W.Click(swatch)
	assert(env._picker, "the swatch opens the colour picker")
	K.Options.Open("Profiles")
	settle(env)
	env._picker.swatchFunc()
	settle(env)
	local ring = K.Store.Module("UnitFrames").colour
	assert(ring.r == 0.2 and ring.g == 0.4 and ring.b == 0.6, "a colour picked after the page changed still goes to its own setting")
	env._picker.cancelFunc({ r = 1, g = 0.5, b = 0 })
	settle(env)
	ring = K.Store.Module("UnitFrames").colour
	assert(ring.r == 1 and ring.g == 0.5 and ring.b == 0, "cancelling restores that setting")
	local refreshes = previewRefreshes
	K.Options.Open("UnitFrames")
	settle(env)
	assert(previewRefreshes > refreshes, "a cached preview refreshes when its page shows again")

	local box = rowFor(ns, "Frame label").controls.text
	box:SetText("Me")
	box:GetScript("OnEnterPressed")(box)
	settle(env)
	assert(K.Store.Module("UnitFrames").label == "Me", "Enter in a text row writes the setting")

	W.Click(rowFor(ns, "Show portraits").controls.toggle)
	settle(env)
	assert(not has(labels(ns), "Ring colour"), "the row hides when its showWhen turns false")

	W.Click(rowFor(ns, "Enable Unit Frames").controls.toggle)
	settle(env)
	assert(K.Modules.IsEnabled("UnitFrames") == true, "the enable switch turns the module on")
	previewBuilds = 0
	K.Options.Open("General")
	K.Options.Open("UnitFrames")
	assert(previewBuilds == 0, "the preview is built once and reused")
end

-- Search across pages ---------------------------------------------------------------------------

do
	local parts = ns.Window.Parts()
	parts.search:SetText("health bar")
	parts.search:GetScript("OnTextChanged")(parts.search, true)
	local list = labels(ns)
	assert(list[1] == "Unit Frames" and has(list, "Health bar style"), "search finds rows by label: " .. table.concat(list, "|"))
	assert(parts.clear:IsShown(), "the clear button shows while searching")
	parts.search:SetText("portrait ring")
	parts.search:GetScript("OnTextChanged")(parts.search, true)
	assert(labels(ns)[1]:find("No settings match", 1, true), "a search with no visible match says so")
	parts.search:SetText("smoke")
	parts.search:GetScript("OnTextChanged")(parts.search, true)
	assert(has(labels(ns), "Smoke checks"), "search covers the About page")
	W.Click(parts.clear)
	assert(ns.Window.State().query == nil and not parts.clear:IsShown(), "clear ends the search")
	assert(labels(ns)[2] == "Enable Unit Frames", "the selected page comes back")
end

-- Elements: every registered element with its layout settings ------------------------------------

do
	K.Layout.Register(env.CreateFrame("Frame"), "UnitFrames.Player", { anchor = "BOTTOM", x = -200, y = 260 }, {
		label = "Player frame", module = "UnitFrames", resizable = true, minWidth = 120, maxWidth = 400, minHeight = 30, maxHeight = 90,
	})
	K.Layout.Register(env.CreateFrame("Frame"), "Minimap.Map", { anchor = "TOPRIGHT", x = 0, y = 0 }, {
		label = "Minimap", module = "Minimap", scalable = true,
	})
	K.Options.Open("Elements")
	settle(env)
	local list = labels(ns)
	assert(has(list, "Player frame") and has(list, "Minimap") and has(list, "Settings window"), "every element is listed")
	assert(has(list, "Unit Frames"), "elements are grouped by module")
	local shownValues = {}
	for _, option in ipairs(rowFor(ns, "Shown").controls.dropdown:GetOptions()) do
		shownValues[#shownValues + 1] = option.value
	end
	assert(table.concat(shownValues, "|") == "always|noCombat|special", "the shown rules come from Layout: " .. table.concat(shownValues, "|"))
	local anchor = rowFor(ns, "Anchor")
	anchor.controls.dropdown:SetValue("TOPLEFT")
	settle(env)
	local last = layout.sets[#layout.sets]
	assert(last and last.field == "anchor" and last.value == "TOPLEFT", "choosing an anchor calls Layout.Set")

	local scaleRow = rowWhere(ns, function(item)
		return item.element == "Options.Window" and item.label == "Scale"
	end)
	local scale = scaleRow.controls.slider
	local before = #layout.sets
	scale:SetScript("OnUpdate", function() end)
	scale:SetValue(1.5)
	assert(#layout.sets == before, "the window's own scale waits while the slider is dragged")
	scale:SetScript("OnUpdate", nil)
	scale:GetScript("OnMouseUp")(scale, "LeftButton")
	last = layout.sets[#layout.sets]
	assert(#layout.sets == before + 1 and last.key == "Options.Window" and last.field == "scale" and last.value == 1.5, "releasing the slider applies the scale")

	K.Options.Open("Settings")
	settle(env)
	assert(ns.Window.State().page == "General", "an unknown page opens General")
	local own = ns.Pages.ElementItems({ key = "Options.Window", label = "Settings window", module = "Options", opts = { scalable = true } }, "Elements", 2)
	assert(not O.Find(own, function(item) return item.label == "Shown" end), "the settings window cannot hide itself with a shown rule")
	local ownAlpha = O.Find(own, function(item) return item.label == "Opacity out of combat" end)
	assert(ownAlpha.min > 0 and ownAlpha.defer, "the settings window keeps some opacity, and its sliders apply on release")

	K.Options.Open("UnitFrames")
	settle(env)
	list = labels(ns)
	assert(has(list, "Positions and sizes") and has(list, "Width") and has(list, "Height"), "a module page lists its elements' sizes")
	assert(not has(list, "Scale"), "a resizable element shows width and height, not scale")
	local width = rowFor(ns, "Width").controls.slider
	assert(width.min == 120 and width.max == 400, "width uses the element's limits")
	width:SetValue(250)
	settle(env)
	last = layout.sets[#layout.sets]
	assert(last.key == "UnitFrames.Player" and last.field == "width" and last.value == 250)
	W.Click(rowFor(ns, "Reset this element").controls.button.buttons[1])
	assert(layout.resets[#layout.resets] == "UnitFrames.Player", "the reset button resets the element")

	K.Options.Open("Minimap")
	settle(env)
	assert(has(labels(ns), "Scale") and not has(labels(ns), "Width"), "a scalable element shows scale")
end

-- When the core has the LayoutChanged callback, the window restyles after its own scale changes ------

do
	local win = ns.Window.Frame()
	local restyles = 0
	local restyleAll = K.Widgets.RestyleAll
	K.Widgets.RestyleAll = function()
		restyles = restyles + 1
		restyleAll()
	end
	if pcall(K.Callbacks.Fire, "LayoutChanged", "UnitFrames.Player") then
		assert(restyles == 0, "another element's change does not restyle the kit")
		win:SetScale(1.25)
		K.Callbacks.Fire("LayoutChanged", "Options.Window")
		assert(restyles == 1, "a new window scale restyles the kit once")
		K.Callbacks.Fire("LayoutChanged", "Options.Window")
		assert(restyles == 1, "the same scale does not restyle again")
		win:SetScale(1)
		K.Callbacks.Fire("LayoutChanged", "Options.Window")
	end
	K.Widgets.RestyleAll = restyleAll
end

-- Profiles: create, export, import errors ------------------------------------------------------------

do
	K.Options.Open("Profiles")
	settle(env)
	local list = labels(ns)
	for _, label in ipairs({ "Profile", "New profile", "Copy from", "Rename", "Delete", "Reset profile", "Export", "Import", "Realm-Tester" }) do
		assert(has(list, label), "Profiles has " .. label)
	end
	local host = K.Widgets.DialogHost()

	W.Click(rowFor(ns, "New profile").controls.button.buttons[1])
	settle(env)
	assert(host:IsShown(), "New asks for a name")
	host.editBox:SetText("Raid")
	host.editBox:GetScript("OnEnterPressed")(host.editBox)
	settle(env)
	assert(K.Store.ProfileName() == "Raid", "the new profile is created and used")
	assert(rowFor(ns, "Profile").controls.dropdown:GetValue() == "Raid", "the page refreshes with the new profile")

	W.Click(rowFor(ns, "Export").controls.button.buttons[1])
	settle(env)
	assert(host:IsShown() and host.editBox:GetText():find("^KSUI1:"), "Export shows the profile string")
	W.Key(host, "ESCAPE")
	settle(env)

	W.Click(rowFor(ns, "Import").controls.button.buttons[1])
	settle(env)
	host.editBox:SetText("not a profile")
	host.editBox:GetScript("OnEnterPressed")(host.editBox)
	settle(env)
	assert(host:IsShown() and W.Texts(host)[2]:find("KSUI1:", 1, true), "a bad string explains why it was refused")
	W.Key(host, "ESCAPE")
	settle(env)

	local copy = rowFor(ns, "Copy from").controls.dropdown
	assert(copy:GetValue() == "", "the copy picker starts on its placeholder")
	copy:SetValue("Default")
	settle(env)
	assert(host:IsShown(), "copying asks first")
	W.Key(host, "ESCAPE")
	settle(env)
end

-- About, Reset and Layout Mode buttons ----------------------------------------------------------------

do
	K.Options.Open("About")
	settle(env)
	assert(has(labels(ns), "Smoke checks"))
	assert(ns.Window.Parts().resetButton:IsEnabled() == false, "About has nothing to reset")

	K.Options.Open("UnitFrames")
	settle(env)
	K.Options.Write("UnitFrames", "enabled", true)
	K.Options.Write("UnitFrames", "size", 33)
	K.Options.Write("UnitFrames", "style", "glass")
	settle(env)
	assert(ns.Window.Parts().resetButton:IsEnabled() == true)
	W.Click(ns.Window.Parts().resetButton)
	settle(env)
	local host = K.Widgets.DialogHost()
	assert(host:IsShown(), "Reset asks first")
	host.visibleButtons[#host.visibleButtons]:GetScript("OnClick")(host.visibleButtons[#host.visibleButtons], "LeftButton")
	settle(env)
	assert(K.Store.Module("UnitFrames").size == 20 and K.Store.Module("UnitFrames").style == "solid", "Reset puts the page's settings back")
	assert(K.Modules.IsEnabled("UnitFrames") == true, "Reset leaves the module switched on")

	env.SetCombat(true)
	assert(ns.Window.Parts().layoutButton:IsEnabled() == false, "Layout Mode is disabled in combat")
	env.SetCombat(false)
	assert(ns.Window.Parts().layoutButton:IsEnabled() == true)
	W.Click(ns.Window.Parts().layoutButton)
	settle(env)
	assert(layout.entered == 1, "the Layout Mode button enters Layout Mode")
	assert(not ns.Window.Frame():IsShown(), "the window closes for Layout Mode")
end

-- Escape and the /kstyle toggle -----------------------------------------------------------------------

do
	K.Options.Open()
	settle(env)
	local win = ns.Window.Frame()
	assert(win:IsShown())
	W.Key(win, "ESCAPE")
	settle(env)
	assert(not win:IsShown(), "Escape closes the window through its own key handler")
	assert(env.UISpecialFrames == nil, "the window does not use UISpecialFrames")
	K.Options.Open()
	settle(env)
	K.Options.Open()
	settle(env)
	assert(not win:IsShown(), "/kstyle closes an open window")
end

assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))

-- Without a Layout service the window still opens and says so on the Elements page -------------------

do
	local env2, K2, ns2 = boot(false)
	assert(K2.Options.Open("Elements") == true)
	settle(env2)
	local explained = false
	for _, label in ipairs(labels(ns2)) do
		explained = explained or label:find("Layout Mode is not available", 1, true) ~= nil
	end
	assert(explained, "the Elements page explains the missing Layout service")
	W.Click(ns2.Window.Parts().layoutButton)
	assert(W.CoreEnv.Printed(env2, "Layout Mode is not available"), "the Layout Mode button says it is not available")
	assert(#env2._errors == 0, "errors: " .. table.concat(env2._errors, "\n"))
end

print("options window ok")
