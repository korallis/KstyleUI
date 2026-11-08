-- test-skins-partb-kit.lua: part B's helpers restyle Blizzard item buttons, dropdowns, tabs, arrows, rows and bars through alpha, hooks and KstyleUI's own child frames.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

-- Methods part B hooks with hooksecurefunc, which puts a wrapper on the object it hooks.
local HOOKED = {
	SetAlpha = true, SetVertexColor = true, Show = true, Hide = true, SetShown = true, SetChecked = true,
	SetNormalTexture = true, SetStatusBarColor = true, SetTabSelected = true, Update = true, InitButtons = true,
}

local function Fields(object)
	local out = {}
	for k in pairs(object) do
		if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
			out[k] = true
		end
	end
	return out
end

-- Check(B, snap) fails on a field written onto a stand-in Blizzard object, other than a hooked method,
-- and on any SetScript, Hide or SetParent call on one.
local function Check(B, snap)
	for _, object in ipairs(B.made) do
		local before = snap[object] or {}
		for k in pairs(Fields(object)) do
			assert(before[k] or HOOKED[k], "a field was written onto a Blizzard object: " .. tostring(k))
		end
		for _, call in ipairs(object._calls) do
			assert(call.method ~= "SetScript", "SetScript on a Blizzard object")
			assert(call.method ~= "Hide" or object._testHides, "Hide on a Blizzard object")
			assert(call.method ~= "SetParent", "SetParent on a Blizzard object")
		end
	end
end

local function Kit(ns)
	return assert(ns.PartBKit, "Kit.lua must set ns.PartBKit")
end

-- Started(opts) -> env, K, ns, B, kit: the module running, with a stand-in builder.
local function Started(opts)
	local env, K, ns = S.New(opts)
	K.Modules.Enable("Skins")
	return env, K, ns, S.Blizzard(env), Kit(ns)
end

local function Near3(r1, g1, b1, r2, g2, b2)
	return W.Near(r1, r2, 1e-3) and W.Near(g1, g2, 1e-3) and W.Near(b1, b2, 1e-3)
end

-- EdgeIs(chrome, r, g, b) is true when the chrome's inner hairline is that colour.
local function EdgeIs(chrome, r, g, b)
	local er, eg, eb = chrome.inner[1]:GetVertexColor()
	return Near3(er, eg, eb, r, g, b)
end

-- ItemButton(B, opts) -> a stand-in item button: slot art, an icon, a hidden IconBorder and a highlight.
local function ItemButton(B, parent)
	local button = B.frame("Button", parent)
	button.slot = B.texture(button, "BACKGROUND")
	button.icon = B.texture(button)
	button.IconBorder = B.texture(button, "OVERLAY")
	button.IconBorder._testHides = true
	button.IconBorder:Hide()
	button.Count = B.text(button)
	button.IconOverlay = B.texture(button, "OVERLAY")
	return button
end

-- Item: Blizzard's slot art goes, the icon stays cropped, and a rim takes the quality colour Blizzard gives the IconBorder.
do
	local env, K, ns, B, kit = Started()
	local button = ItemButton(B)
	local snap = B.snapshot()
	local item = kit.Item(button, { window = "merchant" })
	assert(item and item.rim, "an item gets a KstyleUI rim")
	assert(button.slot:GetAlpha() == 0 and button.IconBorder:GetAlpha() == 0, "the slot art and Blizzard's border are hidden")
	assert(button.icon:GetAlpha() == 1, "the icon stays")
	assert(button.IconOverlay:GetAlpha() == 1, "Blizzard's information overlays stay")
	local late = button:CreateTexture(nil, "OVERLAY")
	B.add(late)
	S.Show(button)
	assert(late:GetAlpha() == 1, "an overlay Blizzard adds later, such as a crafting quality pip, stays")
	local crop = W.LastCall(button.icon, "SetTexCoord")
	assert(crop and W.Near(crop[1], 0.07), "the icon is cropped like the kit's icons")
	assert(item.rim:GetParent() == button, "the rim is KstyleUI's own child frame")
	assert(item.rim.color == nil, "no quality, no ring")
	assert(W.SameColor(item.rim.chrome.fill[5], K.Tokens.Color("buttonFill")), "the rim's tile is the near-black button body every square icon shares")
	assert(W.SameRGB(item.rim.chrome.inner[1], K.Tokens.Color("edgeInner")), "with the plain hairline until a quality colours it")

	local r, g, b = 0.64, 0.21, 0.93
	button.IconBorder:SetVertexColor(r, g, b)
	button.IconBorder:Show()
	local er, eg, eb = K.Theme.Brighten(r, g, b)
	assert(item.rim.color and Near3(item.rim.color[1], item.rim.color[2], item.rim.color[3], er, eg, eb), "the rim takes the quality colour, lifted for the glass")

	button.IconBorder:SetVertexColor(1, 1, 1)
	assert(item.rim.color == nil, "white and grey qualities get no ring")
	button.IconBorder:SetVertexColor(r, g, b)
	button.IconBorder:Hide()
	assert(item.rim.color == nil, "Blizzard hiding its border clears the ring")

	button.IconBorder:Show()
	button.IconBorder:SetVertexColor(r, g, b)
	assert(item.rim.color, "the ring is back")
	K.Options.Write("Skins", "merchant.qualityRims", false)
	assert(item.rim.color == nil, "the window's quality rims switch turns the ring off at once")
	K.Options.Write("Skins", "merchant.qualityRims", true)
	assert(item.rim.color, "and on again")

	button.IconBorder:SetVertexColor(env.Secret(0.5), env.Secret(0.5), env.Secret(0.5))
	assert(item.rim.color == nil, "a secret colour is never compared and gives no ring")

	button.IconBorder:SetVertexColor(r, g, b)
	W.Enter(button)
	W.Settle(env)
	assert(EdgeIs(item.rim.chrome, ns.Style.Accent()), "the edge turns to the accent under the mouse")
	W.Leave(button)
	W.Settle(env)
	assert(kit.Item(button) == item, "a second call returns the same item")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Item with an atlas icon, as the repair buttons: texture coordinates would index the whole atlas sheet, so the icon is not cropped.
