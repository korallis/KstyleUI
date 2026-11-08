-- test-skins-grades.lua: every piece the skins draw takes one of the mockup's measured grades (THEME_SPEC): windows the window shape, rows, insets and list bodies the glass surface, controls the dark button body, bars the bar edge, bottom tabs the button-body strip (test-grades.lua lints the raised tone away).
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local function EdgeIs(K, chrome, name)
	local r, g, b, a = K.Widgets.Rgba(name)
	local e = chrome.edge
	return W.Near(e[1], r) and W.Near(e[2], g) and W.Near(e[3], b) and W.Near(e[4], a)
end

local function Grade(chrome, fill, shape)
	return chrome.fillName == fill and chrome.shapeName == shape
end

local function StatusBar(B, parent)
	local bar = B.frame("StatusBar", parent)
	bar:SetStatusBarTexture("Interface\\Blizzard\\Bar")
	B.add(bar:GetStatusBarTexture())
	B.texture(bar)
	bar.Text = B.text(bar)
	return bar
end

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	local B = S.Blizzard(env)
	local kit, partC = ns.PartBKit, ns.PartC

	-- Controls: the dark button body of the mockup's buttons and the design kit's dropdown, on a tile with no shadow.
	local button = B.frame("Button")
	B.texture(button)
	local backdrop = K.Skin.Button(button)
	assert(Grade(backdrop.chrome, "buttonFill", "tile") and not backdrop.chrome.shadowOn, "a text button is the button body on a tile, got " .. tostring(backdrop.chrome.fillName))
	local edit = B.frame("EditBox")
	B.texture(edit)
	assert(Grade(K.Skin.EditBox(edit).chrome, "buttonFill", "tile"), "an edit box is the button body")
	local check = B.frame("CheckButton")
	B.texture(check)
	assert(Grade(K.Skin.CheckBox(check).box.chrome, "buttonFill", "tile"), "a check box is the button body")
	local drop = B.frame("Button")
	drop.Arrow, drop.Text = B.texture(drop), B.text(drop)
	assert(Grade(ns.Parts.Dropdown(drop).chrome, "buttonFill", "tile"), "a dropdown is the button body")
	local scroll = B.frame("ScrollFrame")
	B.texture(scroll)
	assert(Grade(kit.InputScroll(scroll).chrome, "buttonFill", "tile"), "a scrolling text box is the button body")

	-- Rows, insets and list bodies: the glass surface, the panel grade on a tile, no shadow.
	local row = B.frame("Button")
	local select = kit.Select(row, nil)
	assert(Grade(select.backdrop.chrome, "surface", "tile") and not select.backdrop.chrome.shadowOn, "a list row is the glass surface, got " .. tostring(select.backdrop.chrome.fillName))
	local inset = B.frame("Frame")
	inset.NineSlice = B.frame("Frame", inset)
	inset.Bg = B.texture(inset)
	local tile = kit.Inset(inset, { tile = true })
	assert(Grade(tile.chrome, "surface", "tile"), "an inset is the glass surface")

	-- Bars: the bar grade, the glass surface under a faint edgeBar line.
	local partB = kit.Bar(StatusBar(B))
	assert(Grade(partB.backdrop.chrome, "surface", "tile") and EdgeIs(K, partB.backdrop.chrome, "edgeBar"), "a part B bar wears the bar grade")
	local track = partC.Bar(StatusBar(B))
	assert(Grade(track, "surface", "tile") and EdgeIs(K, track, "edgeBar"), "a part C bar wears the bar grade")
	local rep = B.frame("Frame")
	rep.Fill = B.texture(rep, "BORDER")
	rep.Text = B.text(rep)
	local fill = ns.Parts.FillBar(rep)
	assert(Grade(fill.track.chrome, "surface", "tile") and EdgeIs(K, fill.track.chrome, "edgeBar"), "a reputation bar's track wears the bar grade")

	-- Windows: the window shape with its shadow, as the chat and the tracker.
	local window = B.frame("Frame", nil, "GradeWindow")
	window.Bg = B.texture(window)
	window.numTabs = 3
	local tabs = {}
	for i = 1, 3 do
		local tab = B.frame("Button", window, "GradeWindowTab" .. i)
		tab:SetSize(80, 22)
		tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 10 + (i - 1) * 84, 2)
		B.texture(tab)
		tabs[i] = tab
	end
	local panel = K.Skin.Window(window)
	assert(Grade(panel.chrome, "surface", "window") and panel.chrome.shadowOn, "a window is window-grade glass")

	-- Bottom tabs sit on one dark strip, the design kit's tab bar: the button body behind every tab, from the first to the last.
	local strip = K.Skin.Parts(window).strip
	assert(strip and Grade(strip.chrome, "buttonFill", "tile") and not strip.chrome.shadowOn, "a window's bottom tabs sit on a button-body strip")
	assert(strip:GetParent() == window and strip:GetFrameLevel() < tabs[1]:GetFrameLevel(), "the strip is the window's own frame, behind the tabs")
	local first, last = strip._points[1], strip._points[2]
	assert(first[1] == "TOPLEFT" and first[2] == tabs[1] and last[1] == "BOTTOMRIGHT" and last[2] == tabs[3], "it spans the first tab to the last")
	assert(K.Skin.Window(window) == panel and K.Skin.Parts(window).strip == strip, "a second call keeps the one strip")
	local lone = B.frame("Button")
	B.texture(lone)
	K.Skin.Tab(lone)
	assert(K.Skin.Parts(lone).strip == nil and not K.Skin.IsSkinned(lone, "Backdrop"), "a tab skinned on its own, in a header's tab system, gets no strip of its own")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins grades ok")
