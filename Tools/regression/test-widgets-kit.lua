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
	for _, name in ipairs({ "chamferPanel", "chamferTile", "chamferWindow", "shadow" }) do
		assert(names[name], name .. " is a sliced texture")
	end
end

-- The geometry of one bevel line on a chamfered rectangle: the straight pieces are one border thick, and each
-- corner piece is the square that holds the diagonal band between the straight pieces.
local SQRT2 = math.sqrt(2)
local function cornerSquare(K, chamfer, at)
	local border = K.Scale.Border()
	return K.Scale.Snap(K.Scale.Snap(chamfer) - at * (2 - SQRT2) + border * (SQRT2 - 1))
end

local function chrome(env, K, shape)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(200, 100)
	return frame, K.Widgets.Chrome(frame, { shape = shape, fill = "surface", shadow = true })
end

-- Chrome: a nine-sliced shadow and fill, and a bevel whose straight lines are one border thick.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	local _, c = chrome(env, K, "panel")
	assert(#c.fill == 9 and #c.shadow == 9, "nine pieces each for the fill and the shadow")
	assert(#c.outer == 8 and #c.inner == 8, "four corners and four lines for each bevel line")
	local tl = c.fill[1]
	local coords = W.LastCall(tl, "SetTexCoord")
	assert(coords[1] == 0 and W.Near(coords[2], 32 / 128) and coords[3] == 0 and W.Near(coords[4], 32 / 128), "the corner piece is the texture's 32-texel corner")
	local w, h = tl:GetSize()
	assert(W.Near(w, Scale.Snap(8)) and W.Near(h, Scale.Snap(8)), "a panel's fill corner is 8 units")
	assert(c.shapeName == "panel" and c.dark == nil, "a panel has the three-line edge and no dark inner line")
	local r, g, b, a = Tokens.Color("surface")
	assert(W.SameColor(c.fill[5], r, g, b, a), "the fill is the surface colour at the panel opacity")
	assert(W.SameColor(c.outer[5], Tokens.Color("edgeOuter")), "the outer line is edgeOuter")
	assert(W.SameColor(c.inner[5], Tokens.Color("edgeInner")), "the inner line is edgeInner")
	assert(#c.hairline == 8 and W.SameColor(c.hairline[5], Tokens.Color("edgeFaint")), "the kit's third line: a faint hairline")
	local function inset(line)
		return -line[5]._points[1][5]
	end
	local border = Scale.Border()
	assert(W.Near(inset(c.outer), 0) and W.Near(inset(c.inner), border), "the dark line on the edge, the light line inside it")
	assert(W.Near(inset(c.hairline), border + Scale.Snap(2)), "and the hairline two units of glass further in, as the design's small panel")
	assert(W.Near(c.hairline[5]:GetHeight(), border), "one border thick")
	local chamfer = Tokens.Size("chamferPanel")
	for _, pair in ipairs({ { c.outer, 0 }, { c.inner, border }, { c.hairline, border + Scale.Snap(2) } }) do
		local line, at = pair[1], pair[2]
		local square = cornerSquare(K, chamfer, at)
		for i = 1, 4 do
			assert(W.Near(line[i]:GetWidth(), square) and W.Near(line[i]:GetHeight(), square), "each corner piece is the diagonal's square: " .. square)
			assert(W.LastCall(line[i], "SetTexture")[1] == Tokens.Texture("line"), "drawn from the line strip texture")
			assert(#W.LastCall(line[i], "SetTexCoord") == 8, "mapped onto the diagonal with eight texture coordinates")
		end
		assert(W.Near(line[5]._points[1][4], at + square), "the straight top line starts where the corner square ends")
		assert(W.Near(line[5]:GetHeight(), border), "and is one border thick")
	end
	c:SetShown(false)
	assert(not c.hairline[1]:IsShown() and not c.hairline[5]:IsShown(), "SetShown hides the hairline with the rest")
	c:SetShown(true)
	assert(W.Near(c.outer[5]:GetHeight(), Scale.Border()), "the top line is one border thick")
	local shadowCorner = c.shadow[1]
	assert(W.Near(shadowCorner:GetWidth(), Scale.Snap(12)), "the shadow's corner piece is 12 units: 6 units of reach each way")
	local point = shadowCorner._points[1]
	assert(W.Near(point[4], -Scale.Snap(6)) and W.Near(point[5], Scale.Snap(6)), "the shadow corner is centred on the panel's corner")
	c:SetEdge("accent")
	assert(W.SameColor(c.inner[5], Tokens.Color("accent")), "SetEdge recolours the inner line")
	c:SetOuterRGBA(0.1, 0.2, 0.3, 0.4)
	assert(W.SameColor(c.outer[5], 0.1, 0.2, 0.3, 0.4) and W.SameColor(c.outer[1], 0.1, 0.2, 0.3, 0.4), "SetOuterRGBA recolours the outer line")
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.outer[5], 0.1, 0.2, 0.3, 0.4), "and the colour survives a restyle")
	c:SetOuter()
	assert(W.SameColor(c.outer[5], Tokens.Color("edgeOuter")), "SetOuter with no token returns to the shape's line")
end

-- The window grade, from the design's GLASS PANEL: a 35% line on the edge, three borders of glass, a 50% line, a dark line
-- and a 15% hairline, seven borders deep, with 10-border chamfers and a shadow.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	local _, c = chrome(env, K, "window")
	local border = Scale.Border()
	local function inset(line)
		return -line[5]._points[1][5]
	end
	assert(c.shapeName == "window", "the chrome knows its shape")
	assert(W.Near(c.fill[1]:GetWidth(), Scale.Snap(Tokens.Size("chamferWindow"))), "a window's chamfer is 12 units, in units on every screen")
	assert(W.SameColor(c.outer[5], Tokens.Color("edgeWindowOuter")) and W.Near(inset(c.outer), 0), "the 35% line on the edge")
	assert(W.SameColor(c.inner[5], Tokens.Color("edgeWindowInner")) and W.Near(inset(c.inner), Scale.Snap(3.75)), "the 50% line 3.75 units in")
	assert(c.dark and #c.dark == 8 and W.SameColor(c.dark[5], Tokens.Color("edgeOuter")) and W.Near(inset(c.dark), Scale.Snap(3.75) + border), "the dark line right inside it")
	assert(W.SameColor(c.hairline[5], Tokens.Color("edgeWindowFaint")) and W.Near(inset(c.hairline), Scale.Snap(6.25)), "the 15% hairline 6.25 units in")
	assert(W.Near(c.outer[1]:GetWidth(), cornerSquare(K, Tokens.Size("chamferWindow"), 0)), "the edge line's corner square")
	for _, line in ipairs({ c.outer, c.inner, c.dark, c.hairline }) do
		assert(W.Near(line[5]:GetHeight(), border), "every line is one border thick")
	end
	assert(c.shadow[1]:IsShown(), "windows cast a shadow")
	c:SetShown(false)
	assert(not c.dark[1]:IsShown() and not c.dark[5]:IsShown(), "SetShown hides the dark line too")
	c:SetEdge("accent")
	assert(W.SameColor(c.inner[5], Tokens.Color("accent")), "SetEdge recolours the bright inner line")
	W.Raises(function()
		K.Widgets.Chrome(env.CreateFrame("Frame", nil, Scale.Root()), { shape = "disc" })
	end, "shape must be panel, tile or window")
end

-- Review Focus 2: a move to a 1440p screen redraws the lines as whole pixels.
do
	local env, K = W.New()
	env._physical = { 2560, 1440 }
	env.GetPhysicalScreenSize = function()
		return env._physical[1], env._physical[2]
	end
	local frame, c = chrome(env, K, "tile")
	local _, _, chamferUnits = K.Tokens.Texture("chamferTile")
	local rim = K.Widgets.NineSlice(frame, "chamferTile", "BORDER", 0)
	K.Widgets.LayoutSlice(rim, frame, chamferUnits, 0)
	assert(W.Near(c.outer[5]:GetHeight(), 1), "one unit at 1080p before the move")
	assert(W.Near(chamferUnits, 3.5), "the tile texture's corner is the tile's 3.5-unit chamfer")
	assert(W.Near(c.fill[1]:GetWidth(), 4) and W.Near(rim[1]:GetWidth(), 4), "a tile's 3.5-unit chamfer snaps to 4 pixels at 1080p")
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	K.Widgets.LayoutSlice(rim, frame, chamferUnits, 0)
	local border = K.Scale.Border()
	assert(W.Near(border, 0.75), "the border is one 1440p pixel")
	assert(W.Near(c.outer[5]:GetHeight(), border), "the line is redrawn one pixel thick")
	assert(W.Near(c.fill[1]:GetWidth(), K.Scale.Snap(3.5)) and W.Near(c.fill[1]:GetWidth(), 5 * border), "a tile's chamfer is still 3.5 units: five 1440p pixels, not three borders")
	assert(W.Near(c.outer[1]:GetWidth(), cornerSquare(K, 3.5, 0)), "the edge line's corner square follows the chamfer in units")
	assert(W.Near(c.hairline[5]:GetHeight(), border), "the tile's hairline is redrawn too")
	assert(W.Near(rim[1]:GetWidth(), c.fill[1]:GetWidth()), "a chamfer slice laid out by LayoutSlice lines up with the chrome")
end

-- Bag slots and unit frames recolour chrome on game events, in combat too, so the colour setters allocate nothing.
-- The engine's setters are replaced on each piece: the stubs record each call in a table of their own.
do
	local env, K = W.New()
	local _, c = chrome(env, K, "tile")
	local function noop() end
	for _, list in ipairs({ c.fill, c.shadow, c.outer, c.inner, c.hairline }) do
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