do
	local env, _, _, B, kit = Started()
	local button = B.frame("Button")
	button.Icon = B.texture(button)
	button.Icon:SetAtlas("SpellIcon-256x256-RepairAll")
	local snap = B.snapshot()
	kit.Item(button)
	assert(button.Icon:GetAlpha() == 1, "the atlas icon stays")
	assert(W.LastCall(button.Icon, "SetTexCoord") == nil, "and keeps its atlas coordinates")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Item with its icon as the normal texture, as the send mail attachments: Blizzard's later icon stays visible.
do
	local env, _, _, B, kit = Started()
	local button = B.frame("Button")
	local slot = B.texture(button, "BACKGROUND")
	local normal
	function button:SetNormalTexture(asset)
		if not normal then
			normal = self:CreateTexture(nil, "ARTWORK")
		end
		normal:SetTexture(asset)
	end
	function button:GetNormalTexture()
		return normal
	end
	local snap = B.snapshot()
	kit.Item(button, { normal = true })
	assert(slot:GetAlpha() == 0, "the slot art is hidden")
	button:SetNormalTexture("Interface\\Icons\\Item")
	S.Show(button)
	assert(normal:GetAlpha() == 1, "the icon Blizzard sets later is never hidden")
	assert(W.LastCall(normal, "SetTexCoord"), "and it is cropped")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Dropdown: part A's shared dropdown, so every skinned window's dropdowns match: the box art goes, the arrow stays on a raised tile.
do
	local env, K, ns, B, kit = Started()
	local dropdown = B.frame("DropdownButton")
	dropdown.Background = B.texture(dropdown, "BACKGROUND")
	dropdown.Arrow = B.texture(dropdown, "OVERLAY")
	dropdown.Text = B.text(dropdown)
	local snap = B.snapshot()
	kit.Dropdown(dropdown)
	assert(dropdown.Background:GetAlpha() == 0 and dropdown.Arrow:GetAlpha() == 1, "the box art goes, Blizzard's arrow stays")
	assert(K.Skin.IsSkinned(dropdown, "Backdrop"), "a raised tile behind")
	assert(dropdown.Text:GetFont() == (ns.Style.Font("body")), "the text uses the module's font")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- SideTab: part A's shared side tab: the selected tab's icon rings in the accent.
do
	local env, _, ns, B, kit = Started()
	local frame = B.frame("Frame")
	frame.Background = B.texture(frame, "BACKGROUND")
	frame.Icon = B.texture(frame)
	frame.SelectedTexture = B.texture(frame, "OVERLAY")
	frame.SelectedTexture._testHides = true
	frame.SelectedTexture:Hide()
	function frame:SetChecked(checked)
		self.SelectedTexture:SetShown(checked)
	end
	local snap = B.snapshot()
	kit.SideTab(frame)
	local rim = ns.Parts.RimOf(frame)
	assert(frame.Background:GetAlpha() == 0 and frame.Icon:GetAlpha() == 1, "the tab art goes, the icon stays")
	assert(rim and rim.color == nil, "an unselected tab has no ring")
	frame:SetChecked(true)
	local ar, ag, ab = ns.Style.Accent()
	assert(rim.color and Near3(rim.color[1], rim.color[2], rim.color[3], ar, ag, ab), "the selected tab rings in the accent")
	frame:SetChecked(false)
	assert(rim.color == nil)
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Arrow: page buttons get a chevron that points their way.
do
	local env, _, _, B, kit = Started()
	local prev, nextButton = B.frame("Button"), B.frame("Button")
	B.texture(prev)
	B.texture(nextButton)
	local snap = B.snapshot()
	local left, right = kit.Arrow(prev, "left"), kit.Arrow(nextButton, "right")
	assert(W.LastCall(left, "SetRotation")[1] < 0 and W.LastCall(right, "SetRotation")[1] > 0, "left and right chevrons")
	assert(kit.Arrow(prev, "left") == left, "a second call returns the same chevron")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Select and Hush: a list row loses only the named art, and its tile lights while Blizzard's selection shows.
