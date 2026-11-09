-- test-legibility.lua: text on the Lumen glass stays readable over bright scenery, small text is a readable sans, Cinzel only sets heads of 12 units and up, and pale fills keep a dark edge.
local W = dofile("Tools/regression/widget_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local env, K = W.New()
local Tokens, Widgets, Theme = K.Tokens, K.Widgets, K.Theme
local root = K.Scale.Root()

local function file(path)
	return path and path:match("([^\\/]+)$")
end

-- WCAG relative luminance and contrast, on the sRGB values the game blends.
local function linear(c)
	return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(r, g, b)
	return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end
local function contrast(a, b)
	local la, lb = luminance(a[1], a[2], a[3]), luminance(b[1], b[2], b[3])
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end
local function over(src, alpha, dst)
	return { src[1] * alpha + dst[1] * (1 - alpha), src[2] * alpha + dst[2] * (1 - alpha), src[3] * alpha + dst[3] * (1 - alpha) }
end
local function rgb(name)
	local r, g, b, a = Tokens.Color(name)
	return { r, g, b }, a
end

-- The frost's vertical stops come from the generator that bakes LumenFrost.png: top band, middle start, middle end, bottom.
local stops = {}
do
	local handle = assert(io.open("Tools/media/make_media.py", "r"))
	local source = handle:read("*a")
	handle:close()
	local list = assert(source:match("\nFROST_STOPS = %(([^)]+)%)"), "make_media.py defines FROST_STOPS")
	for value in list:gmatch("[%d%.]+") do
		stops[#stops + 1] = tonumber(value)
	end
	assert(#stops == 4, "four frost stops")
end

-- A card as Chrome paints it: the scenery, the surface at the panel opacity setting, the frost at its band, the grain.
local NOISE_ALPHA = 0.035
local function card(scenery, band)
	local surface = rgb("surface")
	local glass, glassAlpha = rgb("glass")
	local c = over(surface, Widgets.Setting("panelOpacity"), scenery)
	c = over(glass, glassAlpha * band, c)
	return over({ 1, 1, 1 }, NOISE_ALPHA, c)
end

-- Bright scenery a card sits over in play: a white sky, a pale sky, sand and snow.
local BRIGHT = {
	white = { 1, 1, 1 },
	sky = { 0.75, 0.88, 1 },
	sand = { 0.91, 0.84, 0.66 },
	snow = { 0.96, 0.96, 0.97 },
}
local function worst(colorName, band)
	local low, where = math.huge, nil
	for name, scenery in pairs(BRIGHT) do
		local ratio = contrast(rgb(colorName), card(scenery, band))
		if ratio < low then
			low, where = ratio, name
		end
	end
	return low, where
end

-- Body text sits in the card's middle band; heads and caps in the top band, the frost's lightest.
local middle, top = stops[2], stops[1]
for _, check in ipairs({
	{ "text", middle, 4.5, "body text" },
	{ "textEmphasis", middle, 6, "emphasised text, a clear step above body text" },
	{ "muted", middle, 3, "secondary text" },
	{ "giltLit", top, 4.5, "a gilt section head" },
	{ "textEmphasis", top, 4.5, "a title in the top band" },
}) do
	local ratio, where = worst(check[1], check[2])
	assert(ratio >= check[3], string.format("%s (%s) reads at %.2f:1 over %s scenery; it needs %.1f:1", check[4], check[1], ratio, where, check[3]))
end

-- Fonts: small text is Alegreya Sans, Cinzel only sets heads of 12 units and up, and nothing falls under 10 units.
local CINZEL = "Cinzel-SemiBold.ttf"
local ROLES = { "display", "heading", "title", "body", "caption", "number" }
local function face(role)
	return file((Tokens.Font(role)))
end
local function size(role)
	return (select(2, Tokens.Font(role)))
end
assert(face("caption"):match("^AlegreyaSans"), "captions are Alegreya Sans, not tracked Cinzel; got " .. tostring(face("caption")))
assert(size("caption") >= 11, "captions are at least 11 units; got " .. tostring(size("caption")))
assert(face("title") == CINZEL and size("title") >= 12, "section heads have their own Cinzel role of 12 units or more")
local _, upper = Tokens.TextStyle("title")
assert(upper == true, "section heads are Cinzel capitals")
for _, role in ipairs(ROLES) do
	if face(role) == CINZEL then
		assert(size(role) >= 12, "the " .. role .. " role sets Cinzel at " .. size(role) .. " units; Cinzel needs 12 or more")
	end
end
assert(Theme.SetFontScale(Theme.MIN_FONT_SCALE), "the smallest text size")
for _, role in ipairs(ROLES) do
	assert(size(role) >= 10, "at the smallest text size the " .. role .. " role is " .. size(role) .. " units; text stays at 10 or more")
end
assert(Theme.SetFontScale(1))
local cap = Widgets.SectionCap(root, { text = "Blessings" })
local capPath, capSize = cap.label:GetFont()
assert(file(capPath) == CINZEL and capSize >= 12, "a rail card's section cap is a Cinzel head of 12 units or more")
assert(Widgets.SECTION_CAP_HEIGHT >= size("title"), "the rail's section cap height fits its head")

-- A text shadow strong enough to lift text off busy glass: at least a whole unit, nearly opaque.
local _, _, _, shadowAlpha = Tokens.Color("textShadow")
assert(Tokens.Size("textShadowOffset") >= 1 and shadowAlpha >= 0.85, "text casts a shadow of at least one unit")

-- Pale fills: a white or pale class fill on a bar keeps a dark edge between it and the glass.
do
	local bar = Widgets.StatusBar(root, { width = 200, height = 8, min = 0, max = 1, value = 1 })
	bar:SetPoint("CENTER", root, "CENTER")
	bar:SetBarColor(1, 1, 1)
	local edge = assert(bar.keyline, "a bar with a track draws a keyline around it")
	local r, g, b, a = W.Color(edge)
	local glassBehind = card(BRIGHT.white, middle)
	local ring = over({ r, g, b }, a, glassBehind)
	assert(contrast({ 1, 1, 1 }, ring) >= 3, string.format("a white fill against its keyline reads at %.2f:1; it needs 3:1", contrast({ 1, 1, 1 }, ring)))
	local outer, inner = Geometry.Rect(edge, root), Geometry.Rect(bar, root)
	assert(outer and inner, "the keyline and the bar resolve")
	local px = Widgets.Border(bar)
	assert(outer.left <= inner.left - px + 1e-6 and outer.right >= inner.right + px - 1e-6
		and outer.top >= inner.top + px - 1e-6 and outer.bottom <= inner.bottom - px + 1e-6, "the keyline sits one pixel outside the bar on every side")
	local drawLayer, sublevel = edge:GetDrawLayer()
	local trackLayer, trackSublevel = bar.background:GetDrawLayer()
	assert(drawLayer == trackLayer and (sublevel or 0) < (trackSublevel or 0), "the keyline draws under the track")
	local _, trackAlpha = rgb("track")
	assert(trackAlpha >= 0.85, "the track is dark enough to frame a pale fill")
	local overlay = Widgets.StatusBar(root, { width = 200, height = 8, background = false })
	assert(overlay.keyline == nil, "an overlay bar with no track of its own draws no keyline")
end

-- A capsule bar's glow stays inside the bar's ends: it never runs past the track.
do
	local bar = Widgets.StatusBar(root, { width = 200, height = 8, border = true, min = 0, max = 1, value = 1 })
	local first, last = bar.glow[1], bar.glow[9]
	local function x(region, point)
		for _, p in ipairs(region._points) do
			if p[1] == point then
				return p[4] or 0
			end
		end
	end
	assert(x(first, "TOPLEFT") >= 0, "the glow's left end starts at the fill's left end, got an outset of " .. tostring(-x(first, "TOPLEFT")))
	assert(x(last, "BOTTOMRIGHT") <= 0, "the glow's right end stops at the fill's right end")
end

assert(#env._errors == 0, tostring(env._errors[1]))
print("legibility ok")
