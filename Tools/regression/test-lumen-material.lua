-- test-lumen-material.lua: every chrome grade draws the Lumen recipe (no chamfer texture; the picture card with its edge line, rim and gilt L-ticks; the socket with its near-black edge, gold only on a proc; a pill track for bars), and the font roles resolve to Cinzel and Alegreya Sans with Source Sans still selectable.
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

-- Cards, panels, windows and rails: the owner's picture of 2026-11-09. The card fill, a dark edge line and a muted rim
-- one line inside it, on a corner six border lines round; the shadow is drawn but off unless the setting turns it on.
for _, shape in ipairs({ "panel", "card", "window", "rail" }) do
	local frame, chrome, textures = Build(shape)
	for _, name in ipairs({ "CardShape.png", "RingLine6.png", "RingLine5.png" }) do
		assert(Shown(textures, name), shape .. " draws " .. name)
	end
	assert(textures["LumenShadow.png"] and not Shown(textures, "LumenShadow.png"), shape .. ": the shadow is drawn but hidden, as the picture casts none")
	for _, name in ipairs({ "LumenFrost.png", "LumenRim.png", "LumenGilt.png", "Noise.png" }) do
		assert(not textures[name], shape .. " draws no " .. name)
	end
	local line = Widgets.Border(frame)
	assert(W.Near(chrome:Radius(), 6 * line), shape .. " rounds its corners six lines")
	assert(W.Near(chrome.line[1]:GetWidth(), Widgets.Snap(frame, 6 * line)), shape .. ": the edge line's corner pieces are six lines square")
end

