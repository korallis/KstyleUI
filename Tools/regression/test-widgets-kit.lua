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

local function chrome(env, K, shape, width, height)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(width or 200, height or 100)
	return frame, K.Widgets.Chrome(frame, { shape = shape, fill = "surface", shadow = true })
end

-- The alpha of a line piece against its base colour's alpha.
local function alphaOf(piece)
	return select(4, piece:GetVertexColor())
end

-- Corner cuts follow the mockup: 30% of a backdrop's shorter side, capped per shape (panel 12, tile 6, window 12),
-- so the cast bar, the data strip and the nameplate frame cut deep while a chat window stays at 12. A frame with no
-- size yet takes the cap. Icon buttons cut 12% of their side, as the mockup's cluster and action buttons do.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	assert(W.Near(Tokens.Share("chamfer"), 0.3) and W.Near(Tokens.Share("chamferIcon"), 0.12), "the cut shares are tokens")
	W.Raises(function()
		Tokens.Share("nope")
	end, "unknown name")
	assert(Tokens.Size("chamferPanel") == 12 and Tokens.Size("chamferTile") == 6 and Tokens.Size("chamferWindow") == 12, "the caps")
	local cases = {
		{ "panel", 200, 100, 12 }, { "panel", 300, 30, 9 }, { "panel", 200, 20, 6 },
		{ "window", 400, 200, 12 }, { "window", 200, 30, 9 },
		{ "tile", 200, 100, 6 }, { "tile", 180, 18, 5.4 }, { "tile", 200, 10, 3 },
	}
	for _, case in ipairs(cases) do
		local shape, w, h, want = case[1], case[2], case[3], case[4]
		local _, c = chrome(env, K, shape, w, h)
		assert(W.Near(c:Chamfer(), want), shape .. " " .. w .. "x" .. h .. ": the cut is " .. tostring(c:Chamfer()) .. ", the mockup's rule says " .. want)
		assert(W.Near(c.fill[1]:GetWidth(), Scale.Snap(want)), shape .. " " .. w .. "x" .. h .. ": the fill corner is the cut, snapped")
	end
	local frame, c = chrome(env, K, "tile", 200, 100)
	frame:SetSize(200, 10)
	assert(W.Near(c:Chamfer(), 3) and W.Near(c.fill[1]:GetWidth(), Scale.Snap(3)), "a size change re-cuts the corners through OnSizeChanged, got " .. tostring(c:Chamfer()))
	local bare = env.CreateFrame("Frame", nil, Scale.Root())
	local bc = K.Widgets.Chrome(bare, { shape = "panel" })
	assert(W.Near(bc:Chamfer(), 12), "a frame with no size takes the shape's cap")
	local eframe, explicit = chrome(env, K, "panel", 200, 100)
	explicit:SetChamfer(4)
	assert(W.Near(explicit:Chamfer(), 4), "an explicit chamfer still wins")
	eframe:SetSize(200, 10)
	assert(W.Near(explicit:Chamfer(), 4), "and a size change leaves it pinned")
	explicit:SetChamfer(nil)
	assert(W.Near(explicit:Chamfer(), 3) and W.Near(explicit.fill[1]:GetWidth(), Scale.Snap(3)), "unpinning it returns to the computed cut, laid out at once")
	local icon = env.CreateFrame("Frame", nil, Scale.Root())
	icon:SetSize(34, 34)
	local ic = K.Widgets.IconChrome(icon)
	assert(W.Near(ic:Chamfer(), 34 * 0.12), "an icon tile cuts 12% of its side, got " .. tostring(ic:Chamfer()))
	icon:SetSize(50, 50)
	assert(W.Near(ic:Chamfer(), 6), "and follows a size change")
	local big = env.CreateFrame("Frame", nil, Scale.Root())
	big:SetSize(70, 70)
	assert(W.Near(K.Widgets.IconChrome(big):Chamfer(), 8.4), "the icon share has no cap: a 70-unit cluster button cuts 8.4")
end

