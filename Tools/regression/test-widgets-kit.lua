-- test-widgets-kit.lua: the widget kit's shared parts: settings, the restyle registry, text, chrome, Escape, placement and sound.
local W = dofile("Tools/regression/widget_env.lua")

-- The kit's settings are registered with Store and Options at load, with the kit's defaults.
do
	local _, K = W.New({ boot = false })
	local Widgets = K.Widgets
	assert(type(Widgets) == "table", "KstyleUI.Widgets exists")
	local defaults = K.Store.Defaults("Widgets")
	assert(defaults, "the kit registers its defaults with Store")
	local _, _, _, surfaceAlpha = K.Tokens.Color("surface")
	assert(W.Near(defaults.panelOpacity, surfaceAlpha), "panel opacity defaults to the surface token's alpha")
	assert(defaults.shadows == false and defaults.sounds == true and defaults.tooltipScale == 1, "shadows off (the owner's picture of 2026-11-09 casts none; the setting stays), sounds on, tooltips at size 1")
	for _, key in ipairs({ "panelOpacity", "shadows", "sounds", "tooltipScale" }) do
		assert(K.Options.Row("Widgets", key), "the Widgets page has a row for " .. key)
	end
	assert(Widgets.Setting("shadows") == false, "Setting answers with the default before the saved data loads")
	W.Raises(function()
		Widgets.Setting("nope")
	end, "unknown setting")
end