-- Gilt L-ticks on the top left and bottom right of every card shape, the picture's story, chat and damage cards.
for _, shape in ipairs({ "panel", "card", "window", "rail" }) do
	local frame, chrome = Build(shape)
	assert(chrome.gilt and #chrome.gilt == 6, shape .. ": two ticks, each an arc and two legs")
	local p1, p2 = chrome.gilt[1]._points[1], chrome.gilt[4]._points[1]
	assert(p1[1] == "TOPLEFT" and p1[2] == frame and p2[1] == "BOTTOMRIGHT" and p2[2] == frame, shape .. ": the ticks sit on the top left and bottom right corners")
	local gr, gg, gb = Tokens.Color("gilt")
	for i = 1, 6 do
		assert(W.SameRGB(chrome.gilt[i], gr, gg, gb) and chrome.gilt[i]:IsShown(), shape .. ": the ticks are gilt")
	end
end

-- Tiles and sockets: the button fill, a near-black edge line on a three-line corner and a rim one line in, no gilt; a
-- gold edge only on a proc.
for _, shape in ipairs({ "tile", "socket" }) do
	local frame, chrome, textures = Build(shape, 38, 38)
	assert(Shown(textures, "LumenShape.png") and Shown(textures, "RingLine3.png") and Shown(textures, "RingLine2.png"), shape .. " draws the body, the edge line and the rim")
	assert(not Shown(textures, "CardShape.png") and chrome.gilt == nil, shape .. " is not a card and has no gilt")
	assert(W.Near(chrome:Radius(), 3 * Widgets.Border(frame)), shape .. " rounds its corners three lines")
	local sr, sg, sb = Tokens.Color("socketEdge")
	assert(W.SameRGB(chrome.line[1], sr, sg, sb), shape .. ": the edge is near black at rest")
	local lr, lg, lb = Tokens.Color("giltLit")
	chrome:SetProc(true)
	assert(W.SameRGB(chrome.line[1], lr, lg, lb) and W.SameRGB(chrome.line[5], lr, lg, lb), shape .. ": a proc lights the edge gold")
	assert(file(W.LastCall(chrome.line[1], "SetTexture")[1]) == "RingLine3.png", shape .. ": on the same corner")
	assert(W.LastCall(chrome.line[4], "SetColorTexture") ~= nil, shape .. ": its straight runs are solid lines")
	chrome:SetProc(false)
	assert(W.SameRGB(chrome.line[1], sr, sg, sb), shape .. ": the gold leaves with the proc")
end
do
	local r, g, b, a = Tokens.Color("buttonFill")
	local _, chrome = Build("socket", 38, 38)
	assert(W.SameColor(chrome.fill[5], r, g, b, a), "a socket is the button fill")
	assert(a < 1, "the fill is translucent")
end

-- Bars: a pill track, its corners half the bar's short side, so it is a capsule lying down or standing up.
do
	local frame, chrome, textures = Build("bar", 200, 10)
	assert(Shown(textures, "LumenShape.png") and Shown(textures, "LumenOutline.png"), "a bar is a pill track with a faint even rim")
	assert(not Shown(textures, "CardShape.png") and not Shown(textures, "LumenShadow.png") and chrome.gilt == nil, "no card fill, gilt or shadow on a bar")
	assert(W.Near(chrome:Radius(), 5) and W.Near(chrome.fill[1]:GetWidth(), Widgets.Snap(frame, 5)), "the corners are half the height")
	frame:SetSize(10, 120)
	assert(W.Near(chrome:Radius(), 5) and W.Near(chrome.rim[1]:GetHeight(), Widgets.Snap(frame, 5)), "and half the width when the bar stands up")
end

-- The status bar's fill: rounded at both ends by cap masks, with a top sheen and a glow of its own colour.
local function capOf(fill, name)
	for i = 1, fill:GetNumMaskTextures() do
		local mask = fill:GetMaskTexture(i)
		if file(W.LastCall(mask, "SetTexture")[1]) == name then
			return mask
		end
	end
end
do
	local bar = Widgets.StatusBar(root, { width = 200, height = 12, border = true, min = 0, max = 1, value = 0.5 })
	assert(bar.chrome.shapeName == "bar", "a bordered status bar wears the bar grade")
	local trackHeight = bar.borderFrame:GetHeight()
	assert(trackHeight > 12 and W.Near(bar.chrome.fill[1]:GetWidth(), Widgets.Snap(bar.borderFrame, trackHeight / 2)), "the track's corners are half its height once the border is placed, got " .. tostring(bar.chrome.fill[1]:GetWidth()))
	local fill = bar:GetStatusBarTexture()
	assert(fill:GetNumMaskTextures() == 2, "two cap masks round the fill's ends")
	local left, right = capOf(fill, "PillCapLeft.png"), capOf(fill, "PillCapRight.png")
	assert(left and right, "a left and a right cap")
	assert(W.LastCall(right, "SetTexture")[2] == "CLAMPTOWHITE", "outside its square a cap mask lets the fill show")
	assert(right._points[1][2] == fill and left._points[1][2] == bar, "the right cap rides the fill's moving end, the left sits at the start")
	assert(bar.sheenTop and file(W.LastCall(bar.sheenTop, "SetTexture")[1]) == "BarSheen.png", "a top sheen over the fill")
	bar:SetStatusBarColor(0.2, 0.8, 0.4, 1)
	assert(W.SameRGB(bar.glow[1], 0.2, 0.8, 0.4), "the glow takes the fill's own colour")

	-- A module that reverses the fill later gets the caps swapped: the moving end is then the left one.
	bar:SetReverseFill(true)
	assert(left._points[1][2] == fill and right._points[1][2] == bar, "a reversed fill rounds its moving left end")
	bar:SetReverseFill(false)
	assert(right._points[1][2] == fill and left._points[1][2] == bar, "and back")

	-- A bar resized by its caller (DataBars anchors its track to a 4-unit line) keeps round, not stretched, ends.
	bar:SetSize(200, 4)
	assert(W.Near(left:GetWidth(), Widgets.Snap(bar, 4)) and W.Near(right:GetWidth(), Widgets.Snap(bar, 4)), "the caps follow the new height")

	-- A bar turned on end drops the horizontal caps, sheen and glow; turned back, it gets them again.
	bar:SetOrientation("VERTICAL")
	assert(fill:GetNumMaskTextures() == 0 and not bar.sheenTop:IsShown() and not bar.glow[1]:IsShown(), "a vertical fill is not masked by horizontal caps")
	bar:SetOrientation("HORIZONTAL")
	assert(fill:GetNumMaskTextures() == 2 and bar.sheenTop:IsShown() and bar.glow[1]:IsShown(), "a horizontal fill is rounded again")
end
do
	local tall = Widgets.StatusBar(root, { orientation = "VERTICAL", width = 8, height = 120, border = true })
	assert(tall.chrome.shapeName == "bar" and tall:GetStatusBarTexture():GetNumMaskTextures() == 0, "a vertical bar starts with the capsule track and no horizontal caps")
end

-- Fonts: Lumen by default, Source Sans still selectable.
local function face(role)
	return file((Tokens.Font(role)))
end
for role, want in pairs({
	display = "Cinzel-SemiBold.ttf", heading = "Cinzel-SemiBold.ttf", title = "Cinzel-SemiBold.ttf", caption = "AlegreyaSansTabular-Medium.ttf",
	body = "AlegreyaSansTabular-Regular.ttf", number = "AlegreyaSansTabular-ExtraBold.ttf", world = "AlegreyaSansTabular-Medium.ttf",
}) do
	assert(face(role) == want, "the " .. role .. " role is " .. tostring(face(role)) .. ", want " .. want)
end
assert(select(3, Tokens.Font("world")) == "OUTLINE", "world text is outlined")
local tracking = Tokens.TextStyle("caption")
assert(tracking > 0, "captions are tracked")
assert(Tokens.DEFAULT_FONT_FACE == "Lumen", "Lumen is the default face")
assert(Theme.SetFontFace("SourceSans3Semibold"), "Source Sans 3 Semibold is selectable")
for _, role in ipairs({ "display", "heading", "title", "caption", "body", "world" }) do
	assert(face(role) == "SourceSans3-Semibold.ttf", "with Source Sans picked, " .. role .. " is Source Sans")
end
assert(face("number") == "SourceSans3-Semibold.ttf", "and numbers keep Source Sans's tabular digits")
assert(Theme.SetFontFace("Lumen") and face("heading") == "Cinzel-SemiBold.ttf", "Lumen can be picked back")

assert(#env._errors == 0, tostring(env._errors[1]))
print("lumen material ok")
