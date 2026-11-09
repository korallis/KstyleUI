-- gallery_widgets.lua: every control of the widget kit in a representative state, each cropped as one frame of the
-- gallery: text buttons at rest, under the mouse, primary and disabled; edit boxes empty and focused; a dropdown
-- closed; a scroll list, a text area, a slider, toggles, tabs, colour swatches, the font picker, the texture
-- picker open on the one shared menu, the kit tooltip and a dialog with an edit box and a reload button; and the
-- Lumen pieces: a rail with section caps and party lines, a card of sockets in each state, and pill bars.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

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
		match = "Lumen window grade: the deep tint, the baked frost, the rim lit along the top, 14-unit corners, gilt tips on two corners and the soft drop shadow, as the mockup's rails; the Cinzel title has no rule under it.",
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
		caption = "Widgets.ColorSwatch: a rounded tile on the button body filled with the colour, the rim at edgeInner.",
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
		match = "A pill: its track is the bar grade's surface fill with a faint line, as the mockup's .bar track; the mockup draws no switches.",
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
		match = "A tile with the soft shadow: the deep fill, the rim and 8-unit corners, matching the box it hangs from.",
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
		caption = "Widgets.Tooltip for KstyleUI's own controls: a Lumen card with its frost, rim and shadow, a rare item's icon in a socket with its rim and glow in the quality colour, and the accent rule.",
		match = "The card grade, as the mockup's tooltip card; the icon socket matches the mockup's .ab sockets.",
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
		match = "Lumen window grade: the frost, the rim, 14-unit corners, gilt tips and the soft drop shadow.",
	})

	-- Lumen: a rail on the right, as the mockup's story rail, with section caps and party lines on pill bars.
	local screen = K.Scale.Root()
	local rail = env.CreateFrame("Frame", nil, screen)
	at(rail, 1325, 40, 318, 400)
	rail.chrome = Widgets.Chrome(rail, { shape = "rail" })
	local pad = K.Tokens.Size("railPadding")
	local function cap(parent, text, count, y, width)
		local section = Widgets.SectionCap(parent, { text = text, count = count, width = (width or 318) - 2 * pad })
		at(section, pad, y)
		return section
	end
	cap(rail, "The Path", "Step 82", pad)
	local step = Widgets.Text(rail, "heading", "textEmphasis")
	step:SetPoint("TOPLEFT", rail, "TOPLEFT", pad, -(pad + 26))
	Widgets.SetText(step, "Durotar, 6 to 10")
	local line = Widgets.Text(rail, "body", "textEmphasis")
	line:SetPoint("TOPLEFT", rail, "TOPLEFT", pad, -(pad + 56))
	line:SetText("Loot Taillasher Eggs on the shore")
	local sub = Widgets.Text(rail, "body", "muted")
	sub:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -3)
	sub:SetText("Guarded by Bloodtalon Taillashers, 0 / 3")
	cap(rail, "Party", 3, 150)
	local party = {
		{ "Leduc", "Paladin 9", { 0.96, 0.55, 0.73 }, 0.92 },
		{ "Trolly", "Priest 8", { 0.91, 0.93, 0.96 }, 1 },
		{ "Garrosh", "Warrior 10", Common.WARRIOR, 0.41 },
	}
	for i, member in ipairs(party) do
		local y = 150 + 30 + (i - 1) * 44
		local name = Widgets.Text(rail, "body", "textEmphasis")
		name:SetPoint("TOPLEFT", rail, "TOPLEFT", pad, -y)
		name:SetText(member[1])
		local class = Widgets.Text(rail, "body", "muted")
		class:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -pad, -y)
		class:SetText(member[2])
		local bar = Widgets.StatusBar(rail, { width = 318 - 2 * pad, height = 6, border = true, min = 0, max = 1, value = member[4] })
		at(bar, pad, y + 20)
		bar:SetBarColor(member[3][1], member[3][2], member[3][3], 1)
	end
	cap(rail, "Quests", 15, 330)
	local quest = Widgets.Text(rail, "body", "quest")
	quest:SetPoint("TOPLEFT", rail, "TOPLEFT", pad, -360)
	quest:SetText("Threat from Below")
	frames:Add(env, rail, {
		name = "widgets_rail", title = "Rail", grade = "window", reference = "tracker",
		caption = "Widgets.Chrome's rail grade with Widgets.SectionCap heads: the deep tint, the baked frost, the rim lit along the top, 14-unit corners and gilt filament tips on the top left and bottom right; section caps (gem, tracked Cinzel caption, fading gilt rule, count) over Alegreya Sans rows and pill bars.",
		match = "The mockup's left rail (.lg) and its .capline heads.",
	})

	-- A card of sockets: rest, hover, pressed, on cooldown, a proc's gold rim, unusable and empty.
	local card = env.CreateFrame("Frame", nil, screen)
	at(card, 900, 520, 400, 120)
	card.chrome = Widgets.Chrome(card, { shape = "card" })
	cap(card, "Blessings", 7, pad, 400)
	local icons = { 132355, 133633, 135349, 135274, 134939, 134414, 134237 }
	local states = { "rest", "hover", "pressed", "cooldown", "proc", "unusable", "empty" }
	for i, state in ipairs(states) do
		local socket = Widgets.IconButton(card, { size = 38, icon = state ~= "empty" and icons[i] or nil })
		at(socket, pad + (i - 1) * (38 + K.Tokens.Size("socketGap")), 52)
		socket:SetHotkey(tostring(i))
		if state == "hover" then
			hover[socket] = true
			W.Enter(socket)
		elseif state == "pressed" then
			W.Down(socket)
		elseif state == "cooldown" then
			socket:SetCooldown(env._time and env._time - 4 or 0, 12)
		elseif state == "proc" then
			socket:SetProc(true)
		elseif state == "unusable" then
			socket:SetUsable(false)
		elseif state == "empty" then
			socket:SetAlpha(0.35)
		end
	end
	frames:Add(env, card, {
		name = "widgets_sockets", title = "Card and sockets", grade = "panel", reference = "actionbars",
		caption = "Widgets.Chrome's card grade (no gilt) holding Widgets.IconButton sockets: the dark crystal body, the rim, the icon masked to 8-unit corners, and the gold rim and glow only on the proc; rest, hover, pressed, cooldown, proc, unusable and empty.",
		match = "The mockup's .ab sockets and .ab.proc.",
	})

	-- Pill bars: the bar grade's track with the fill rounded at both ends, its top sheen and its own glow.
	local bars = env.CreateFrame("Frame", nil, screen)
	at(bars, 900, 680, 400, 90)
	local specs = { { 12, 0.76, Common.WARRIOR }, { 5, 0.45, { 0.36, 0.66, 1 } }, { 10, 0.08, { 0.89, 0.32, 0.31 } } }
	for i, spec in ipairs(specs) do
		local bar = Widgets.StatusBar(bars, { width = 380, height = spec[1], border = true, min = 0, max = 1, value = spec[2] })
		at(bar, 10, 10 + (i - 1) * 26)
		bar:SetBarColor(spec[3][1], spec[3][2], spec[3][3], 1)
	end
	frames:Add(env, bars, {
		name = "widgets_pillbars", title = "Pill bars", grade = "bar", reference = "xp",
		caption = "Widgets.StatusBar with a border: the bar grade's pill track, the fill rounded at both ends by its cap masks, a top sheen and a soft glow of its own colour; health at 12 units, power at 5 and a nearly empty bar at 10.",
		match = "The mockup's .bar and .bar i.",
	})

	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
	return frames:Finish(Gallery.Build(env, { hover = hover }), env, K, "gallery widgets")
end)
