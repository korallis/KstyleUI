-- test-skins-restedxp-leases.lua: the state matrix for the RestedXP skin's leases. A lease is KstyleUI's look lent to a widget RestedXP is showing that AceGUI or another library owns: a label of KstyleUI's own over the widget's hushed text, a kit button, edit box or scroll bar over its control, and the widget's own font swapped for the one drawn so the library measures what the player sees. Six review rounds on pull request #244 each found two or three more states in which a lease went wrong, so this test enumerates them: every leased window and dialog, crossed with every event the reviews found, in two orders, checking the same invariants after each step.
--
-- The surfaces: the leveling report (its Labels and Headings), the feedback form and the export box (title, edit label, edit box, Accept, Close and the scroll bars), the guide importer's list of guides (its chrome, arrow and value) and the guide configurator's page (its Labels and Heading).
-- The events: KstyleUI's text size changed while open; hidden and shown again; given back to AceGUI's pool and handed to another owner; made narrower and wider; a control disabled and enabled; RestedXP redrawing its theme, open and hidden.
-- The invariants: (1) no label is shorter than its words; (2) no label or control of KstyleUI's shows while its source is hidden, or after the lease ended; (3) a widget RestedXP has given back carries what it would carry had KstyleUI never run, whatever its next owner does with it; (4) nothing raised, nothing logged as failed, and nothing written or scripted onto a RestedXP or library object.
--
-- Invariant 3 is checked against a second world: the same RestedXP, driven through the same steps, with the Skins module never enabled. After every give-back, and after each thing the next owner does, every object RestedXP or AceGUI made under the widget is compared with its twin there: shown, alpha, size, points, font, font object, words, colours, justification, enabled. A hook KstyleUI left on the widget cannot be taken off (the game has no call for it), so "none of ours" means that the hooks do nothing once the lease has ended: if one acted, the twin would differ. SetScript, Hide and SetParent from outside RestedXP's own code fail the fake's seal (rxp.fake.check).
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local W = S.W

-- Methods KstyleUI may replace on RestedXP's objects with hooksecurefunc.
local HOOKED = { SetAlpha = true, SetChecked = true, SetFont = true, SetFontObject = true, SetText = true, Show = true, Hide = true, SetShown = true, SetStatusBarColor = true, UpdateVisuals = true, SetMinMaxValues = true, DoLayout = true, SetScale = true }
local LONG = "Copy this text and paste it where the guide's author asked for it, then close this window"