-- Chrome: a nine-sliced shadow and fill, and the mockup's bevelled edge: the dark edgeOuter line on the edge, the light
-- line one border inside it, lit on the top and on the cut facets (1.4 and 1.6 times its alpha), plain on the sides
-- and 1.1 on the bottom, and a fading second row at 65% of it one border further in. The shadow reaches 10 units out
-- and drops 2 units, as the mockup's panels cast it.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	local _, c = chrome(env, K, "panel")
	assert(#c.fill == 9 and #c.shadow == 9, "nine pieces each for the fill and the shadow")
	assert(#c.outer == 8 and #c.inner == 8 and #c.fade == 8, "four corners and four lines for each bevel line")
	assert(c.plate == nil, "no plate line without a bezel")
	local tl = c.fill[1]
	local coords = W.LastCall(tl, "SetTexCoord")
	assert(coords[1] == 0 and W.Near(coords[2], 32 / 128) and coords[3] == 0 and W.Near(coords[4], 32 / 128), "the corner piece is the texture's 32-texel corner")
	local w, h = tl:GetSize()
	assert(W.Near(w, Scale.Snap(12)) and W.Near(h, Scale.Snap(12)), "a 200x100 panel's fill corner is the 12-unit cap")
	assert(c.shapeName == "panel" and c.dark == nil and c.hairline == nil, "a panel has the bevel edge and no hairline: the mockup's glass")
	local r, g, b, a = Tokens.Color("surface")
	assert(W.SameColor(c.fill[5], r, g, b, a), "the fill is the surface colour at the panel opacity")
	assert(W.SameColor(c.outer[5], Tokens.Color("edgeOuter")) and W.SameColor(c.outer[1], Tokens.Color("edgeOuter")), "the outer line is edgeOuter all round")
	local er, eg, eb, ea = Tokens.Color("edgeInner")
	assert(W.SameColor(c.inner[7], er, eg, eb, ea) and W.SameColor(c.inner[8], er, eg, eb, ea), "the light line's sides are edgeInner")
	assert(W.SameColor(c.inner[5], er, eg, eb, ea * 1.4), "its top is lit: 1.4 times the alpha, the mockup's bright top edge")
	assert(W.SameColor(c.inner[6], er, eg, eb, ea * 1.1), "its bottom is 1.1 times")
	for i = 1, 4 do
		assert(W.SameColor(c.inner[i], er, eg, eb, ea * 1.6), "each cut facet is lit 1.6 times: the mockup's bright chamfers")
	end
	assert(W.SameColor(c.fade[7], er, eg, eb, ea * 0.65) and W.SameColor(c.fade[5], er, eg, eb, ea * 1.4 * 0.65) and W.SameColor(c.fade[1], er, eg, eb, ea * 1.6 * 0.65), "the fade row is 65% of the light line, side by side: the mockup's second row reads 0.4 to 0.8 of its first")
	local function inset(line)
		return -line[5]._points[1][5]
	end
	local border = Scale.Border()
	assert(W.Near(inset(c.outer), 0) and W.Near(inset(c.inner), border) and W.Near(inset(c.fade), 2 * border), "the dark line on the edge, the light line inside it, the fade row inside that")
	assert(W.Near(c.inner[5]:GetHeight(), border) and W.Near(c.fade[5]:GetHeight(), border), "one border thick")
	local chamfer = c:Chamfer()
	for _, pair in ipairs({ { c.outer, 0 }, { c.inner, border }, { c.fade, 2 * border } }) do
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
	assert(not c.inner[1]:IsShown() and not c.inner[5]:IsShown() and not c.fade[5]:IsShown(), "SetShown hides the lines with the rest")
	c:SetShown(true)
	assert(c.fade[5]:IsShown(), "and shows them again")
	local reach, drop = Scale.Snap(Tokens.Size("shadow")), Scale.Snap(Tokens.Size("shadowOffset"))
	local shadowCorner = c.shadow[1]
	assert(W.Near(shadowCorner:GetWidth(), Scale.Snap(2 * Tokens.Size("shadow"))), "the shadow's corner piece is twice the reach: 10 units of reach each way")
	local point = shadowCorner._points[1]
	assert(W.Near(point[4], -reach) and W.Near(point[5], reach - drop), "the shadow corner is centred on the panel's corner and drops 2 units")
	local bottom = c.shadow[7]._points[1]
	assert(W.Near(bottom[4], -reach) and W.Near(bottom[5], -reach - drop), "the bottom corners drop too, so the shadow reads below the panel")
	c:SetEdge("accent")
	local ar, ag, ab = Tokens.Color("accent")
	assert(W.SameColor(c.inner[7], ar, ag, ab, 1) and W.SameColor(c.inner[5], ar, ag, ab, 1), "SetEdge recolours the light line; an opaque edge stays opaque on its lit sides")
	assert(W.SameColor(c.fade[7], ar, ag, ab, 0.65), "and the fade row follows at 65%")
	c:SetOuterRGBA(0.1, 0.2, 0.3, 0.4)
	assert(W.SameColor(c.outer[5], 0.1, 0.2, 0.3, 0.4) and W.SameColor(c.outer[1], 0.1, 0.2, 0.3, 0.4), "SetOuterRGBA recolours the outer line")
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.outer[5], 0.1, 0.2, 0.3, 0.4), "and the colour survives a restyle")
	c:SetOuter()
	assert(W.SameColor(c.outer[5], Tokens.Color("edgeOuter")), "SetOuter with no token returns to the shape's line")
