-- test-lumen-material.lua: every chrome grade draws the Lumen recipe (no chamfer texture, rounded corners, frost and rim, gilt only on windows and rails, a gold rim only on a proc, a pill track for bars), and the font roles resolve to Cinzel and Alegreya Sans with Source Sans still selectable.
local W = dofile("Tools/regression/widget_env.lua")

local env, K = W.New()
local Widgets, Tokens, Scale, Theme = K.Widgets, K.Tokens, K.Scale, K.Theme
local root = Scale.Root()

local function file(path)
	return type(path) == "string" and path:match("([^\\]+)$") or nil
end

-- Textures(frame) -> { [file] = { shown = n, total = n } } for every texture a chrome drew on the frame.
local function Textures(frame)
	local out = {}
	for _, region in ipairs(W.Regions(frame, "Texture")) do
		local call = W.LastCall(region, "SetTexture")
		local name = call and file(call[1])
		if name then
			local entry = out[name] or { shown = 0, total = 0 }
			entry.total = entry.total + 1
			if region:IsShown() then
				entry.shown = entry.shown + 1
			end
			out[name] = entry
		end
	end
	return out
end

local function Shown(textures, name)
	return textures[name] ~= nil and textures[name].shown > 0
end

local function Build(shape, width, height)
	local frame = env.CreateFrame("Frame", nil, root)
	frame:SetSize(width or 300, height or 200)
	local chrome = Widgets.Chrome(frame, { shape = shape })
	return frame, chrome, Textures(frame)
end

-- No grade draws from a chamfer texture or the bevel line strip.
for _, shape in ipairs({ "panel", "card", "window", "rail", "tile", "socket", "bar" }) do
	local _, _, textures = Build(shape)
	for name in pairs(textures) do
		assert(not name:find("Chamfer", 1, true), shape .. " draws the chamfer texture " .. name)
		assert(name ~= "Line.png", shape .. " draws the chamfer bevel line strip")
	end
end

-- Cards, panels, windows and rails: the soft shadow, the deep tint, the frost and the rim, rounded 14 units.
for _, shape in ipairs({ "panel", "card", "window", "rail" }) do
	local frame, chrome, textures = Build(shape)
	for _, name in ipairs({ "LumenShadow.png", "LumenShape.png", "LumenFrost.png", "LumenRim.png" }) do
		assert(Shown(textures, name), shape .. " draws " .. name)
	end
	assert(chrome:Radius() == Tokens.Size("radius") and Tokens.Size("radius") == 14, shape .. " rounds its corners 14 units")
	assert(W.Near(chrome.fill[1]:GetWidth(), Widgets.Snap(frame, 14)), shape .. ": the corner pieces are the 14-unit radius")
end

-- Gilt filament tips on two opposite corners of windows and rails, and none on panels and cards.
for shape, want in pairs({ panel = 0, card = 0, window = 2, rail = 2 }) do
	local _, _, textures = Build(shape)
	local gilt = textures["LumenGilt.png"]
	local shown = gilt and gilt.shown or 0
	assert(shown == want, shape .. " shows " .. shown .. " gilt tips, want " .. want)
end
do
	local frame, chrome = Build("window")
	local tl, br = chrome.gilt[1], chrome.gilt[2]
	local p1, p2 = tl._points[1], br._points[1]
	assert(p1[1] == "TOPLEFT" and p1[2] == frame and p2[1] == "BOTTOMRIGHT" and p2[2] == frame, "the tips sit on the top left and bottom right corners")
	local gr, gg, gb = Tokens.Color("gilt")
	assert(W.SameRGB(tl, gr, gg, gb), "the tips are gilt")
end

-- Tiles and sockets: a dark crystal body, a faint rim on the small radius, no frost, no gilt; gold rim only on a proc.
for _, shape in ipairs({ "tile", "socket" }) do
	local frame, chrome, textures = Build(shape, 38, 38)
	assert(Shown(textures, "LumenShape.png") and Shown(textures, "LumenRimSmall.png"), shape .. " draws the body and the small rim")
	assert(not Shown(textures, "LumenFrost.png") and not Shown(textures, "LumenGilt.png"), shape .. " has no frost and no gilt")
	assert(chrome:Radius() <= Tokens.Size("radiusTile") and chrome:Radius() > 0, shape .. " rounds its corners")
	local rr, rg, rb = chrome.rim[1]:GetVertexColor()
	local lr, lg, lb = Tokens.Color("giltLit")
	assert(not (W.Near(rr, lr) and W.Near(rg, lg) and W.Near(rb, lb)), shape .. ": the rim is not gold at rest")
	chrome:SetProc(true)
	assert(W.SameRGB(chrome.rim[1], lr, lg, lb) and W.SameRGB(chrome.rim[5], lr, lg, lb), shape .. ": a proc lights the rim gold")
	assert(file(W.LastCall(chrome.rim[4], "SetTexture")[1]) == "LumenOutline.png", shape .. ": all the way round, not only along the top")
	chrome:SetProc(false)
	assert(W.SameRGB(chrome.rim[1], rr, rg, rb), shape .. ": the gold leaves with the proc")
	assert(file(W.LastCall(chrome.rim[4], "SetTexture")[1]) == "LumenRimSmall.png", shape .. ": and the rim is lit from the top again")
	assert(frame ~= nil)