-- Every tracked widget restyles on ThemeChanged, ScaleChanged, a kit setting and a profile change; one failure does not stop the rest.
do
	local env, K = W.New()
	local Widgets = K.Widgets
	local runs = {}
	local bad = Widgets.Track({ Restyle = function()
		error("boom")
	end })
	local good = Widgets.Track({ Restyle = function(self)
		runs[#runs + 1] = self
	end })
	assert(bad and good)
	local errorsBefore = K.ErrorCount()
	K.Callbacks.Fire("ThemeChanged")
	K.Callbacks.Fire("ScaleChanged")
	K.Options.Write("Widgets", "shadows", false)
	K.Callbacks.Fire("ProfileChanged", "Default", "Default")
	assert(#runs == 4 and runs[1] == good, "the widget restyled four times, got " .. #runs)
	assert(K.ErrorCount() == errorsBefore + 4, "each failing restyle is reported")
	K.Options.Write("Appearance", "accentColor", { r = 0.5, g = 0.5, b = 0.5 })
	assert(#runs == 4, "another page's setting does not restyle the kit")
	K.Options.Write("Appearance", "motion", "off")
	assert(#runs == 5, "the reduced motion switch restyles the kit, so running animations follow it")
	assert(#env._errors >= 4)
end

-- Text uses the role's font with the soft shadow, captions are upper case, secrets pass through, and a face change restyles every text.
do
	local env, K = W.New()
	local Widgets, Tokens = K.Widgets, K.Tokens
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	local caption = Widgets.Text(frame, "caption", "text")
	local path, size, flags = Tokens.Font("caption")
	local font = W.LastCall(caption, "SetFont")
	assert(font[1] == path and font[2] == size and font[3] == flags, "the caption font from the tokens")
	assert(W.SameColor({ GetVertexColor = function()
		return caption:GetTextColor()
	end }, Tokens.Color("text")), "the text colour from the tokens")
	local sr, sg, sb, sa = caption:GetShadowColor()
	local tr, tg, tb, ta = Tokens.Color("textShadow")
	assert(W.Near(sr, tr) and W.Near(sg, tg) and W.Near(sb, tb) and W.Near(sa, ta), "the shadow colour from the tokens")
	local dx, dy = caption:GetShadowOffset()
	assert(W.Near(dx, Tokens.Size("textShadowOffset")) and W.Near(dy, -Tokens.Size("textShadowOffset")), "the shadow drops down and right")
	Widgets.SetText(caption, "Uncommon")
	assert(caption:GetText() == "UNCOMMON", "a caption is upper case")
	local body = Widgets.Text(frame, "body")
	Widgets.SetText(body, "Level 38")
	assert(body:GetText() == "Level 38", "body text keeps its case")
	local secret = env.Secret("Hogger")
	Widgets.SetText(caption, secret)
	assert(caption:GetText() == secret, "a secret string reaches SetText untouched")
	Widgets.SetText(caption, nil)
	assert(caption:GetText() == "", "nil clears the text")
	assert(K.Theme.SetFontFace("InterSemiBold"))
	assert(W.LastCall(body, "SetFont")[1]:match("Inter%-SemiBold"), "a face change restyles the text")
	assert(W.LastCall(caption, "SetFont")[1]:match("Inter%-SemiBold"), "a face change restyles every text")
end

-- A font the game cannot load falls back to a Blizzard font object instead of leaving the text unusable.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	local text = frame:CreateFontString()
	text.SetFont = function()
		return false
	end
	K.Widgets.StyleText(text, "body")
	assert(W.LastCall(text, "SetFontObject"), "a failed SetFont falls back to SetFontObject")
end

-- The texel sizes the kit slices with match the PNG files.
do
	local _, K = W.New({ boot = false })
	local function pngSize(path)
		local file = path:gsub("^Interface\\AddOns\\KstyleUI\\", ""):gsub("\\", "/")
		local handle = assert(io.open(file, "rb"), "missing " .. file)
		local head = handle:read(24)
		handle:close()
		local function u32(i)
			local a, b, c, d = head:byte(i, i + 3)
			return ((a * 256 + b) * 256 + c) * 256 + d
		end
		return u32(17), u32(21)
	end
	local names = {}
	for name, texels in pairs(K.Widgets.TEXTURE_TEXELS) do
		local width, height = pngSize((K.Tokens.Texture(name)))
		assert(width == texels and height == texels, name .. " is " .. width .. "x" .. height .. ", the kit slices it as " .. texels)
		names[name] = true
	end
	for _, name in ipairs({ "lumenShape", "cardShape", "lumenOutline", "ringLine2", "ringLine3", "ringLine4", "ringLine5", "ringLine6", "lumenShadow", "shadow" }) do
		assert(names[name], name .. " is a sliced texture")
	end
	for _, name in ipairs({ "medUnitSlab", "medUnitSlabCap", "medCardEdge", "medAuraBorder", "medGroupTile", "medGroupTargetRing" }) do
		assert(names[name], name .. " is a sliced texture, so Widgets.NineSlice draws it instead of raising")
	end
	for _, name in ipairs({ "lumenFrost", "lumenRim", "lumenRimSmall", "gilt" }) do
		assert(not names[name] and not pcall(K.Tokens.Texture, name), name .. " is retired with the frost glass")
	end
	assert(not names.chamferPanel and not names.chamferWindow, "the chamfer slices are retired")
end

local function chrome(env, K, shape, width, height)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(width or 200, height or 100)
	return frame, K.Widgets.Chrome(frame, { shape = shape, fill = "surface", shadow = true })
end

-- Corners: cards, panels, windows and rails wear the Medallions steel bevel, a 4-unit corner; tiles and sockets round
-- three border lines, at every size, and never more than half the shorter side. The padding keeps the old 14 and 8
-- unit caps, so content does not move.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	W.Raises(function()
		Tokens.Share("nope")
	end, "unknown name")
	assert(not pcall(Tokens.Share, "radiusSocket"), "the socket share is retired: sockets round three lines at every size")
	assert(Tokens.Size("radius") == 14 and Tokens.Size("radiusTile") == 8, "the padding caps")
	local line = Scale.Border()
	local cases = {
		{ "panel", 200, 100, 4 }, { "panel", 300, 30, 4 }, { "panel", 200, 6, 3 },
		{ "window", 400, 200, 4 }, { "card", 200, 100, 4 }, { "rail", 318, 600, 4 },
		{ "tile", 200, 100, 3 * line }, { "tile", 180, 18, 3 * line }, { "tile", 200, 4, 2 * line }, { "socket", 38, 38, 3 * line },
	}
	for _, case in ipairs(cases) do
		local shape, w, h, want = case[1], case[2], case[3], case[4]
		local _, c = chrome(env, K, shape, w, h)
		local label = shape .. " " .. w .. "x" .. h
		assert(W.Near(c:Radius(), want), label .. ": the corner is " .. tostring(c:Radius()) .. ", want " .. want)
		assert(c.Chamfer == c.Radius, "Chamfer is the radius for older callers")
		assert(W.Near(c.line[1]:GetWidth(), Scale.Snap(want)), label .. ": the outer line's corner is the radius, snapped")
		assert(W.Near(c.fill[1]:GetWidth(), Scale.Snap(want) - line), label .. ": the fill sits one line in")
		assert(W.Near(c.rim[1]:GetWidth(), c.fill[1]:GetWidth()), label .. ": and so does the rim")
	end
	local _, panel = chrome(env, K, "panel", 200, 100)
	assert(W.Near(panel:PadRadius(), 14), "a panel pads as it did, so content stays put")
	local frame, c = chrome(env, K, "tile", 200, 100)
	frame:SetSize(200, 4)
	assert(W.Near(c:Radius(), 2) and W.Near(c.line[1]:GetWidth(), Scale.Snap(2)), "a size change re-rounds the corners through OnSizeChanged, got " .. tostring(c:Radius()))
	local bare = env.CreateFrame("Frame", nil, Scale.Root())
	local bc = K.Widgets.Chrome(bare, { shape = "panel" })
	assert(W.Near(bc:Radius(), 4), "a frame with no size takes the steel's 4-unit corner")
	local eframe, explicit = chrome(env, K, "panel", 200, 100)
	explicit:SetRadius(4)
	assert(W.Near(explicit:Radius(), 4), "an explicit radius still wins")
	eframe:SetSize(200, 6)
	assert(W.Near(explicit:Radius(), 3), "but never more than half the short side")
	explicit:SetChamfer(nil)
	assert(W.Near(explicit:Radius(), 3) and W.Near(explicit.line[1]:GetWidth(), Scale.Snap(3)), "SetChamfer is SetRadius; unpinning returns to the computed corner, laid out at once")
	local icon = env.CreateFrame("Frame", nil, Scale.Root())
	icon:SetSize(52, 52)
	local ic = K.Widgets.IconChrome(icon)
	assert(W.Near(ic:Radius(), 3 * line), "a 52-unit socket rounds three lines, got " .. tostring(ic:Radius()))
	icon:SetSize(38, 38)
	assert(W.Near(ic:Radius(), 3 * line), "and so does a 38-unit one")
	local pframe, pinned = chrome(env, K, "panel", 80, 80)
	pinned:SetRadius(12)
	assert(W.LastCall(pinned.line[1], "SetTexture")[1] == Tokens.Texture("ringLine12"), "a corner pinned at 12 lines draws the 12-line ring, so its arc stays one line thick")
	pframe:SetSize(80, 40)
	pinned:SetRadius(20)
	assert(W.LastCall(pinned.line[1], "SetTexture")[1] == Tokens.Texture("ringLine20"), "a disc of 40 draws the 20-line ring")
	pinned:SetRadius(14)
	local drawn = W.LastCall(pinned.line[1], "SetTexture")[1]
	assert(drawn == Tokens.Texture("ringLine12") or drawn == Tokens.Texture("ringLine16"), "a count between rings takes the nearest one")
end

-- Chrome: the Medallions steel card. The medCardFill tint in the card shape one line in, a one-line outer edge in
-- medOutline on the 4-unit ring, a rim one line in, lit along the top and low along the bottom, and a shadow that stays
-- off unless the setting turns it on. No frost and no grain.
do
	local env, K = W.New()
	local Scale, Tokens, Widgets = K.Scale, K.Tokens, K.Widgets
	local line = Scale.Border()
	local _, c = chrome(env, K, "panel")
	env.RunTimers()
	assert(#c.fill == 9 and #c.shadow == 0 and #c.rim == 9 and #c.line == 9, "nine pieces for each drawn slice; the disabled shadow stays unbuilt")
	assert(c.frost == nil and c.noise == nil, "no frost and no grain")
	assert(W.LastCall(c.fill[1], "SetTexture")[1] == Tokens.Texture("cardShape"), "the fill is the card shape")
	assert(W.LastCall(c.line[1], "SetTexture")[1] == Tokens.Texture("ringLine" .. 4 / line), "the outer line is the steel's 4-unit ring")
	assert(W.LastCall(c.rim[1], "SetTexture")[1] == Tokens.Texture("ringLine" .. (4 - line) / line), "the rim, one line in, is the next ring in")
	local point = c.fill[1]._points[1]
	assert(point[1] == "TOPLEFT" and W.Near(point[4], line) and W.Near(point[5], -line), "the fill starts one line in")
	assert(W.SameColor(c.fill[5], Widgets.Rgba("medCardFill")), "the fill is the steel's card fill at the panel opacity")
	local lr, lg, lb, la = Widgets.Rgba("medOutline")
	for i = 1, 9 do
		assert(W.SameColor(c.line[i], lr, lg, lb, la), "the outer line is medOutline on every piece")
	end
	assert(W.SameColor(c.rim[1], Widgets.Rgba("medRimLit")) and W.SameColor(c.rim[9], Widgets.Rgba("medRimLow")), "the rim is lit at the top and low at the bottom")
	assert(not c.shadow[1]:IsShown(), "the card casts no shadow")
	K.Options.Write("Widgets", "shadows", true)
	assert(c.shadow[1]:IsShown(), "the setting still turns it on")
	c:SetShown(false)
	assert(not c.rim[1]:IsShown() and not c.line[1]:IsShown() and not c.fill[5]:IsShown(), "SetShown hides every layer")
	c:SetShown(true)
	assert(c.rim[1]:IsShown() and c.line[1]:IsShown() and not c.rim[5]:IsShown() and not c.line[5]:IsShown(), "and shows them again, the rings' transparent centres still hidden")
	local reach = Scale.Snap(Tokens.Size("shadow"))
	local shadowCorner = c.shadow[1]
	assert(W.LastCall(shadowCorner, "SetTexture")[1] == Tokens.Texture("lumenShadow"), "the shadow is the card shadow, with the card cut out")
	assert(W.Near(shadowCorner:GetWidth(), Scale.Snap(2 * Tokens.Size("shadow"))), "the shadow's corner piece is twice the reach")
	local sp = shadowCorner._points[1]
	assert(W.Near(sp[4], -reach) and W.Near(sp[5], reach), "the shadow corner is centred on the panel's corner")
	c:SetEdge("accent")
	local ar, ag, ab = Tokens.Color("accent")
	assert(W.SameColor(c.rim[1], ar, ag, ab, 1) and W.SameColor(c.rim[9], ar, ag, ab, 1), "SetEdge recolours the whole rim")
	assert(W.SameColor(c.line[1], lr, lg, lb, la), "and leaves the outer line")
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.rim[9], ar, ag, ab, 1), "and the colour survives a restyle")
	c:SetProc(true)
	assert(W.SameRGB(c.line[1], Widgets.Rgba("giltLit")), "a proc lights the outer line in lit steel")
	c:SetProc(false)
	assert(W.SameColor(c.line[1], lr, lg, lb, la), "and back")
end

-- The gilt L-ticks are built on every card shape but never show under the steel; a window can leave them off.
do
	local env, K = W.New()
	local Scale = K.Scale
	assert(not pcall(K.Tokens.Size, "gilt"), "the gilt tip size is retired")
	for _, shape in ipairs({ "panel", "card", "window", "rail" }) do
		local _, c = chrome(env, K, shape)
		assert(c.shapeName == shape, "the chrome knows its shape")
		assert(c.gilt and #c.gilt == 6, shape .. ": two ticks of an arc and two legs")
		for i = 1, 6 do
			assert(not c.gilt[i]:IsShown(), shape .. ": the steel shows no gilt tick")
		end
	end
	local frame = env.CreateFrame("Frame", nil, Scale.Root())
	frame:SetSize(200, 40)
	local small = K.Widgets.Chrome(frame, { shape = "window", gilt = false })
	assert(small.gilt == nil, "a window can leave its gilt off")
	W.Raises(function()
		K.Widgets.Chrome(env.CreateFrame("Frame", nil, Scale.Root()), { shape = "disc" })
	end, "shape must be panel, card, window, rail, tile, socket or bar")
end

-- The bar grade: a capsule track, its corners half the bar's short side, and a faint even rim in the edge token.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(180, 18)
	local c = K.Widgets.Chrome(frame, { shape = "bar", fill = "surface", shadow = false })
	env.RunTimers()
	local er, eg, eb, ea = K.Tokens.Color("edgeBar")
	assert(#c.fill == 9 and #c.rim == 9, "a nine-sliced capsule for the track and its rim")
	assert(W.LastCall(c.rim[1], "SetTexture")[1] == K.Tokens.Texture("lumenOutline"), "the rim is even all round")
	assert(W.SameColor(c.rim[1], er, eg, eb, ea) and W.SameColor(c.rim[2], er, eg, eb, ea), "the rim takes the bar's edge token")
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.rim[3], er, eg, eb, ea), "and keeps it through a restyle")
	assert(W.Near(c:Radius(), 9) and W.Near(c.fill[1]:GetWidth(), 9) and W.Near(c.rim[9]:GetWidth(), 9), "an 18-unit bar's corners are 9 units")
	assert(c.shadow == nil and c.line == nil and c.gilt == nil, "no shadow, outer line or gilt on a bar")
end

-- An icon chrome: the socket grade of the picture's action buttons. A near-black outer line on a three-line corner, the
-- button fill one line in, a rim the button colours, no gilt, and a lit steel outer line only while a proc is up.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	local frame = env.CreateFrame("Frame", nil, Scale.Root())
	frame:SetSize(38, 38)
	local c = K.Widgets.IconChrome(frame)
	assert(c.shapeName == "socket" and c.frost == nil and c.gilt == nil, "a socket: no frost, no gilt")
	assert(W.LastCall(c.line[1], "SetTexture")[1] == Tokens.Texture("ringLine3"), "its outer line is the three-line ring")
	local sr, sg, sb, sa = Tokens.Color("socketEdge")
	assert(W.SameColor(c.line[1], sr, sg, sb, sa) and W.SameColor(c.line[5], sr, sg, sb, sa), "in the near-black socket edge")
	assert(W.SameColor(c.fill[5], Tokens.Color("buttonFill")), "on the button fill")
	c:SetRim(0.5, 0.6, 0.7, 1)
	assert(W.SameColor(c.rim[5], 0.5, 0.6, 0.7, 1) and W.SameColor(c.rim[1], 0.5, 0.6, 0.7, 1), "SetRim colours the rim")
	c:SetProc(true)
	assert(W.SameRGB(c.line[1], K.Widgets.Rgba("giltLit")), "a proc lights the outer line in lit steel")
	c:SetRim(0.1, 0.1, 0.1, 1)
	assert(W.SameRGB(c.line[1], K.Widgets.Rgba("giltLit")), "and the lit steel holds while the proc is up")
	assert(W.SameColor(c.rim[1], 0.1, 0.1, 0.1, 1), "while the rim takes the button's colour")
	c:SetProc(false)
	assert(W.SameColor(c.line[1], sr, sg, sb, sa), "then the socket edge returns")
	assert(not pcall(Tokens.Size, "buttonBezel"), "sockets have no bezel plate")
end

-- A move to a 1440p screen redraws the corners in whole pixels: the same number of lines, each one 1440p pixel.
do
	local env, K = W.New()
	env._physical = { 2560, 1440 }
	env.GetPhysicalScreenSize = function()
		return env._physical[1], env._physical[2]
	end
	local frame, c = chrome(env, K, "tile")
	local rim = K.Widgets.NineSlice(frame, "lumenOutline", "BORDER", 0)
	K.Widgets.LayoutSlice(rim, frame, c:Radius(), 0)
	assert(W.Near(c:Radius(), 3), "a tile's corner is three lines")
	assert(W.Near(c.line[1]:GetWidth(), 3) and W.Near(rim[1]:GetWidth(), 3), "3 pixels at 1080p")
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.RunTimers()
	K.Widgets.LayoutSlice(rim, frame, c:Radius(), 0)
	assert(W.Near(K.Scale.Border(), 0.75), "the border is one 1440p pixel")
	assert(W.Near(c.line[1]:GetWidth(), 3 * 0.75) and W.Near(c.fill[1]:GetWidth(), 2 * 0.75), "still three lines, each one 1440p pixel")
	assert(W.Near(rim[1]:GetWidth(), c.line[1]:GetWidth()), "a slice laid out with the chrome's radius lines up with the chrome")
end

-- Bag slots and unit frames recolour chrome on game events, in combat too, so the colour setters allocate nothing.
-- The engine's setters are replaced on each piece: the stubs record each call in a table of their own.
do
	local env, K = W.New()
	local _, c = chrome(env, K, "tile")
	local function noop() end
	for _, list in ipairs({ c.fill, c.shadow, c.rim, c.line }) do
		for _, piece in ipairs(list) do
			piece.SetVertexColor, piece.SetShown = noop, noop
		end
	end
	local function work()
		c:SetFillRGBA(0.1, 0.2, 0.3, 0.4)
		c:SetFill("raised", 0.5)
		c:SetFill("raised")
		c:SetEdgeRGBA(0.5, 0.6, 0.7, 0.8)
	end
	work()
	local jit = rawget(_G, "jit")
	if jit then
		jit.off()
		jit.flush()
	end
	collectgarbage("collect")
	collectgarbage("stop")
	-- Reserve the baseline's stack slot so the warm-up reaches the same stack depth as the measured loop.
	local before
	for _ = 1, 10 do
		work()
	end
	before = collectgarbage("count")
	for _ = 1, 1000 do
		work()
	end
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then
		jit.on()
	end
	assert(grown == 0, "the chrome colour setters allocated " .. grown .. " KB over 1000 rounds")
end

-- A fill colour of the caller's, a token at a scaled alpha, and a plain token each paint the fill.
do
	local env, K = W.New()
	local _, c = chrome(env, K, "panel")
	c:SetFillRGBA(0.1, 0.2, 0.3, 0.4)
	assert(W.SameColor(c.fill[5], 0.1, 0.2, 0.3, 0.4), "SetFillRGBA paints the caller's colour")
	c:SetFill("raised", 0.5)
	assert(W.SameColor(c.fill[5], K.Widgets.Rgba("raised", 0.5)), "SetFill with an alpha scale paints the token at that alpha")
	c:SetFill("raised")
	assert(W.SameColor(c.fill[5], K.Tokens.Color("raised")), "SetFill without one paints the token itself")
	c:SetFillRGBA(0.6, 0.7, 0.8, 0.9)
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.fill[5], 0.6, 0.7, 0.8, 0.9), "the caller's colour survives a restyle")
end

-- The kit settings restyle chrome: the panel opacity and the shadow switch.
do
	local env, K = W.New()
	local _, c = chrome(env, K, "panel")
	K.Options.Write("Widgets", "panelOpacity", 0.6)
	local _, _, _, a = c.fill[5]:GetVertexColor()
	local steel, surface = select(4, K.Widgets.Rgba("medCardFill")), select(4, K.Tokens.Color("surface"))
	assert(W.Near(a, steel * 0.6 / surface), "the panel opacity scales the steel fill's alpha")
	K.Options.Write("Widgets", "shadows", false)
	assert(c.shadow[1]:IsShown() == false, "the shadow switch hides the shadow")
	K.Options.Write("Widgets", "shadows", true)
	assert(c.shadow[1]:IsShown() == true, "and shows it again")
end

-- Escape: the frame takes Escape and passes every other key on; in combat it never touches the protected propagation call.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	local closed = 0
	K.Widgets.EscapeCloses(frame, function()
		closed = closed + 1
	end)
	assert(W.LastCall(frame, "EnableKeyboard")[1] == true, "the frame takes the keyboard")
	assert(W.LastCall(frame, "SetPropagateKeyboardInput")[1] == true, "other keys reach the game")
	W.Key(frame, "W")
	assert(closed == 0 and W.LastCall(frame, "SetPropagateKeyboardInput")[1] == true)
	W.Key(frame, "ESCAPE")
	assert(closed == 1 and W.LastCall(frame, "SetPropagateKeyboardInput")[1] == false, "Escape closes and is not passed on")
	frame:GetScript("OnHide")(frame)
	assert(W.LastCall(frame, "SetPropagateKeyboardInput")[1] == true, "hiding passes keys on again")
	local calls = #W.Calls(frame, "SetPropagateKeyboardInput")
	env.SetCombat(true)
	assert(#W.Calls(frame, "SetPropagateKeyboardInput") == calls + 1, "combat start passes keys on, before lockdown")
	calls = calls + 1
	W.Key(frame, "ESCAPE")
	W.Key(frame, "W")
	assert(closed == 2, "Escape still closes in combat")
	assert(#W.Calls(frame, "SetPropagateKeyboardInput") == calls, "no protected call in combat")
end

-- A frame made in combat takes the keyboard only once combat ends.
do
	local env, K = W.New()
	env.SetCombat(true)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	K.Widgets.EscapeCloses(frame, function() end)
	assert(#W.Calls(frame, "SetPropagateKeyboardInput") == 0 and #W.Calls(frame, "EnableKeyboard") == 0, "nothing in combat")
	env.SetCombat(false)
	assert(W.LastCall(frame, "SetPropagateKeyboardInput")[1] == true and W.LastCall(frame, "EnableKeyboard")[1] == true, "after combat")
end

-- Place: the default position on the root, then Layout.Register when Layout exists; without it, a devlog line.
do
	local env, K = W.New({ layout = true })
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	K.Widgets.Place(frame, "Test.Frame", { anchor = "TOP", x = 0, y = -40 }, { scalable = true, label = "Test" })
	local p = frame._points[1]
	assert(p[1] == "TOP" and p[2] == K.Scale.Root() and p[3] == "TOP" and p[4] == 0 and p[5] == -40, "the default point on the root")
	local reg
	for _, entry in ipairs(env._layout) do if entry.key == "Test.Frame" then reg = entry; break end end
	assert(reg and reg.frame == frame and reg.key == "Test.Frame" and reg.position.anchor == "TOP" and reg.opts.scalable, "registered with Layout")
	local env2, K2 = W.New()
	local placed = env2.CreateFrame("Frame", nil, K2.Scale.Root())
	K2.Widgets.Place(placed, "Test.Placed", { anchor = "TOP", x = 0, y = -40 }, { label = "Placed" })
	assert(K2.Layout.Get("Test.Placed") and K2.Layout.Get("Test.Placed").anchor == "TOP", "the real Layout service registers the frame")
	local layout = K2.Layout
	K2.Layout = nil
	local other = env2.CreateFrame("Frame", nil, K2.Scale.Root())
	K2.Widgets.Place(other, "Test.Other", { anchor = "CENTER", x = 5, y = 6 })
	K2.Layout = layout
	assert(other._points[1][1] == "CENTER", "positioned without Layout")
	local logged = false
	for _, entry in ipairs(env2.KstyleUIDB.devlog) do
		logged = logged or (entry.module == "Widgets" and entry.message:find("Layout", 1, true) ~= nil)
	end
	assert(logged, "a missing Layout service is logged")
end

-- Sound plays a sound kit while the sounds setting is on, and is silent without PlaySound.
do
	local played = {}
	local env, K = W.New({ setup = function(e)
		e.SOUNDKIT = { IG_MAINMENU_OPEN = 850 }
		e.PlaySound = function(id)
			played[#played + 1] = id
		end
	end })
	K.Widgets.Sound("IG_MAINMENU_OPEN")
	assert(played[1] == 850, "the sound kit plays")
	K.Options.Write("Widgets", "sounds", false)
	K.Widgets.Sound("IG_MAINMENU_OPEN")
	assert(#played == 1, "silent when sounds are off")
	env.PlaySound = nil
	K.Options.Write("Widgets", "sounds", true)
	K.Widgets.Sound("IG_MAINMENU_OPEN")
	K.Widgets.Sound("NOT_A_KIT")
end

print("widgets kit ok")
