-- gallery_widgets.lua: every control of the widget kit in a representative state, each cropped as one frame of the
-- gallery: text buttons at rest, under the mouse, primary and disabled; edit boxes empty and focused; a dropdown
-- closed; a scroll list, a text area, a slider, toggles, tabs, colour swatches, the font picker, the texture
-- picker open on the one shared menu, the kit tooltip and a dialog with an edit box and a reload button.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	if w then
		frame:SetSize(w, h)
	end
end

return Common.Run(function()
	local W = dofile("Tools/regression/widget_env.lua")
	local env, K = W.New(Common.ScreenOpts({ saved = Gallery.Saved({}), setup = Gallery.Setup }))
	local root = K.Scale.Root()
	local Widgets = K.Widgets
	local frames = Gallery.Frames()
	local hover = {}

	-- The controls sit on a titled window, as they do in the settings window, so each crop shows the glass they
	-- sit on. Positions below are inside this window.
	local window = Widgets.Panel(root, { title = "Kit controls", width = 790, height = 800 })
	at(window, 40, 40, 790, 800)
	frames:Add(env, window, {
		name = "widgets_window", title = "Titled panel", grade = "window", reference = "chat",
		caption = "Widgets.Panel with a title bar: the window grade, the chrome every KstyleUI window (options, setup, bags, dialogs, copy window) is built on, holding the kit controls below.",
		match = "Fill, the dark outer and light inner line, the 12-unit chamfer and the drop shadow as the mockup's chat panel; the upper-case title has no rule under it, as the kit sheet.",
	})
	root = window

	-- Text buttons: rest, hover, primary, disabled, and the close button.
	local buttons = env.CreateFrame("Frame", nil, root)
	at(buttons, 30, 60, 330, 90)
	local rest = Widgets.Button(buttons, { text = "Cancel" })
	at(rest, 0, 0)
	local hovered = Widgets.Button(buttons, { text = "Apply" })
	at(hovered, 110, 0)
	W.Enter(hovered)
	hover[hovered] = true
	local primary = Widgets.Button(buttons, { text = "Accept", primary = true })
	at(primary, 220, 0)
	local disabled = Widgets.Button(buttons, { text = "Disabled" })
	at(disabled, 0, 46)
	disabled:Disable()
	local close = Widgets.CloseButton(buttons, function() end)
	at(close, 130, 50)
	local reload = Widgets.ReloadButton(buttons, {})
	at(reload, 220, 46)
	frames:Add(env, buttons, {
		name = "widgets_buttons", title = "Kit buttons", grade = "button", reference = "datastrip",
		caption = "Widgets.Button at rest, under the mouse, primary and disabled, the close glyph and the reload button, on the button grade's body with the edgeInner hairline; hover lights the hairline to the accent.",
		match = "Body #101214 and a one-border light line, as the mockup's data strip pill and the N plate; the mockup has no text buttons, so the rim stays neutral grey instead of the action buttons' class-colour rim.",
	})

	-- Edit boxes: with its placeholder, and focused with text.
	local inputs = env.CreateFrame("Frame", nil, root)
	at(inputs, 30, 180, 330, 32)
	local empty = Widgets.EditBox(inputs, { width = 150, placeholder = "Search settings..." })
	at(empty, 0, 0)
	local focused = Widgets.EditBox(inputs, { width = 150, text = "Valerin" })
	at(focused, 170, 0)
	focused:SetFocus()
	focused:GetScript("OnEditFocusGained")(focused)
	frames:Add(env, inputs, {
		name = "widgets_editbox", title = "Edit boxes", grade = "button", reference = "datastrip",
		caption = "Widgets.EditBox empty with its placeholder, and focused with text: the button body with the hairline in the accent while the box has focus.",
		match = "Body and faint edge as the mockup's dark pills; the accent focus line is the kit's own state.",
	})

	-- Dropdown closed, and a second one open on the shared menu.
	local closed = Widgets.Dropdown(root, {
		width = 200, value = "glass",
		options = { { value = "glass", label = "Glass" }, { value = "soft", label = "Soft" }, { value = "flat", label = "Flat" } },
	})
	at(closed, 30, 250)
	frames:Add(env, closed, {
		name = "widgets_dropdown", title = "Dropdown", grade = "button", reference = "datastrip",
		caption = "Widgets.Dropdown closed: the chosen label and a chevron on the button body.",
		match = "Body #101214 with the one-border light line, as the mockup's data strip.",
	})

	-- Colour swatches.
	local swatches = env.CreateFrame("Frame", nil, root)
	at(swatches, 30, 310, 130, 28)
	local a = Widgets.ColorSwatch(swatches, { color = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] } })
	at(a, 0, 0)
	local b = Widgets.ColorSwatch(swatches, { color = { r = 0.31, g = 0.76, b = 1 }, hasAlpha = true })
	at(b, 36, 0)
	local c = Widgets.ColorSwatch(swatches, { color = { r = 0.9, g = 0.23, b = 0.25 } })
	at(c, 72, 0)
	frames:Add(env, swatches, {
		name = "widgets_swatch", title = "Colour swatches", grade = "button", reference = "bufficons",
		caption = "Widgets.ColorSwatch: a chamfered tile on the button body filled with the colour, the hairline at edgeInner.",
		match = "Tile body and neutral one-border rim as the mockup's buff icons; the colour fill replaces the icon.",
	})

	-- Toggles and slider.
	local switches = env.CreateFrame("Frame", nil, root)
	at(switches, 30, 370, 330, 40)
	local on = Widgets.Toggle(switches, { value = true, label = "Panel shadows" })
	at(on, 0, 0)
	local off = Widgets.Toggle(switches, { value = false, label = "Sounds" })
	at(off, 180, 0)
	frames:Add(env, switches, {
		name = "widgets_toggle", title = "Toggles", grade = "bar", reference = "xp",
		caption = "Widgets.Toggle on and off: the pill track filled surface, its border white 40% off and the accent on, with the round knob.",
		match = "A pill, not a chamfered panel: its track is the bar grade's surface fill with a faint line, as the mockup's experience bar track; the mockup draws no switches.",
	})
	local slider = Widgets.Slider(root, { min = 0.5, max = 1, step = 0.01, value = 0.97, width = 300 })
	at(slider, 30, 450)
	frames:Add(env, slider, {
		name = "widgets_slider", title = "Slider", grade = "bar", reference = "xp",
		caption = "Widgets.Slider: a 4-unit pill track with the accent fill up to a ringed knob, the value above and the range below.",
		match = "Track and accent fill as the mockup's experience bar; the mockup draws no sliders.",
	})

	-- Tabs.
	local tabs = Widgets.Tabs(root, {
		width = 360, height = 32, value = "general",
		tabs = { { value = "general", label = "General" }, { value = "layout", label = "Layout" }, { value = "profiles", label = "Profiles" }, { value = "about", label = "About" } },
	})
	at(tabs, 400, 60)
	frames:Add(env, tabs, {
		name = "widgets_tabs", title = "Tabs", grade = "button", reference = "chat",
		caption = "Widgets.Tabs: a strip of upper-case tabs on the button body, the selected tab's text white with an accent underline and glow.",
		match = "The mockup's chat tabs sit on the chat glass with the selected tab underlined in the class colour; the kit strip draws the same underline on the dark button body.",
	})

	-- Scroll list.
	local items = {}
	for i, label in ipairs({ "Unit frames", "Action bars", "Cooldowns", "Auras", "Bags", "Chat", "Minimap", "Tooltips", "Data bars", "Meters", "Nameplates", "Combat text" }) do
		items[i] = { label = label }
	end
	local list = Widgets.ScrollList(root, { width = 300, height = 190, rowHeight = 26 })
	at(list, 400, 120)
	list:SetData(items)
	frames:Add(env, list, {
		name = "widgets_scrolllist", title = "Scroll list", grade = "panel", reference = "chat",
		caption = "Widgets.ScrollList: virtualised rows clipped to the view, with a 3-unit scroll bar; the list draws no chrome of its own and sits on its window's glass.",
		match = "Rows and bar only; the glass behind it is the window grade of the panel it sits in, as the mockup's chat lines sit on the chat glass.",
	})

	-- Text area.
	local area = Widgets.TextArea(root, { width = 300, height = 150, text = "[14:31] You receive loot: [Crocolisk Hide] x2\n[14:31] You gain 168 experience.\n[14:31] You receive loot: [Rugged Hide]\n[14:32] [1. General] Riverglades: Anyone for croc hunt?\n[14:32] [1. General] Thargor: LFM tank for Razorfen Kraul", readOnly = true })
	at(area, 400, 340)
	frames:Add(env, area, {
		name = "widgets_textarea", title = "Text area", grade = "button", reference = "chat",
		caption = "Widgets.TextArea read-only: the chat copy log in a clipped scroll frame on the button body, with the slim scroll bar.",
		match = "Body #101214 with the one-border light line; the mockup's nearest frame is the chat panel, whose glass is the lighter surface tone, so the text area reads one step darker as an input should.",
	})

	-- Font and texture pickers; the texture picker open on the one shared menu, with its samples.
	local font = Widgets.FontPicker(root, { width = 300, value = (K.Tokens.FontPath("SourceSans3Semibold")) })
	at(font, 400, 520)
	frames:Add(env, font, {
		name = "widgets_fontpicker", title = "Font picker", grade = "button", reference = "datastrip",
		caption = "Widgets.FontPicker: a dropdown over the kit's fonts, each row drawn in its face.",
		match = "The dropdown's body and line, as the mockup's data strip pill.",
	})
	local texture = Widgets.TexturePicker(root, { width = 300, value = K.Tokens.MediaList("statusbar")[1].path })
	at(texture, 400, 580)
	texture:Open()
	local menu = Widgets.DropdownMenu()
	assert(menu:IsShown(), "the menu opened")
	local menuBox = env.CreateFrame("Frame", nil, root)
	at(menuBox, 400, 580, 300, 120)
	frames:Add(env, menuBox, {
		name = "widgets_dropdown_menu", title = "Dropdown menu", grade = "panel", reference = "player",
		caption = "Widgets.TexturePicker open on the shared dropdown menu: the box's hairline in the accent, and below it a glass panel listing Glass, Soft and Flat with an accent-tinted sample of each, the chosen row marked by an accent bar and wash.",
		match = "Menu fill, two-line edge and drop shadow as the mockup's glass; its chamfer is the 3.5-unit tile, smaller than the unit frame's 8, because it matches the box it hangs from.",
	})

	-- The kit tooltip, on an invisible owner, beside the window.
	root = K.Scale.Root()
	local owner = env.CreateFrame("Frame", nil, root)
	owner:SetSize(1, 1)
	at(owner, 900, 40, 1, 1)
	local tip = Widgets.Tooltip()
	tip:SetOwner(owner, "RIGHT")
	tip:SetIcon(Hud.ICONS.mortalStrike, K.Tokens.Color("rare"))
	tip:AddTitle("Vanquisher's Blade", K.Tokens.Color("rare"))
	tip:AddCaption("Rare", K.Tokens.Color("rare"))
	tip:AddLine("Item Level 44")
	tip:AddLine("Two-Handed Sword")
	tip:AddDoubleLine("Physical Damage", "96 - 145")
	tip:AddDoubleLine("Attack Speed", "3.4")
	tip:AddRule()
	tip:AddLine("+18 Strength", K.Tokens.Color("accent"))
	tip:AddLine("+12 Stamina", K.Tokens.Color("accent"))
	tip:AddDivider()
	tip:AddLine("Durability 100 / 100")
	tip:AddLine("Requires Level 40")
	tip:Show()
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", root, "TOPLEFT", 900, -40)
	frames:Add(env, tip, {
		name = "widgets_tooltip", title = "Kit tooltip", grade = "panel", reference = "player",
		caption = "Widgets.Tooltip for KstyleUI's own controls: a glass panel with the two-line edge and shadow, a rare item's icon on a button tile with its rim and glow in the quality colour, and the accent rule.",
		match = "Fill, edge and shadow as the mockup's unit frame glass at the 8-unit panel chamfer; the icon tile matches the mockup's buff icons.",
	})

	-- A dialog: the reload prompt's shape with an edit box, at its default position.
	Widgets.Popup({
		title = "Import profile",
		text = "Paste a profile string. The current profile is replaced, and the interface reloads.",
		editBox = { placeholder = "KstyleUI1..." },
		buttons = { { label = "Cancel" }, { label = "Reload now", primary = true, reload = true } },
	})
	local host = Widgets.DialogHost()
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", root, "TOPLEFT", 900, -300)
	frames:Add(env, host, {
		name = "widgets_dialog", title = "Dialog", grade = "window", reference = "chat",
		caption = "Widgets.Popup in the shared dialog host: a titled glass window with body text, an edit box on the button body, and Cancel and Reload now buttons.",
		match = "Window grade: the chat panel's fill, two-line edge, 12-unit chamfer and drop shadow.",
	})

	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
	return frames:Finish(Scene.Build(env, { hover = hover }), env, K, "gallery widgets")
end)