local failures, checks, where = {}, 0, ""
local function Check(ok, message)
	checks = checks + 1
	if not ok then
		failures[#failures + 1] = where .. ": " .. message
	end
	return ok
end

-- World(skinned) -> one game with RestedXP in it, with KstyleUI's skins running or never enabled.
local function World(skinned)
	local rxp
	local env, K, ns = S.New({ setup = function(e)
		rxp = Fake.Install(e, { v2 = true })
	end })
	if skinned then
		K.Modules.Enable("Skins")
	end
	env.RunTimers()
	env._textWidth = function(value, _, size) return #value * size * 0.5 end
	return { env = env, K = K, ns = ns, rxp = rxp, fake = rxp.fake, skinned = skinned }
end

local function Trust(w, fn)
	return w.fake.trust(fn)()
end

local function TextSize(w, size)
	w.K.Options.Write("Skins", "text.size", size)
	w.env.RunTimers()
end

-- Holder(text) -> the frame of KstyleUI's that carries the label drawn over a leased text.
local function Holder(text)
	for _, child in ipairs({ text:GetParent():GetChildren() }) do
		if child.label and child:GetNumPoints() > 0 and select(2, child:GetPoint(1)) == text then
			return child
		end
	end
end

-- Proxy(w, source, kind) -> the kit control drawn over a leased control.
local function Proxy(w, source, kind)
	for _, child in ipairs({ source:GetChildren() }) do
		if w.K.Skin.IsSkinned(child, kind) then
			return child
		end
	end
end

local function Near(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-6
	end
	return a == b
end

local function Get(object, method, ...)
	local fn = object[method]
	if type(fn) ~= "function" then
		return {}
	end
	return { fn(object, ...) }
end

-- Carried(w, roots, skip) -> what every object RestedXP or a library made under the roots carries, in the order it
-- was made. skip(object, field) leaves one field of one object out.
local FIELDS = { "GetObjectType", "IsShown", "GetAlpha", "GetWidth", "GetHeight", "GetFont", "GetText", "GetTextColor", "GetVertexColor", "GetJustifyH", "GetJustifyV", "IsEnabled", "IsMouseEnabled", "GetTexture", "GetNumPoints" }
local function Carried(w, roots, skip)
	local list = {}
	local function Add(object)
		local record = { object = object }
		for _, field in ipairs(FIELDS) do
			if not (skip and skip(object, field)) then
				record[field] = Get(object, field)
			end
		end
		local font = Get(object, "GetFontObject")[1]
		record.FontObject = font and { font:GetFont() } or { "none" }
		record.Points = {}
		for i = 1, (object.GetNumPoints and object:GetNumPoints() or 0) do
			local point, _, onPoint, x, y = object:GetPoint(i)
			record.Points[#record.Points + 1] = point
			record.Points[#record.Points + 1] = onPoint
			record.Points[#record.Points + 1] = x
			record.Points[#record.Points + 1] = y
		end
		list[#list + 1] = record
	end
	local function Walk(frame)
		Add(frame)
		for _, region in ipairs({ frame:GetRegions() }) do
			if w.fake.owns(region) then
				Add(region)
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			if w.fake.owns(child) then
				Walk(child)
			end
		end
	end
	for _, frame in ipairs(roots) do
		Walk(frame)
	end
	return list
end

-- Same(s, p, surface, what) compares what the surface's widgets carry in the skinned world with their twins.
local function Same(s, p, surface, what)
	local ours, theirs = Carried(s, surface.roots(s), surface.skip and function(o, f) return surface.skip(s, o, f) end), Carried(p, surface.roots(p), surface.skip and function(o, f) return surface.skip(p, o, f) end)
	if not Check(#ours == #theirs, what .. ": " .. #ours .. " objects of RestedXP's under the widget, " .. #theirs .. " without KstyleUI") then
		return
	end
	for i, record in ipairs(ours) do
		local twin = theirs[i]
		for field, values in pairs(record) do
			if field ~= "object" and twin[field] then
				local same = #values == #twin[field]
				for n = 1, #values do
					same = same and Near(values[n], twin[field][n])
				end
				if not same then
					local a, b = {}, {}
					for n = 1, math.max(#values, #twin[field]) do
						a[n], b[n] = tostring(values[n]), tostring(twin[field][n])
					end
					Check(false, what .. ": object " .. i .. " (" .. tostring(record.GetObjectType and record.GetObjectType[1]) .. " " .. tostring(record.GetText and record.GetText[1] or "") .. ") " .. field .. " is " .. table.concat(a, " ") .. ", without KstyleUI " .. table.concat(b, " "))
				end
			end
		end
	end
	Check(true, what)
end

local function Clean(w, what)
	local ok, err = pcall(w.fake.check, HOOKED)
	Check(ok, what .. ": " .. tostring(err))
	Check(#w.env._errors == 0, what .. ": raised " .. tostring(w.env._errors[1]))
	local failed = S.Logged(w.env, "could not be restyled")
	Check(not failed, what .. ": " .. tostring(failed))
end

local function Coloured(text, r, g, b)
	local cr, cg, cb = text:GetTextColor()
	return W.Near(cr, r) and W.Near(cg, g) and W.Near(cb, b)
end

-- Leased(s, surface, what): the invariants while RestedXP shows the surface.
local function Leased(s, surface, what)
	for _, item in ipairs(surface.texts(s)) do
		local text, name = item.text, what .. ": " .. item.name
		local holder = Holder(text)
		if Check(holder ~= nil, name .. " has a label of KstyleUI's over it") then
			local shown = text:IsShown()
			Check(holder:IsShown() == shown, name .. "'s label shows as its source does (source " .. tostring(shown) .. ", label " .. tostring(holder:IsShown()) .. ")")
			Check(text:IsVisible() or not holder:IsVisible(), name .. "'s label is not on screen while its source is not")
			Check(text:GetAlpha() == 0, name .. " is hushed under its label")
			local words = text:GetText() or ""
			Check((holder.label:GetText() or "") == (item.caps and s.K.Locale.Upper(words) or words), name .. "'s label says the source's words, got " .. tostring(holder.label:GetText()))
			if item.box and shown then
				local tall, box = holder.label:GetStringHeight(), item.box()
				Check(type(tall) == "number" and type(box) == "number" and box + 1e-6 >= tall, name .. " is as tall as its words: " .. tostring(box) .. " for " .. tostring(tall) .. " in " .. tostring(holder.label:GetNumLines()) .. " lines")
			end
		end
	end
	for _, item in ipairs(surface.controls and surface.controls(s) or {}) do
		local name = what .. ": " .. item.name
		local proxy = Proxy(s, item.source, item.kind)
		if Check(proxy ~= nil and proxy:IsShown(), name .. " has a kit " .. item.kind .. " over it") and item.kind == "Button" then
			local enabled = item.source:IsEnabled()
			Check(proxy:IsEnabled() == enabled, name .. "'s kit button is enabled as its source is (" .. tostring(enabled) .. ")")
			local words = item.source:GetFontString()
			local holder = words and Holder(words)
			if holder then
				Check(Coloured(holder.label, s.K.Tokens.Color(enabled and "text" or "textDisabled")), name .. "'s label is the kit's " .. (enabled and "text" or "disabled text") .. " colour")
			end
		end
	end
	Clean(s, what)
end

-- Ended(s, p, surface, was, what): the invariants once RestedXP has hidden the surface or given it back.
local function Ended(s, p, surface, was, what)
	for _, item in ipairs(was.texts) do
		local holder = Holder(item.text)
		Check(not holder or not holder:IsShown(), what .. ": " .. item.name .. "'s label is hidden")
	end
	for _, item in ipairs(was.controls) do
		local proxy = Proxy(s, item.source, item.kind)
		Check(not proxy or not proxy:IsShown(), what .. ": " .. item.name .. "'s kit " .. item.kind .. " is hidden")
	end
	Same(s, p, surface, what)
	Clean(s, what)
end

local function Was(s, surface)
	return { texts = surface.texts(s), controls = surface.controls and surface.controls(s) or {} }
end

-- Labels(container, list) lists the leased AceGUI Labels and Headings under a container.
local function Labels(container, list)
	list = list or {}
	for _, child in ipairs(container.children or {}) do
		if child.type == "Label" then
			list[#list + 1] = { name = "label '" .. tostring(child.label:GetText()) .. "'", text = child.label, widget = child, box = function() return child.frame:GetHeight() end }
		elseif child.type == "Heading" then
			list[#list + 1] = { name = "heading '" .. tostring(child.label:GetText()) .. "'", text = child.label, widget = child, caps = true }
		end
		Labels(child, list)
	end
	return list
end

local function Frames(items)
	local roots = {}
	for _, item in ipairs(items) do
		roots[#roots + 1] = item.widget.frame
	end
	return roots
end

local function Relaid(w, text)
	local holder = w.skinned and Holder(text)
	local resized = holder and holder:GetScript("OnSizeChanged")
	if resized then
		resized(holder)
	end
end

-- Dialog(w) -> the parts of the AceGUI frame the feedback form or the export box shows.
local function Dialog(w, frame)
	local widget = frame.obj
	local child = widget.children[1]
	local scroll = child and child.type == "ScrollFrame" and child or nil
	local edit = scroll and scroll.children[1] or child
	local close
	for _, button in ipairs({ frame:GetChildren() }) do
		if button.obj == widget and button:GetObjectType() == "Button" and button ~= widget.statustext:GetParent() and w.fake.owns(button) then
			close = button
		end
	end
	return widget, edit, scroll, close
end

local function DialogTexts(w, frame)
	local widget, edit, _, close = Dialog(w, frame)
	local list = {
		{ name = "title", text = widget.titletext, caps = true },
		{ name = "close label", text = close:GetFontString() },
	}
	if edit then
		list[#list + 1] = { name = "edit label", text = edit.label, box = function() return edit.label:GetHeight() end }
		list[#list + 1] = { name = "accept label", text = edit.button:GetFontString() }
	end
	return list
end

local function DialogControls(w, frame)
	local _, edit, scroll, close = Dialog(w, frame)
	local list = { { name = "close", source = close, kind = "Button" } }
	if edit then
		list[#list + 1] = { name = "edit box", source = edit.editBox, kind = "EditBox" }
		list[#list + 1] = { name = "accept", source = edit.button, kind = "Button" }
		list[#list + 1] = { name = "edit scroll bar", source = edit.scrollBar, kind = "ScrollBar" }
	end
	if scroll then
		list[#list + 1] = { name = "scroll bar", source = scroll.scrollbar, kind = "ScrollBar" }
	end
	return list
end

-- AceGUI's Fill layout gives the edit box the dialog's width (AceGUI-3.0.lua); its label hangs across its top.
local function PlaceEdit(w, frame, width)
	local _, edit = Dialog(w, frame)
	Trust(w, function()
		edit.frame:ClearAllPoints()
		edit.frame:SetPoint("TOPLEFT", w.env.UIParent, "TOPLEFT", 40, -40)
		edit.frame:SetSize(width, 160)
	end)
	Relaid(w, edit.label)
end

local SURFACES = {}

SURFACES[#SURFACES + 1] = {
	name = "leveling report",
	open = function(w)
		if not w.report then
			local attachment = w.env.CreateFrame("Frame", "InspectFrame", w.env.UIParent)
			w.rxp.tracker:CreateGui(attachment, "Another player")
			w.report = w.rxp.tracker.ui.InspectFrame
			Trust(w, function()
				w.report.frame:SetSize(380, 420)
				w.report.scrollContainer.content:SetWidth(340)
				w.report.reachedContainer.data:SetText("Level 12 reached in 3 hours 41 minutes, which is 14 minutes faster than the guide's own pace for this bracket")
			end)
		end
		w.fake.open(w.report.frame)
	end,
	close = function(w) w.fake.close(w.report.frame) end,
	texts = function(w) return Labels(w.report.scrollContainer) end,
	roots = function(w) return Frames(Labels(w.report.scrollContainer)) end,
	-- RestedXP keeps the report's widgets for good and measures them again whenever it shows the report
	-- (LevelingTracker.lua 430-470 and 850), so a hidden Label's height is whatever its last measure made it.
	skip = function(_, object, field)
		return field == "GetHeight" and object:GetObjectType() == "Frame"
	end,
	resize = function(w, k)
		Trust(w, function()
			w.report.scrollContainer.content:SetWidth(340 * k)
			w.report.scrollContainer:DoLayout()
		end)
	end,
}

for _, spec in ipairs({
	{ "feedback form", "RESTEDXP_BUG_REPORT_WINDOW", function(w) w.rxp.comms.OpenBugReport({ arg1 = 12 }) end },
	{ "export box", "RESTEDXP_BRANDED_EXPORT", function(w) w.rxp.comms.OpenBrandedExport("Test export", LONG, "Export content", 480, 240, function() end) end },
}) do
	local key, pooled = spec[2], spec[2] == "RESTEDXP_BRANDED_EXPORT"
	local surface = {
		name = spec[1],
		open = function(w)
			spec[3](w)
			w[key] = w.env[key]
			w[key .. "_edit"] = select(2, Dialog(w, w[key]))
			PlaceEdit(w, w[key], 300)
		end,
		close = function(w) w.fake.close(w[key]) end,
		texts = function(w) return DialogTexts(w, w[key]) end,
		controls = function(w) return DialogControls(w, w[key]) end,
		-- Closing the export box releases its frame and its edit box, which AceGUI then parents to UIParent.
		roots = function(w) return { w[key], w[key .. "_edit"].frame } end,
		resize = function(w, k) PlaceEdit(w, w[key], 300 * k) end,
		buttons = function(w)
			local _, edit, _, close = Dialog(w, w[key])
			return { edit.button, close }
		end,
	}
	if pooled then
		-- Another addon takes the frame and the edit box RestedXP released from AceGUI's pool, uses them as its own
		-- and gives them back.
		-- Another addon takes only the edit box: RestedXP's next export gets its frame back from the pool with a new one.
		surface.lend = function(w, step)
			if step == "take" then
				local content = w.env.CreateFrame("Frame", nil, w.env.UIParent)
				content:SetSize(220, 200)
				w.lent = w.fake.acquireEdit({ content = content, children = {}, AddChild = function() end })
				assert(w.lent == w[key .. "_edit"], "the pool hands the export box's edit box to the next caller")
				Trust(w, function()
					w.lent.label:SetText("Their label")
					w.lent.frame:Show()
				end)
			elseif step == "use" then
				Trust(w, function()
					w.lent.label:SetText("Their own words, long enough to wrap onto a second line in a box this narrow")
					w.lent.editBox:SetText("Theirs")
					w.lent.button:Disable()
					w.lent.button:Enable()
					w.lent.label:Hide()
					w.lent.label:Show()
				end)
			else
				w.fake.aceRelease(w.lent)
				w.lent = nil
			end
		end
		surface.adopt = function(w, step)
			local frame, edit = w[key], w[key .. "_edit"]
			if step == "take" then
				local dialog = w.fake.acquireDialog()
				assert(dialog.frame == frame, "the pool hands the export box's frame to the next caller")
				assert(w.fake.acquireEdit(dialog) == edit, "and its edit box")
				Trust(w, function()
					dialog.titletext:SetText("Another addon")
					edit.label:SetText("Their own words, long enough to wrap onto a second line in a box this narrow")
					edit.label:Show()
					edit.editBox:SetText("Theirs")
					edit.button:Show()
				end)
				w.fake.open(frame)
			elseif step == "use" then
				Trust(w, function()
					edit.button:Disable()
					edit.label:SetFont("Fonts\\ARIALN.TTF", 14, "")
					edit.label:SetHeight(30)
					edit.label:Hide()
					edit.label:Show()
					edit.frame:SetWidth(180)
					edit.button:Enable()
					frame.obj.titletext:SetText("Another addon, again")
				end)
			else
				Trust(w, function() frame.obj:Release() end)
			end
		end
	end
	SURFACES[#SURFACES + 1] = surface
end

SURFACES[#SURFACES + 1] = {
	name = "importer's guide list",
	open = function(w)
		if not w.importer then
			w.rxp.guideImporter:Open()
			w.importer = w.rxp.guideImporter.widgets
			Trust(w, function() w.importer.currentGuides.text:SetText("6-10 Durotar") end)
		else
			w.fake.open(w.importer.import.frame)
		end
	end,
	close = function(w) w.fake.close(w.importer.import.frame) end,
	texts = function(w) return { { name = "value", text = w.importer.currentGuides.text } } end,
	controls = function(w)
		return {
			{ name = "list chrome", source = w.importer.currentGuides.frame, kind = "EditBox" },
			{ name = "list arrow", source = w.importer.currentGuides.button, kind = "Button" },
		}
	end,
	roots = function(w) return { w.importer.currentGuides.frame } end,
	buttons = function(w) return { w.importer.currentGuides.button } end,
	redraw = function(w) w.importer.import:UpdateSubTheme() end,
}

SURFACES[#SURFACES + 1] = {
	name = "guide configurator",
	open = function(w)
		local configurator = w.rxp.ui.v2.configurator
		if not w.configurator then
			w.configurator = configurator:CreateGuideConfigurator()
			Trust(w, function() w.configurator.scrollContainer.content:SetWidth(260) end)
		end
		configurator:Open()
	end,
	close = function(w) w.fake.close(w.configurator.frame) end,
	texts = function(w) return Labels(w.configurator.scrollContainer) end,
	roots = function(w) return Frames(w.configuratorWas or Labels(w.configurator.scrollContainer)) end,
	-- A Label's frame is as tall as its last measure made it, and its next owner's OnAcquire measures it again
	-- (AceGUIWidget-Label.lua 71-88), so its height is compared from then on, not while it lies in the pool.
	skip = function(w, object, field)
		return field == "GetHeight" and object:GetObjectType() == "Frame" and not w.configuratorOwned
	end,
	resize = function(w, k)
		Trust(w, function()
			w.configurator.scrollContainer.content:SetWidth(260 * k)
			w.configurator.scrollContainer:DoLayout()
		end)
	end,
	redraw = function(w) w.rxp.ui.v2.configurator:UpdateTheme() end,
	-- RestedXP gives a page's Labels and Heading back to AceGUI's pool when it renders the next page
	-- (GuideConfigurator.lua 1210). Another addon takes them, uses them as its own and gives them back.
	adopt = function(w, step)
		if step == "take" then
			w.configuratorWas = Labels(w.configurator.scrollContainer)
			-- The page RestedXP renders next takes other widgets: these stay with the pool until the other addon asks.
			Trust(w, function()
				for _, child in ipairs(w.configurator.scrollContainer.children) do
					w.fake.aceRelease(child)
				end
				w.configurator.scrollContainer.children = {}
			end)
			local host = w.env.CreateFrame("Frame", nil, w.env.UIParent)
			host:SetSize(200, 200)
			w.theirs = {}
			for i, item in ipairs(w.configuratorWas) do
				local widget = w.fake.aceLabel(host, i == 1 and "Their own words, long enough to wrap onto a second line in a label this narrow" or "Theirs", item.widget.type)
				assert(widget == item.widget, "the pool hands each released widget to the next caller")
				w.theirs[i] = widget
			end
			w.configuratorOwned = true
		elseif step == "use" then
			Trust(w, function()
				for _, widget in ipairs(w.theirs) do
					if widget.type == "Label" then
						widget:SetFont("Fonts\\MORPHEUS.TTF", 15, "")
						widget:SetWidth(120)
						widget:SetText("Their second words")
					else
						widget:SetText("Their heading")
					end
					widget.label:Hide()
					widget.label:Show()
				end
			end)
		else
			for _, widget in ipairs(w.theirs) do
				w.fake.aceRelease(widget)
			end
			w.configuratorOwned, w.configuratorWas, w.theirs = nil, nil, nil
		end
	end,
}

local function Both(s, p, fn, ...)
	fn(s, ...)
	fn(p, ...)
end

local EVENTS = {
	{ "text size changed while open", function(s, _, surface)
		TextSize(s, 1.5)
		Leased(s, surface, "at text size 1.5")
		TextSize(s, 1)
		Leased(s, surface, "back at text size 1")
	end },
	{ "hidden and shown again", function(s, p, surface)
		local was = Was(s, surface)
		Both(s, p, surface.close)
		Ended(s, p, surface, was, "hidden")
		TextSize(s, 1.5)
		Ended(s, p, surface, was, "hidden, at text size 1.5")
		TextSize(s, 1)
		-- A text that follows a font object (a template's, or the one AceGUI keeps for a Label) follows it again once
		-- the lease has ended: when something changes the object, the text changes with it.
		local function Refont(w, path, size)
			local done = {}
			for _, item in ipairs(surface.texts(w)) do
				local object = item.text:GetFontObject()
				if object and not done[object] then
					done[object] = true
					Trust(w, function() object:SetFont(path, size, "") end)
				end
			end
		end
		local fonts = {}
		for _, item in ipairs(surface.texts(p)) do
			local object = item.text:GetFontObject()
			fonts[#fonts + 1] = object and { object:GetFont() } or false
		end
		Both(s, p, Refont, "Fonts\\skurri.ttf", 13)
		Ended(s, p, surface, was, "hidden, its font objects changed")
		Both(s, p, function(w)
			for i, item in ipairs(surface.texts(w)) do
				local object = item.text:GetFontObject()
				if object and fonts[i] then
					Trust(w, function() object:SetFont(fonts[i][1], fonts[i][2], fonts[i][3]) end)
				end
			end
		end)
		Ended(s, p, surface, was, "hidden, its font objects back")
		Both(s, p, surface.open)
		Leased(s, surface, "shown again")
	end },
	{ "a text hidden and shown by its library", function(s, p, surface)
		for i, item in ipairs(surface.texts(s)) do
			Both(s, p, function(w) Trust(w, function() surface.texts(w)[i].text:Hide() end) end)
			Leased(s, surface, item.name .. " hidden")
			Both(s, p, function(w) Trust(w, function() surface.texts(w)[i].text:Show() end) end)
			Leased(s, surface, item.name .. " shown")
		end
	end },
	{ "shown again while another owner holds one of its widgets", function(s, p, surface)
		if not surface.lend then
			return
		end
		local was = Was(s, surface)
		Both(s, p, surface.close)
		Both(s, p, surface.lend, "take")
		local lent = { roots = function(w) return { w.lent.frame } end }
		Ended(s, p, lent, was, "one widget taken by another addon")
		Both(s, p, surface.open)
		Leased(s, surface, "shown by RestedXP with another widget")
		Same(s, p, lent, "the other addon's widget while RestedXP shows the frame")
		TextSize(s, 1.5)
		Same(s, p, lent, "the other addon's widget, at text size 1.5")
		Both(s, p, surface.lend, "use")
		Same(s, p, lent, "the other addon's widget in use")
		TextSize(s, 1)
		Same(s, p, lent, "the other addon's widget, back at text size 1")
		Both(s, p, surface.close)
		Same(s, p, lent, "the other addon's widget after RestedXP closed the frame")
		Both(s, p, surface.lend, "give")
		Both(s, p, surface.open)
		Leased(s, surface, "shown by RestedXP once more")
	end },
	{ "handed to another owner", function(s, p, surface)
		if not surface.adopt then
			return
		end
		local was = Was(s, surface)
		if surface.name ~= "guide configurator" then
			Both(s, p, surface.close)
			Ended(s, p, surface, was, "given back")
		end
		Both(s, p, surface.adopt, "take")
		Ended(s, p, surface, was, "taken by another addon")
		Both(s, p, surface.adopt, "use")
		Ended(s, p, surface, was, "used by another addon")
		TextSize(s, 1.5)
		Ended(s, p, surface, was, "used by another addon, at text size 1.5")
		TextSize(s, 1)
		Both(s, p, surface.adopt, "give")
		Ended(s, p, surface, was, "given back by the other addon")
		Both(s, p, surface.open)
		Leased(s, surface, "shown by RestedXP again")
	end },
	{ "made narrower and wider", function(s, p, surface)
		if not surface.resize then
			return
		end
		for _, k in ipairs({ 0.6, 1.4, 1 }) do
			Both(s, p, surface.resize, k)
			Leased(s, surface, "at " .. k .. " of its width")
		end
	end },
	{ "a control disabled and enabled", function(s, p, surface)
		if not surface.buttons then
			return
		end
		for i in ipairs(surface.buttons(s)) do
			Both(s, p, function(w) Trust(w, function() surface.buttons(w)[i]:Disable() end) end)
			Leased(s, surface, "button " .. i .. " disabled")
			Both(s, p, function(w) Trust(w, function() surface.buttons(w)[i]:Enable() end) end)
			Leased(s, surface, "button " .. i .. " enabled")
		end
	end },
	{ "RestedXP redraws its theme", function(s, p, surface)
		if not surface.redraw then
			return
		end
		Both(s, p, surface.redraw)
		Leased(s, surface, "redrawn while open")
		local was = Was(s, surface)
		Both(s, p, surface.close)
		Both(s, p, surface.redraw)
		Ended(s, p, surface, was, "redrawn while hidden")
		-- RestedXP renders a page before it shows the window (GuideConfigurator.lua, ShowPage), so widgets it redrew
		-- while hidden go back to the pool without ever having been on screen: hiding a frame nobody sees runs no OnHide.
		if surface.adopt then
			Both(s, p, surface.adopt, "take")
			Ended(s, p, surface, was, "redrawn while hidden, then taken by another addon")
			Both(s, p, surface.adopt, "use")
			Ended(s, p, surface, was, "redrawn while hidden, then used by another addon")
			Both(s, p, surface.adopt, "give")
		end
		Both(s, p, surface.open)
		Leased(s, surface, "shown after a redraw while hidden")
	end },
}

local cells = 0
for _, surface in ipairs(SURFACES) do
	for _, order in ipairs({ "forward", "reverse" }) do
		local s, p = World(true), World(false)
		where = surface.name .. " (" .. order .. "), opened"
		Both(s, p, surface.open)
		Leased(s, surface, "first shown")
		for i = 1, #EVENTS do
			local event = EVENTS[order == "forward" and i or #EVENTS + 1 - i]
			where = surface.name .. " (" .. order .. "), " .. event[1]
			local ok, err = pcall(event[2], s, p, surface)
			Check(ok, "raised " .. tostring(err))
			cells = cells + 1
		end
		where = surface.name .. " (" .. order .. "), closed at the end"
		local was = Was(s, surface)
		Both(s, p, surface.close)
		Ended(s, p, surface, was, "closed")
	end
end

for i, failure in ipairs(failures) do
	if i <= 60 then
		print("LEASE: " .. failure)
	end
end
assert(#failures == 0, #failures .. " lease checks failed, the first: " .. tostring(failures[1]))
print(("ok: %d surfaces x %d events x 2 orders = %d cells, %d checks"):format(#SURFACES, #EVENTS, cells, checks))