end

-- ColorLine paints one bevel line with per-side factors, allocating nothing.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	local line = K.Widgets.Line(frame, "BORDER", 0)
	K.Widgets.ColorLine(line, 1, 1, 1, 0.5, { top = 1.4, bottom = 1.1, side = 1, cut = 1.6 })
	assert(W.Near(alphaOf(line[5]), 0.7) and W.Near(alphaOf(line[6]), 0.55) and W.Near(alphaOf(line[7]), 0.5) and W.Near(alphaOf(line[8]), 0.5), "top, bottom and sides")
	for i = 1, 4 do
		assert(W.Near(alphaOf(line[i]), 0.8), "the corners are the cut facets")
	end
	K.Widgets.ColorLine(line, 1, 1, 1, 0.9, { top = 1.4, bottom = 1.1, side = 1, cut = 1.6 })
	assert(W.Near(alphaOf(line[5]), 1) and W.Near(alphaOf(line[1]), 1), "a factor never pushes the alpha past 1")
	K.Widgets.ColorLine(line, 0.2, 0.3, 0.4, 0.5)
	assert(W.SameColor(line[5], 0.2, 0.3, 0.4, 0.5) and W.SameColor(line[1], 0.2, 0.3, 0.4, 0.5), "without factors every piece takes the colour")
end

-- The window grade: the mockup's chat, tracker and strip wear the same bevelled edge as every panel, with a 12-unit
-- chamfer and a shadow. The design file's five-line window edge is gone.
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
	assert(W.SameColor(c.outer[5], Tokens.Color("edgeOuter")) and W.Near(inset(c.outer), 0), "the dark line on the edge")
	local er, eg, eb, ea = Tokens.Color("edgeInner")
	assert(W.SameColor(c.inner[7], er, eg, eb, ea) and W.Near(inset(c.inner), border), "the light line a border in, as on every panel")
	assert(#c.fade == 8 and W.Near(inset(c.fade), 2 * border), "the fade row inside it")
	assert(c.dark == nil and c.hairline == nil, "no further lines: the mockup's windows are the same glass as its panels")
	assert(W.Near(c.outer[1]:GetWidth(), cornerSquare(K, Tokens.Size("chamferWindow"), 0)), "the edge line's corner square")
	for _, line in ipairs({ c.outer, c.inner, c.fade }) do
		assert(W.Near(line[5]:GetHeight(), border), "every line is one border thick")
	end
	assert(c.shadow[1]:IsShown(), "windows cast a shadow")
	c:SetEdge("accent")
	assert(W.SameColor(c.inner[7], Tokens.Color("accent")), "SetEdge recolours the light line")
	W.Raises(function()
		K.Widgets.Chrome(env.CreateFrame("Frame", nil, Scale.Root()), { shape = "disc" })
	end, "shape must be panel, tile or window")
end

-- A bar's edge: the mockup draws its bars with a fainter line, so a chrome takes an edge token, lit the same way.
do
	local env, K = W.New()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(180, 18)
	local c = K.Widgets.Chrome(frame, { shape = "tile", edge = "edgeBar", shadow = false })
	local er, eg, eb, ea = K.Tokens.Color("edgeBar")
	assert(W.SameColor(c.inner[7], er, eg, eb, ea) and W.SameColor(c.inner[5], er, eg, eb, ea * 1.4), "the light line takes the edge token, lit on top")
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameColor(c.inner[7], er, eg, eb, ea), "and keeps it through a restyle")
	assert(W.Near(c:Chamfer(), 5.4), "a 18-unit bar cuts 5.4: the mockup's buff bars")
end