do
	local env, _, ns, B, kit = Started()
	local row = B.frame("Button")
	row.Background = B.texture(row, "BACKGROUND")
	row.Selected = B.texture(row)
	row.Selected._testHides = true
	row.Selected:Hide()
	row.Icon = B.texture(row)
	local snap = B.snapshot()
	kit.Hush(row, row.Background, row.Selected)
	assert(row.Background:GetAlpha() == 0 and row.Selected:GetAlpha() == 0, "the named textures are hidden")
	assert(row.Icon:GetAlpha() == 1, "the rest stay")
	local tile = kit.Select(row, row.Selected)
	row.Selected:Show()
	assert(EdgeIs(tile.backdrop.chrome, ns.Style.Accent()), "Blizzard's selection lights the tile")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Rows: part A's shared row walker: each row a scroll box shows is skinned now, and rows a later update brings too.
do
	local env, _, _, B, kit = Started()
	local box = B.frame("Frame")
	local rows = { B.frame("Button", box), B.frame("Button", box) }
	function box:ForEachFrame(fn)
		for _, row in ipairs(rows) do
			fn(row)
		end
	end
	function box:Update() end
	local snap = B.snapshot()
	local count = {}
	assert(kit.Rows(box, function(row)
		count[row] = (count[row] or 0) + 1
	end))
	assert(count[rows[1]] == 1 and count[rows[2]] == 1, "the shown rows are skinned at once")
	rows[3] = B.frame("Button", box)
	box:Update()
	assert(count[rows[3]] == 1, "a new row is skinned on the next update")
	assert(kit.Rows(box, function() end), "a second call does not walk the rows again")
	box:Update()
	assert(count[rows[3]] == 2, "and the first walker keeps running")
	local plain = B.frame("Frame")
	assert(kit.Rows(plain, function() end) == false, "a frame with no rows is left alone")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- RankBar: a profession skill bar is drawn by a KstyleUI status bar that mirrors Blizzard's Update and the bar settings.
do
	local env, K, ns, B, kit = Started()
	local frame = B.frame("Frame")
	frame.Background = B.texture(frame)
	frame.Fill = B.texture(frame)
	frame.Border = B.texture(frame)
	frame.Rank = B.frame("Frame", frame)
	frame.Rank:SetFrameLevel(5)
	frame.Rank.Text = B.text(frame.Rank)
	function frame:Update(info)
		self.Rank.Text:SetText(info.skillLevel)
	end
	local snap = B.snapshot()
	local bar = kit.RankBar(frame)
	assert(frame.Fill:GetAlpha() == 0 and frame.Border:GetAlpha() == 0, "Blizzard's bar art is hidden")
	local fill = bar.fill
	assert(fill:GetParent() == frame and fill:GetFrameLevel() == 4, "a KstyleUI bar under Blizzard's rank text")
	frame:Update({ skillLevel = 150, maxSkillLevel = 300 })
	assert(select(2, fill:GetMinMaxValues()) == 300 and fill:GetValue() == 150, "the bar mirrors Blizzard's update")
	local secret = env.Secret(42)
	frame:Update({ skillLevel = secret, maxSkillLevel = 300 })
	assert(fill:GetValue() == secret, "a secret value reaches the engine untouched")
	assert(W.LastCall(fill:GetStatusBarTexture(), "SetTexture")[1] == ns.Style.BarTexture(), "the module's bar texture")
	K.Options.Write("Skins", "bars.fill", "right")
	assert(W.LastCall(fill, "SetReverseFill")[1] == true, "the fill direction setting reverses the bar")
	K.Options.Write("Skins", "bars.color", "custom")
	K.Options.Write("Skins", "bars.customColor", { r = 0.1, g = 0.2, b = 0.3 })
	local r, g, b = fill:GetStatusBarColor()
	assert(Near3(r, g, b, 0.1, 0.2, 0.3), "a custom bar colour")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Bar: a Blizzard status bar keeps its fill, loses its frame art and takes the module's bar look.
