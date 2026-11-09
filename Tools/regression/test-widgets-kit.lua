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
	assert(defaults.shadows == true and defaults.sounds == true and defaults.tooltipScale == 1, "shadows and sounds on, tooltips at size 1")
	for _, key in ipairs({ "panelOpacity", "shadows", "sounds", "tooltipScale" }) do
		assert(K.Options.Row("Widgets", key), "the Widgets page has a row for " .. key)
	end
	assert(Widgets.Setting("shadows") == true, "Setting answers with the default before the saved data loads")
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
	for _, name in ipairs({ "lumenShape", "lumenFrost", "lumenRim", "lumenRimSmall", "lumenOutline", "lumenShadow", "shadow" }) do
		assert(names[name], name .. " is a sliced texture")
	end
	assert(not names.chamferPanel and not names.chamferWindow, "the chamfer slices are retired")
end

local function chrome(env, K, shape, width, height)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(width or 200, height or 100)
	return frame, K.Widgets.Chrome(frame, { shape = shape, fill = "surface", shadow = true })
end

-- Corners are rounded, never cut. Cards, panels, windows and rails round 14 units, tiles and sockets 8, and no corner
-- is more than half the shorter side, so a short strip becomes a pill. A frame with no size yet takes the cap. Icon
-- sockets round 11/52 of their side, the mockup's 52-unit socket.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	assert(W.Near(Tokens.Share("radiusSocket"), 11 / 52), "the socket share is a token")
	W.Raises(function()
		Tokens.Share("nope")
	end, "unknown name")
	assert(Tokens.Size("radius") == 14 and Tokens.Size("radiusTile") == 8, "the caps")
	local cases = {
		{ "panel", 200, 100, 14 }, { "panel", 300, 30, 14 }, { "panel", 200, 20, 10 },
		{ "window", 400, 200, 14 }, { "window", 200, 24, 12 }, { "card", 200, 100, 14 }, { "rail", 318, 600, 14 },
		{ "tile", 200, 100, 8 }, { "tile", 180, 18, 8 }, { "tile", 200, 10, 5 }, { "socket", 38, 38, 8 },
	}
	for _, case in ipairs(cases) do
		local shape, w, h, want = case[1], case[2], case[3], case[4]
		local _, c = chrome(env, K, shape, w, h)
		assert(W.Near(c:Radius(), want), shape .. " " .. w .. "x" .. h .. ": the radius is " .. tostring(c:Radius()) .. ", want " .. want)
		assert(c.Chamfer == c.Radius, "Chamfer is the radius for older callers")
		assert(W.Near(c.fill[1]:GetWidth(), Scale.Snap(want)), shape .. " " .. w .. "x" .. h .. ": the fill corner is the radius, snapped")
		assert(W.Near(c.rim[1]:GetWidth(), Scale.Snap(want)), shape .. " " .. w .. "x" .. h .. ": and so is the rim's")
	end
	local frame, c = chrome(env, K, "tile", 200, 100)
	frame:SetSize(200, 10)
	assert(W.Near(c:Radius(), 5) and W.Near(c.fill[1]:GetWidth(), Scale.Snap(5)), "a size change re-rounds the corners through OnSizeChanged, got " .. tostring(c:Radius()))
	local bare = env.CreateFrame("Frame", nil, Scale.Root())
	local bc = K.Widgets.Chrome(bare, { shape = "panel" })
	assert(W.Near(bc:Radius(), 14), "a frame with no size takes the shape's cap")
	local eframe, explicit = chrome(env, K, "panel", 200, 100)
	explicit:SetRadius(4)
	assert(W.Near(explicit:Radius(), 4), "an explicit radius still wins")
	eframe:SetSize(200, 6)
	assert(W.Near(explicit:Radius(), 3), "but never more than half the short side")
	explicit:SetChamfer(nil)
	assert(W.Near(explicit:Radius(), 3) and W.Near(explicit.fill[1]:GetWidth(), Scale.Snap(3)), "SetChamfer is SetRadius; unpinning returns to the computed radius, laid out at once")
	local icon = env.CreateFrame("Frame", nil, Scale.Root())
	icon:SetSize(52, 52)
	local ic = K.Widgets.IconChrome(icon)
	assert(W.Near(ic:Radius(), 11), "a 52-unit socket rounds 11, got " .. tostring(ic:Radius()))
	icon:SetSize(38, 38)
	assert(W.Near(ic:Radius(), 38 * 11 / 52), "and follows a size change")
end