end
do
	local r, g, b, a = Tokens.Color("buttonFill")
	local _, chrome = Build("socket", 38, 38)
	assert(W.SameColor(chrome.fill[5], r, g, b, a), "a socket is the dark crystal body")
	assert(a < 1, "the crystal is translucent")
end

-- Bars: a pill track, its round caps the bar's half height.
do
	local frame, chrome, textures = Build("bar", 200, 10)
	assert(Shown(textures, "Pill.png") and Shown(textures, "PillRim.png"), "a bar is a pill track with a faint rim")
	assert(not Shown(textures, "LumenFrost.png") and not Shown(textures, "LumenGilt.png") and not Shown(textures, "LumenShadow.png"), "no frost, gilt or shadow on a bar")
	assert(W.Near(chrome.track[1]:GetWidth(), frame:GetHeight() / 2), "the caps are half the height")
end

-- The status bar's fill: rounded at both ends by cap masks, with a top sheen and a glow of its own colour.
do
	local bar = Widgets.StatusBar(root, { width = 200, height = 12, border = true, min = 0, max = 1, value = 0.5 })
	assert(bar.chrome.shapeName == "bar", "a bordered status bar wears the bar grade")
	local fill = bar:GetStatusBarTexture()
	assert(fill:GetNumMaskTextures() == 2, "two cap masks round the fill's ends")
	local masks = {}
	for i = 1, 2 do
		masks[file(W.LastCall(fill:GetMaskTexture(i), "SetTexture")[1])] = fill:GetMaskTexture(i)
	end
	assert(masks["PillCapLeft.png"] and masks["PillCapRight.png"], "a left and a right cap")
	assert(W.LastCall(masks["PillCapRight.png"], "SetTexture")[2] == "CLAMPTOWHITE", "outside its square a cap mask lets the fill show")
	assert(masks["PillCapRight.png"]._points[1][2] == fill, "the right cap rides the fill's moving end")
	assert(bar.sheenTop and file(W.LastCall(bar.sheenTop, "SetTexture")[1]) == "BarSheen.png", "a top sheen over the fill")
	bar:SetStatusBarColor(0.2, 0.8, 0.4, 1)
	assert(W.SameRGB(bar.glow[1], 0.2, 0.8, 0.4), "the glow takes the fill's own colour")
end

-- Fonts: Lumen by default, Source Sans still selectable.
local function face(role)
	return file((Tokens.Font(role)))
end
for role, want in pairs({
	display = "Cinzel-SemiBold.ttf", heading = "Cinzel-SemiBold.ttf", caption = "Cinzel-SemiBold.ttf",
	body = "AlegreyaSansTabular-Regular.ttf", number = "AlegreyaSansTabular-Bold.ttf", world = "AlegreyaSansTabular-Medium.ttf",
}) do
	assert(face(role) == want, "the " .. role .. " role is " .. tostring(face(role)) .. ", want " .. want)
end
assert(select(3, Tokens.Font("world")) == "OUTLINE", "world text is outlined")
local tracking = Tokens.TextStyle("caption")
assert(tracking > 0, "captions are tracked")
assert(Tokens.DEFAULT_FONT_FACE == "Lumen", "Lumen is the default face")
assert(Theme.SetFontFace("SourceSans3Semibold"), "Source Sans 3 Semibold is selectable")
for _, role in ipairs({ "display", "heading", "caption", "body", "world" }) do
	assert(face(role) == "SourceSans3-Semibold.ttf", "with Source Sans picked, " .. role .. " is Source Sans")
end
assert(face("number") == "SourceSans3-Semibold.ttf", "and numbers keep Source Sans's tabular digits")
assert(Theme.SetFontFace("Lumen") and face("heading") == "Cinzel-SemiBold.ttf", "Lumen can be picked back")

assert(#env._errors == 0, tostring(env._errors[1]))
print("lumen material ok")
