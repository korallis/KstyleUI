-- test-statusbar-square.lua: a bordered status bar is the bible's clean square bar (KSTY-60 item 10) at every screen and size: no capsule caps, masks, fill glow, top sheen or rounded chrome; a black pixel, then one of 45 percent black, round a dark track, both outside the bar on whole physical pixels and under its fill; the kit bar's lit top line and shade on the fill; and the same edge reused, not stacked, when a skin asks twice.
local W = dofile("Tools/regression/widget_env.lua")

local SCREENS = { { 1920, 1080 }, { 5120, 1440 }, { 3440, 1440 }, { 2560, 1440 }, { 3840, 2160 }, { 1280, 720 } }

local function corner(region, point)
	for _, p in ipairs(region._points or {}) do
		if p[1] == point then
			return p[2], p[4], p[5]
		end
	end
end

local function pixels(K, frame, units)
	return units * K.Widgets.ScaleFactor(frame) / K.Scale.Pixel(1)
end

local function masks(region)
	return region and region:GetNumMaskTextures() or 0
end

for _, screen in ipairs(SCREENS) do
	for _, size in ipairs({ "auto", "default" }) do
		local where = string.format("%dx%d size %s", screen[1], screen[2], size)
		local env, K = W.New({ width = screen[1], height = screen[2], uiScale = 768 / 1080, size = size, fit = true })
		local Widgets = K.Widgets
		local bar = Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 8, border = true, background = "track", min = 0, max = 1, value = 0.5 })
		local fill = bar:GetStatusBarTexture()
		assert(bar.caps == nil and bar.glow == nil and bar.sheenTop == nil and bar.chrome == nil, where .. ": no capsule caps, fill glow, top sheen or rounded chrome")
		assert(masks(fill) == 0 and masks(bar.background) == 0, where .. ": the fill and the track keep square ends")
		local edge = bar.barEdge
		assert(edge and edge.target == bar, where .. ": the border is the square bar edge, drawn on the bar itself")
		for _, name in ipairs({ "soft", "hard", "track" }) do
			assert(edge[name]:GetDrawLayer() == "BACKGROUND" and edge[name]:GetParent() == bar, where .. ": the edge's " .. name .. " sits in the bar's BACKGROUND, under its fill")
		end
		edge:SetShown(false)
		assert(not edge.hard:IsShown() and not edge.track:IsShown(), where .. ": the edge can be switched off")
		edge:SetShown(true)
		assert(W.SameColor(edge.hard, K.Tokens.Color("black")), where .. ": the first edge pixel is black")
		assert(W.SameColor(edge.soft, K.Tokens.Color("barEdgeSoft")), where .. ": the second is 45 percent black")
		assert(W.SameColor(edge.track, K.Tokens.Color("barTrack")), where .. ": round the dark track")
		for name, want in pairs({ hard = 1, soft = 2 }) do
			local region = edge[name]
			for _, point in ipairs({ "TOPLEFT", "BOTTOMRIGHT" }) do
				local rel, x, y = corner(region, point)
				assert(rel == bar, where .. ": the " .. name .. " edge hangs on the bar")
				local sx = point == "TOPLEFT" and -1 or 1
				assert(math.abs(pixels(K, bar, x) - sx * want) < 1e-6 and math.abs(pixels(K, bar, y) + sx * want) < 1e-6,
					where .. ": the " .. name .. " edge stands " .. want .. " physical pixels outside the bar's " .. point .. ", got " .. tostring(pixels(K, bar, x)))
			end
		end
		assert(bar.lit and bar.shade, where .. ": the fill takes the kit bar's lit top line and shade")
		assert(corner(bar.lit, "TOPLEFT") == fill and math.abs(pixels(K, bar, bar.lit:GetHeight()) - 1) < 1e-6, where .. ": the lit line is one physical pixel on the fill's top edge")
		bar:SetOrientation("VERTICAL")
		bar:SetReverseFill(true)
		assert(masks(fill) == 0 and bar.caps == nil, where .. ": turning or reversing the bar adds no caps")
		assert(Widgets.BarEdge(bar) == edge, where .. ": a second request reuses the bar's edge")
		local skinned = env.CreateFrame("StatusBar", nil, K.Scale.Root())
		local unit = K.Scale.Pixel(1) / Widgets.ScaleFactor(skinned)
		skinned:SetSize(unit * 120.4, unit * 9.6)
		local skin = Widgets.BarEdge(skinned)
		local _, farX, farY = corner(skin.hard, "BOTTOMRIGHT")
		assert(math.abs(pixels(K, skinned, farX) - (1 - 0.4)) < 1e-6 and math.abs(pixels(K, skinned, farY) + (1 + 0.4)) < 1e-6,
			where .. ": a Blizzard bar of a fractional size gets its far corners pulled onto whole pixels, got " .. tostring(pixels(K, skinned, farX)) .. ", " .. tostring(pixels(K, skinned, farY)))
		assert(skin.track and corner(skin.track, "TOPLEFT") == skinned and skin.track:GetParent() == skinned and skin.regions[skin.track], where .. ": a skinned Blizzard bar gets the same edge and track under its fill, its regions listed for the skin's strip to keep")
		assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	end
end
print("ok status bar square")