-- Chrome: the Lumen card. A nine-sliced shadow reaching 14 units with its 3-unit drop baked in and the card cut out of
-- it, so the glass never darkens over its own shadow, the deep tint in the rounded shape, the
-- frost slice tinted glass, the grain inside the arcs, and the rim slice tinted with the edge colour (its texture holds
-- the bright top). Panels and cards have no gilt.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	local _, c = chrome(env, K, "panel")
	assert(#c.fill == 9 and #c.shadow == 9 and #c.frost == 9 and #c.rim == 9, "nine pieces each for the shadow, fill, frost and rim")
	assert(c.gilt == nil, "a panel has no gilt")
	local tl = c.fill[1]
	local coords = W.LastCall(tl, "SetTexCoord")
	assert(coords[1] == 0 and W.Near(coords[2], 56 / 128) and coords[3] == 0 and W.Near(coords[4], 56 / 128), "the corner piece is the texture's 56-texel corner")
	local w, h = tl:GetSize()
	assert(W.Near(w, Scale.Snap(14)) and W.Near(h, Scale.Snap(14)), "a 200x100 panel's fill corner is the 14-unit radius")
	local r, g, b, a = Tokens.Color("surface")
	assert(W.SameColor(c.fill[5], r, g, b, a), "the fill is the deep tint at the panel opacity")
	assert(W.SameColor(c.frost[5], Tokens.Color("glass")) and W.SameColor(c.frost[1], Tokens.Color("glass")), "the frost is the glass tint")
	local er, eg, eb, ea = Tokens.Color("edgeInner")
	for i = 1, 9 do
		assert(W.SameColor(c.rim[i], er, eg, eb, ea), "the rim is edgeInner on every piece; its texture lights the top")
	end
	local grain = c.noise._points[1]
	assert(W.Near(grain[4], Scale.Snap(14 * (1 - math.sqrt(2) / 2))), "the grain stays inside the round corners")
	c:SetShown(false)
	assert(not c.rim[1]:IsShown() and not c.frost[5]:IsShown() and not c.fill[5]:IsShown(), "SetShown hides every layer")
	c:SetShown(true)
	assert(c.rim[5]:IsShown() and c.frost[5]:IsShown(), "and shows them again")
	local reach = Scale.Snap(Tokens.Size("shadow"))
	local shadowCorner = c.shadow[1]
	assert(W.LastCall(shadowCorner, "SetTexture")[1] == Tokens.Texture("lumenShadow"), "the shadow is the Lumen card shadow, with the card cut out")
	assert(W.Near(shadowCorner:GetWidth(), Scale.Snap(2 * Tokens.Size("shadow"))), "the shadow's corner piece is twice the reach")
	local point = shadowCorner._points[1]
	assert(W.Near(point[4], -reach) and W.Near(point[5], reach), "the shadow corner is centred on the panel's corner, its drop baked into the texture")
	local bottom = c.shadow[7]._points[1]
	assert(W.Near(bottom[4], -reach) and W.Near(bottom[5], -reach), "so the bottom corners line up with the card's cut-out")
	c:SetEdge("accent")
	local ar, ag, ab = Tokens.Color("accent")
	assert(W.SameColor(c.rim[1], ar, ag, ab, 1) and W.SameColor(c.rim[5], ar, ag, ab, 1), "SetEdge recolours the rim")
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.rim[5], ar, ag, ab, 1), "and the colour survives a restyle")
end

-- The window and rail grades: the same card with gilt filament tips on the top left and bottom right corners, set one
-- unit outside the corner and 20 units square at the 14-unit radius, the bottom right one mirrored.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	for _, shape in ipairs({ "window", "rail" }) do
		local frame, c = chrome(env, K, shape)
		assert(c.shapeName == shape, "the chrome knows its shape")
		assert(W.Near(c.fill[1]:GetWidth(), Scale.Snap(14)), shape .. ": rounded 14 units")
		assert(c.gilt and #c.gilt == 2, shape .. ": two gilt tips")
		local tl, br = c.gilt[1], c.gilt[2]
		assert(W.Near(tl:GetWidth(), Scale.Snap(Tokens.Size("gilt"))), "each tip covers 20 units")
		local p1, p2 = tl._points[1], br._points[1]
		assert(p1[1] == "TOPLEFT" and p1[2] == frame and W.Near(p1[4], -Scale.Snap(1)) and W.Near(p1[5], Scale.Snap(1)), "the first tip sits a unit outside the top left corner")
		assert(p2[1] == "BOTTOMRIGHT" and p2[2] == frame and W.Near(p2[4], Scale.Snap(1)) and W.Near(p2[5], -Scale.Snap(1)), "the second a unit outside the bottom right")
		local coords = W.LastCall(br, "SetTexCoord")
		assert(coords[1] == 1 and coords[2] == 0 and coords[3] == 1 and coords[4] == 0, "the bottom right tip is the top left one mirrored")
		assert(W.SameRGB(tl, Tokens.Color("gilt")) and W.SameRGB(br, Tokens.Color("gilt")), "the tips are gilt")
		assert(c.shadow[1]:IsShown(), shape .. "s cast a shadow")
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
	local er, eg, eb, ea = K.Tokens.Color("edgeBar")
	assert(#c.fill == 9 and #c.rim == 9, "a nine-sliced capsule for the track and its rim")
	assert(W.LastCall(c.rim[1], "SetTexture")[1] == K.Tokens.Texture("lumenOutline"), "the rim is even all round")
	assert(W.SameColor(c.rim[1], er, eg, eb, ea) and W.SameColor(c.rim[2], er, eg, eb, ea), "the rim takes the bar's edge token")
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.rim[3], er, eg, eb, ea), "and keeps it through a restyle")
	assert(W.Near(c:Radius(), 9) and W.Near(c.fill[1]:GetWidth(), 9) and W.Near(c.rim[9]:GetWidth(), 9), "an 18-unit bar's corners are 9 units")
	assert(c.shadow == nil and c.frost == nil and c.gilt == nil, "no shadow, frost or gilt on a bar")