-- An icon chrome: the button grade's body with the rim lit on its top, bottom and cuts and shaded on its sides (0.65),
-- no fade row, and with a bezel a light plate line on the plate's outer edge, 1.25 times edgeInner.
do
	local env, K = W.New()
	local Scale, Tokens = K.Scale, K.Tokens
	local frame = env.CreateFrame("Frame", nil, Scale.Root())
	frame:SetSize(34, 34)
	local c = K.Widgets.IconChrome(frame, { bezel = 3 })
	assert(c.fade == nil, "an icon tile draws no fade row: its rim and halo are its two lines")
	assert(c.plate and #c.plate == 8, "a bezelled icon draws the plate's own light line")
	assert(W.Near(-c.plate[5]._points[1][5], -Scale.Snap(3)), "on the plate's outer edge, 3 units outside the rim")
	local er, eg, eb, ea = Tokens.Color("edgeInner")
	assert(W.SameColor(c.plate[7], er, eg, eb, ea * 1.25) and W.SameColor(c.plate[5], er, eg, eb, ea * 1.25 * 1.4) and W.SameColor(c.plate[1], er, eg, eb, ea * 1.25 * 1.6), "the plate line is edgeInner at 1.25, lit like a panel's edge: the mockup's bright plate outline")
	c:SetRim(0.5, 0.6, 0.7, 1)
	assert(W.SameColor(c.inner[5], 0.5, 0.6, 0.7, 1) and W.SameColor(c.inner[6], 0.5, 0.6, 0.7, 1) and W.SameColor(c.inner[1], 0.5, 0.6, 0.7, 1), "the rim is full on the top, the bottom and the cuts")
	assert(W.SameColor(c.inner[7], 0.5, 0.6, 0.7, 0.65) and W.SameColor(c.inner[8], 0.5, 0.6, 0.7, 0.65), "and shaded on the sides, the mockup's lit-from-above rim")
	assert(W.SameColor(c.outer[5], 0.5, 0.6, 0.7, 0.45), "the halo is uniform")
	c:SetShown(false)
	assert(not c.plate[5]:IsShown(), "SetShown hides the plate line")
	c:SetShown(true)
	assert(c.plate[5]:IsShown())
	local plain = K.Widgets.IconChrome(env.CreateFrame("Frame", nil, Scale.Root()))
	assert(plain.plate == nil, "no bezel, no plate line")
end

-- Review Focus 2: a move to a 1440p screen redraws the lines as whole pixels.
do
	local env, K = W.New()
	env._physical = { 2560, 1440 }
	env.GetPhysicalScreenSize = function()
		return env._physical[1], env._physical[2]
	end
	local frame, c = chrome(env, K, "tile")
	local _, _, textureUnits = K.Tokens.Texture("chamferTile")
	assert(W.Near(textureUnits, 3.5), "the tile texture's corner is drawn at 3.5 units; the chrome stretches it to the cut")
	local rim = K.Widgets.NineSlice(frame, "chamferTile", "BORDER", 0)
	K.Widgets.LayoutSlice(rim, frame, c:Chamfer(), 0)
	assert(W.Near(c.outer[5]:GetHeight(), 1), "one unit at 1080p before the move")
	assert(W.Near(c:Chamfer(), 6), "a 200x100 tile cuts the tile cap, 6 units")
	assert(W.Near(c.fill[1]:GetWidth(), 6) and W.Near(rim[1]:GetWidth(), 6), "a tile's 6-unit chamfer is 6 pixels at 1080p")
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	K.Widgets.LayoutSlice(rim, frame, c:Chamfer(), 0)
	local border = K.Scale.Border()
	assert(W.Near(border, 0.75), "the border is one 1440p pixel")
	assert(W.Near(c.outer[5]:GetHeight(), border), "the line is redrawn one pixel thick")
	assert(W.Near(c.fill[1]:GetWidth(), K.Scale.Snap(6)) and W.Near(c.fill[1]:GetWidth(), 8 * border), "a tile's chamfer is still 6 units: eight 1440p pixels, not six borders")
	assert(W.Near(c.outer[1]:GetWidth(), cornerSquare(K, 6, 0)), "the edge line's corner square follows the chamfer in units")
	assert(W.Near(c.inner[5]:GetHeight(), border) and W.Near(c.fade[5]:GetHeight(), border), "the tile's light line and fade row are redrawn too")
	assert(W.Near(rim[1]:GetWidth(), c.fill[1]:GetWidth()), "a chamfer slice laid out with the chrome's cut lines up with the chrome")
end

-- Bag slots and unit frames recolour chrome on game events, in combat too, so the colour setters allocate nothing.
-- The engine's setters are replaced on each piece: the stubs record each call in a table of their own.
do
	local env, K = W.New()
	local _, c = chrome(env, K, "tile")
	local function noop() end
	for _, list in ipairs({ c.fill, c.shadow, c.outer, c.inner, c.fade }) do
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