do
	local env, _, ns, B, kit = Started()
	local bar = B.frame("StatusBar")
	bar:SetStatusBarTexture("Interface\\Blizzard\\Bar")
	local fill = bar:GetStatusBarTexture()
	B.add(fill)
	local left = B.texture(bar)
	bar.rankText = B.text(bar)
	local snap = B.snapshot()
	kit.Bar(bar)
	assert(left:GetAlpha() == 0 and fill:GetAlpha() == 1, "the frame art goes, the fill stays")
	assert(W.LastCall(fill, "SetTexture")[1] == ns.Style.BarTexture(), "the module's bar texture")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- In combat a protected frame waits: the helper runs once combat ends.
do
	local env, _, _, B, kit = Started()
	local button = ItemButton(B)
	button.IsProtected = function()
		return true
	end
	env.SetCombat(true)
	assert(kit.Item(button) == nil, "nothing happens to a protected frame in combat")
	assert(button.slot:GetAlpha() == 1)
	env.SetCombat(false)
	assert(button.slot:GetAlpha() == 0, "the skin applies when combat ends")
	assert(S.Logged(env, "Item waits for combat to end"))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A missing frame is logged once and skipped.
do
	local env, _, _, _, kit = Started()
	for _, name in ipairs({ "Item", "Dropdown", "SideTab", "Arrow", "Square", "Select", "Inset", "MoneyBox", "InputScroll", "NumberBox", "RankBar", "Bar", "Rows", "Window", "Text" }) do
		kit[name](nil)
	end
	assert(S.Logged(env, "is missing on this client"), "a missing frame is logged")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The module's accent, not the interface accent: with a custom Skins accent, buttons, dropdowns, check boxes, tabs and scroll bars light in it.
do
	local env, K, ns, B, kit = Started()
	K.Options.Write("Skins", "accent.source", "custom")
	K.Options.Write("Skins", "accent.color", { r = 0.9, g = 0.1, b = 0.2 })
	local ar, ag, ab = ns.Style.Accent()
	assert(Near3(ar, ag, ab, 0.9, 0.1, 0.2))
	local button = B.frame("Button")
	B.texture(button)
	local label = B.text(button)
	button.GetFontString = function()
		return label
	end
	local dropdown = B.frame("DropdownButton")
	dropdown.Background = B.texture(dropdown)
	local check = B.frame("CheckButton")
	B.texture(check)
	local tab = B.frame("Button")
	tab.Text = B.text(tab)
	function tab:SetTabSelected() end
	local snap = B.snapshot()
	kit.Button(button)
	kit.Dropdown(dropdown)
	kit.CheckBox(check)
	kit.Tab(tab)
	assert(label:GetFont() == (ns.Style.Font("body")), "a button label takes the module's text settings")
	K.Options.Write("Skins", "text.size", 1.5)
	assert(W.Near(select(2, label:GetFont()), select(2, K.Tokens.Font("body")) * 1.5), "and follows a text size change")
	for _, frame in ipairs({ button }) do
		W.Enter(frame)
		W.Settle(env)
		assert(EdgeIs(K.Skin.Parts(frame).backdrop.chrome, 0.9, 0.1, 0.2), "the hover edge is the module's accent")
		W.Leave(frame)
		W.Settle(env)
	end
	check:SetChecked(true)
	local mr, mg, mb = K.Skin.Parts(check).mark:GetVertexColor()
	assert(Near3(mr, mg, mb, 0.9, 0.1, 0.2), "a check mark in the module's accent")
	tab:SetTabSelected(true)
	local ur, ug, ub = K.Skin.Parts(tab).underline:GetVertexColor()
	assert(Near3(ur, ug, ub, 0.9, 0.1, 0.2), "a tab underline in the module's accent")
	K.Options.Write("Skins", "accent.color", { r = 0.1, g = 0.8, b = 0.3 })
	ur, ug, ub = K.Skin.Parts(tab).underline:GetVertexColor()
	assert(Near3(ur, ug, ub, 0.1, 0.8, 0.3), "an accent change repaints at once")
	Check(B, snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A skill bar skinned after Blizzard drew it starts at Blizzard's progress, not empty.
do
	local env, _, _, B, kit = Started()
	local frame = B.frame("Frame")
	frame.Fill = B.texture(frame)
	frame.ratio = 0.5
	local bar = kit.RankBar(frame)
	assert(bar.fill:GetValue() == 0.5, "the bar starts at the progress Blizzard already shows")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins part B kit ok")

-- Square: an icon button on the near-black button body, as every square icon.
do
	local _, K, _, B, kit = Started()
	local button = ItemButton(B)
	local square = kit.Square(button)
	assert(square and square.backdrop, "a square gets a backdrop")
	assert(W.SameColor(square.backdrop.chrome.fill[5], K.Tokens.Color("buttonFill")), "the square's body is the near-black button fill, not a raised tile")
	assert(button.icon:GetAlpha() == 1, "the icon stays")
end