end

-- An icon chrome: the socket grade. The dark crystal body, the rim on the small radius, no frost and no gilt, a rim
-- the button colours, and the gold rim only while a proc is up.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	local frame = env.CreateFrame("Frame", nil, Scale.Root())
	frame:SetSize(38, 38)
	local c = K.Widgets.IconChrome(frame)
	assert(c.shapeName == "socket" and c.frost == nil and c.gilt == nil, "a socket: no frost, no gilt")
	assert(W.LastCall(c.rim[1], "SetTexture")[1] == Tokens.Texture("lumenRimSmall"), "its rim is drawn for the small radius")
	assert(W.SameColor(c.fill[5], Tokens.Color("buttonFill")), "on the dark crystal body")
	c:SetRim(0.5, 0.6, 0.7, 1)
	assert(W.SameColor(c.rim[5], 0.5, 0.6, 0.7, 1) and W.SameColor(c.rim[1], 0.5, 0.6, 0.7, 1), "SetRim colours the rim")
	c:SetProc(true)
	assert(W.SameRGB(c.rim[1], Tokens.Color("giltLit")), "a proc lights it gold")
	c:SetRim(0.1, 0.1, 0.1, 1)
	assert(W.SameRGB(c.rim[1], Tokens.Color("giltLit")), "and the gold holds while the proc is up")
	c:SetProc(false)
	assert(W.SameColor(c.rim[1], 0.1, 0.1, 0.1, 1), "then the rim the button set returns")
	assert(not pcall(Tokens.Size, "buttonBezel"), "sockets have no bezel plate")
end

-- A move to a 1440p screen redraws the corners in whole pixels of the same units.
do
	local env, K = W.New()
	env._physical = { 2560, 1440 }
	env.GetPhysicalScreenSize = function()
		return env._physical[1], env._physical[2]
	end
	local frame, c = chrome(env, K, "tile")
	local rim = K.Widgets.NineSlice(frame, "lumenOutline", "BORDER", 0)
	K.Widgets.LayoutSlice(rim, frame, c:Radius(), 0)
	assert(W.Near(c:Radius(), 8), "a 200x100 tile rounds the tile cap, 8 units")
	assert(W.Near(c.fill[1]:GetWidth(), 8) and W.Near(rim[1]:GetWidth(), 8), "8 pixels at 1080p")
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	K.Widgets.LayoutSlice(rim, frame, c:Radius(), 0)
	assert(W.Near(K.Scale.Border(), 0.75), "the border is one 1440p pixel")
	assert(W.Near(c.fill[1]:GetWidth(), K.Scale.Snap(8)) and W.Near(c.rim[1]:GetWidth(), K.Scale.Snap(8)), "the corners are still 8 units, snapped to 1440p pixels")
	assert(W.Near(rim[1]:GetWidth(), c.fill[1]:GetWidth()), "a slice laid out with the chrome's radius lines up with the chrome")
end

-- Bag slots and unit frames recolour chrome on game events, in combat too, so the colour setters allocate nothing.
-- The engine's setters are replaced on each piece: the stubs record each call in a table of their own.
do
	local env, K = W.New()
	local _, c = chrome(env, K, "tile")
	local function noop() end
	for _, list in ipairs({ c.fill, c.shadow, c.rim }) do
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
	-- Growth that happens once, right after a full collection, is not per call: the warm-up runs it before the baseline.
	for _ = 1, 10 do
		work()
	end
	local before = collectgarbage("count")
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
	assert(W.Near(a, 0.6), "the panel opacity sets the fill's alpha")
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
	local reg = env._layout[1]
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
