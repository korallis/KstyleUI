-- test-widgets-statusbar.lua: the status bar: texture, background, spark and sheen, with values that go only to the engine's setters.
local W = dofile("Tools/regression/widget_env.lua")

local function withEnum(e)
	e.Enum = { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 } }
end

-- Secret values pass to SetMinMaxValues and SetValue untouched, eased by the engine.
do
	local env, K = W.New({ setup = withEnum })
	local Tokens = K.Tokens
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 18, smooth = true, spark = true })
	assert(bar:GetObjectType() == "StatusBar")
	assert(W.LastCall(bar, "SetStatusBarTexture")[1] == Tokens.Texture("barGlass"), "the Glass texture by default")
	assert(W.SameRGB({ GetVertexColor = function()
		return bar:GetStatusBarColor()
	end }, Tokens.Color("accent")), "the accent by default")
	assert(bar.background and W.SameColor(bar.background, Tokens.Color("track")), "a track-coloured background")
	local high, value = env.Secret(4020), env.Secret(2240)
	bar:SetBarRange(0, high)
	local range = W.LastCall(bar, "SetMinMaxValues")
	assert(range[1] == 0 and range[2] == high, "the range reaches the engine untouched")
	bar:SetBarValue(value)
	local call = W.LastCall(bar, "SetValue")
	assert(call[1] == value and call[2] == 1, "a secret value goes to SetValue with the engine's ease-out")
	local spark = bar.spark
	assert(spark and spark:IsShown(), "a spark")
	local p = spark._points[1]
	assert(p[1] == "CENTER" and p[2] == bar:GetStatusBarTexture() and p[3] == "RIGHT", "the spark rides the fill's edge, so Lua never reads the value")
	assert(W.LastCall(spark, "SetBlendMode")[1] == "ADD")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Without smoothing, or on a client without the interpolation enum, SetValue gets the value alone.
do
	local env, K = W.New({ setup = withEnum })
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 100, height = 10 })
	bar:SetBarValue(5)
	assert(W.LastCall(bar, "SetValue").n == 1, "no interpolation unless asked")
	assert(bar.spark == nil or bar.spark:IsShown() == false, "no spark unless asked")
	local env2, K2 = W.New()
	local smooth = K2.Widgets.StatusBar(K2.Scale.Root(), { smooth = true })
	smooth:SetBarValue(env2.Secret(7))
	assert(W.LastCall(smooth, "SetValue").n == 1, "a client without the enum sets the value directly")
	assert(#env._errors == 0 and #env2._errors == 0)
end

-- Colour: an accent bar follows the class colour; a token or a colour of the caller's stays put.
do
	local _, K = W.New()
	local accent = K.Widgets.StatusBar(K.Scale.Root(), {})
	local hostile = K.Widgets.StatusBar(K.Scale.Root(), { color = "hostile" })
	K.Theme.SetCustomAccent(0.2, 0.5, 0.9)
	K.Theme.SetAccentSource("custom")
	local function color(bar)
		return { GetVertexColor = function()
			return bar:GetStatusBarColor()
		end }
	end
	assert(W.SameRGB(color(accent), 0.2, 0.5, 0.9), "an accent bar follows the accent")
	assert(W.SameRGB(color(hostile), K.Tokens.Color("hostile")), "a token bar keeps its token")
	accent:SetBarColor(0.1, 0.2, 0.3)
	K.Theme.SetCustomAccent(0.9, 0.9, 0.1)
	assert(W.SameRGB(color(accent), 0.1, 0.2, 0.3), "a caller's colour stays through a theme change")
	accent:SetColorToken("accent")
	assert(W.SameRGB(color(accent), 0.9, 0.9, 0.1), "and SetColorToken returns to a token")
	-- SetFillColor recolours the fill alone, one widget call, for the combat paths that recolour many bars at once;
	-- the colour sticks through a theme change and a later Paint, as SetBarColor's does.
	local sparked = K.Widgets.StatusBar(K.Scale.Root(), { spark = true })
	local function sparkCalls()
		local n = 0
		for _, call in ipairs(sparked.spark._calls) do
			if call.method == "SetVertexColor" then
				n = n + 1
			end
		end
		return n
	end
	local before = sparkCalls()
	sparked:SetFillColor(0.3, 0.6, 0.9)
	assert(W.SameRGB(color(sparked), 0.3, 0.6, 0.9), "SetFillColor colours the fill")
	assert(sparkCalls() == before, "and leaves the spark alone")
	K.Theme.SetCustomAccent(0.2, 0.5, 0.9)
	sparked:Paint()
	assert(W.SameRGB(color(sparked), 0.3, 0.6, 0.9), "the fill colour is the bar's own from then on")
	accent:SetColorToken("accent")
	accent:SetBarTexture("Flat")
	assert(W.LastCall(accent, "SetStatusBarTexture")[1] == K.Tokens.Texture("barFlat"), "a media key picks a bundled texture")
	accent:SetBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	assert(W.LastCall(accent, "SetStatusBarTexture")[1] == "Interface\\TargetingFrame\\UI-StatusBar", "a path is used as is")
	assert(W.LastCall(accent.background, "SetTexture")[1] == "Interface\\TargetingFrame\\UI-StatusBar", "the background follows the texture")
end

-- The sheen crosses the bar on an AnimationGroup, clipped to the bar; reduced motion skips it.
do
	local env, K = W.New()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 180, height = 18, sheen = true })
	assert(bar.sheenClip and W.LastCall(bar.sheenClip, "SetClipsChildren")[1] == true, "the sheen is clipped to the bar")
	bar:PlaySheen()
	assert(#W.Calls(bar.sheenAnim, "Play") == 1 and bar.sheen:IsShown(), "PlaySheen plays one pass")
	local move = bar.sheenMove
	assert(W.LastCall(move, "SetDuration")[1] == K.Tokens.Duration("castSheen"), "over the cast sheen duration")
	assert(W.LastCall(move, "SetOffset")[1] > 180, "across the whole bar")
	bar:PlaySheen(true)
	assert(W.LastCall(bar.sheenAnim, "SetLooping")[1] == "REPEAT", "or on a loop")
	bar:StopSheen()
	assert(#W.Calls(bar.sheenAnim, "Stop") >= 1 and bar.sheen:IsShown() == false)
	bar:PlaySheen(true)
	local stops = #W.Calls(bar.sheenAnim, "Stop")
	K.Options.Write("Appearance", "motion", "off")
	assert(#W.Calls(bar.sheenAnim, "Stop") > stops and bar.sheen:IsShown() == false, "turning reduced motion on stops a looping sheen")
	bar:PlaySheen()
	assert(#W.Calls(bar.sheenAnim, "Play") == 3, "reduced motion plays no sheen")
	assert(#env._errors == 0)
end

-- A duration object goes to SetTimerDuration; vertical bars put the spark on the top edge.
do
	local _, K = W.New()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { orientation = "VERTICAL", spark = true, width = 18, height = 120 })
	assert(W.LastCall(bar, "SetOrientation")[1] == "VERTICAL")
	local p = bar.spark._points[1]
	assert(p[2] == bar:GetStatusBarTexture() and p[3] == "TOP", "a vertical spark rides the top edge")
	assert(bar.spark:GetWidth() <= 18 * 2 and bar.spark:GetHeight() < 20, "a vertical spark spans the bar's width, got " .. bar.spark:GetWidth())
	local object = {}
	assert(bar:SetBarDuration(object) == true and W.LastCall(bar, "SetTimerDuration")[1] == object, "a duration object reaches the engine")
	local reversed = K.Widgets.StatusBar(K.Scale.Root(), { reverse = true, spark = true })
	assert(W.LastCall(reversed, "SetReverseFill")[1] == true and reversed.spark._points[1][3] == "LEFT", "a reversed spark rides the left edge")
	local plain = K.Widgets.StatusBar(K.Scale.Root(), { background = false, border = true })
	assert(plain.background == nil and plain.chrome, "no background, and a pill track when asked")
	assert(plain.chrome.shapeName == "bar" and plain.chrome.fillName == "surface" and W.SameColor(plain.chrome.rim[1], K.Tokens.Color("edgeBar")), "the border is the bar grade: a pill track with the faint bar edge")
	local lined = K.Widgets.StatusBar(K.Scale.Root(), { background = false, border = true, edge = "edgeInner" })
	assert(W.SameColor(lined.chrome.rim[1], K.Tokens.Color("edgeInner")), "a bar may ask for the panel edge instead")
end

-- Combat paths recolour and retexture bars on every cast and unit event, so the setters allocate nothing.
-- The engine's setters are replaced on the bar: the stubs record each call in a table of their own.
do
	local _, K = W.New()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { spark = true, sheen = true })
	local function noop() end
	for _, region in ipairs({ bar, bar.background, bar.spark, bar.sheen, bar.lit }) do
		region.SetVertexColor, region.SetTexture = noop, noop
	end
	bar.SetStatusBarColor, bar.SetStatusBarTexture = noop, noop
	local path = "Interface\\TargetingFrame\\UI-StatusBar"
	local function work()
		bar:SetBarColor(0.1, 0.2, 0.3)
		bar:SetBarColor(0.4, 0.5, 0.6, 0.7)
		bar:SetColorToken("hostile")
		bar:SetBarTexture("Flat")
		bar:SetBarTexture("Glass")
		bar:SetBarTexture(path)
		bar:SetBarTexture(nil)
		bar:SetBarTexture(path)
		bar:SetBarTexture(path)
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
	assert(grown == 0, "SetBarColor, SetColorToken and SetBarTexture allocated " .. grown .. " KB over 1000 rounds")
end

-- A colour the caller set survives a token round trip in either order, and a texture set twice reaches the engine once.
do
	local _, K = W.New()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), {})
	local function rgba()
		return bar:GetStatusBarColor()
	end
	bar:SetBarColor(0.1, 0.2, 0.3, 0.4)
	local r, g, b, a = rgba()
	assert(W.Near(r, 0.1) and W.Near(g, 0.2) and W.Near(b, 0.3) and W.Near(a, 0.4), "four channels reach the engine")
	bar:SetBarColor(0.5, 0.6, 0.7)
	local call = W.LastCall(bar, "SetStatusBarColor")
	assert(call.n == 3 and W.Near(call[1], 0.5) and W.Near(call[3], 0.7), "three channels reach the engine as three, got " .. call.n)
	bar:SetColorToken("hostile")
	assert(W.SameRGB({ GetVertexColor = rgba }, K.Tokens.Color("hostile")), "the token replaces the caller's colour")
	bar:SetBarColor(0.2, 0.3, 0.4)
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameRGB({ GetVertexColor = rgba }, 0.2, 0.3, 0.4), "the caller's colour comes back after the token and survives a restyle")
	bar:SetBarTexture("Soft")
	local calls = #W.Calls(bar, "SetStatusBarTexture")
	bar:SetBarTexture("Soft")
	assert(#W.Calls(bar, "SetStatusBarTexture") == calls, "the same texture again changes nothing")
	bar:SetBarTexture(K.Tokens.Texture("barSoft"))
	assert(#W.Calls(bar, "SetStatusBarTexture") == calls, "the key's own path is the same texture")
	bar:SetBarTexture(nil)
	assert(W.LastCall(bar, "SetStatusBarTexture")[1] == K.Tokens.Texture("barGlass"), "nil returns to the Glass default")
	assert(W.LastCall(bar.background, "SetTexture")[1] == K.Tokens.Texture("barGlass"), "and the background follows")
end

-- Owner pass 1 (M6, "two similar flat blues"): a flat bar reads as a lit, shaded object. A lit line one border tall
-- rides the fill's top and a shade darkens the fill toward its foot, so a health bar over a power bar of a similar
-- hue separates by tone at their shared edge while each keeps its own colour.
do
	local _, K = W.New({ setup = function(e)
		e.CreateColor = function(r, g, b, a)
			return { r = r, g = g, b = b, a = a, GetRGBA = function(c) return c.r, c.g, c.b, c.a end }
		end
	end })
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 13, background = "track" })
	local fill = bar:GetStatusBarTexture()
	assert(bar.lit and select(2, bar.lit:GetPoint(1)) == fill, "the lit line rides the fill")
	assert(bar.shade, "the fill carries a shade")
	local a, b = { bar.shade:GetPoint(1) }, { bar.shade:GetPoint(2) }
	assert(a[2] == fill and b[2] == fill, "the shade covers the fill, so it follows the value")
	local g = bar.shade._state.Gradient
	assert(g and g[1] == "VERTICAL", "a vertical gradient")
	local foot, top = g[2], g[3]
	assert(foot.r == 0 and foot.g == 0 and foot.b == 0 and foot.a > 0 and foot.a <= 0.4, "dark at the foot, never heavier than 40%")
	assert(top.a == 0, "clear at the top, under the lit line")
	local plain = K.Widgets.StatusBar(K.Scale.Root(), { background = false })
	assert(not plain.shade and not plain.lit, "an overlay bar with no track (prediction, absorbs) adds no edge or shade")
	local pill = K.Widgets.StatusBar(K.Scale.Root(), { border = true })
	assert(not pill.shade and not pill.lit, "a pill bar keeps its own sheen")
end

local function byte(value)
	return math.floor(value * 255 + 0.5)
end

local function withColor(e)
	e.CreateColor = function(r, g, b, a)
		return {
			r = r, g = g, b = b, a = a or 1,
			SetRGBA = function(c, nr, ng, nb, na)
				c.r, c.g, c.b, c.a = nr, ng, nb, na
			end,
		}
	end
end

-- The picture's vertical fill ramp lives on the kit bar. A secret colour never enters the gradient,
-- and a texture other than Flat keeps the plain colour call.
do
	local env, K = W.New({ setup = withColor })
	local function stops(kind, token, top, bottom)
		local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 14 })
		bar:SetBarTexture("Flat")
		local r, g, b = K.Tokens.Color(token)
		bar:SetFillRamp(r, g, b, kind)
		local gradient = bar:GetStatusBarTexture()._state.Gradient
		assert(gradient and gradient[1] == "VERTICAL", kind .. " ramps vertically")
		local hi, lo = gradient[3], gradient[2]
		assert(byte(hi.r) == top[1] and byte(hi.g) == top[2] and byte(hi.b) == top[3], kind .. " top")
		assert(byte(lo.r) == bottom[1] and byte(lo.g) == bottom[2] and byte(lo.b) == bottom[3], kind .. " bottom")
	end
	stops("health", "hudPlayerHealth", { 46, 109, 213 }, { 41, 98, 192 })
	stops("target", "hudTargetHealth", { 208, 74, 67 }, { 179, 58, 53 })
	stops("power", "hudMana", { 62, 62, 242 }, { 57, 57, 221 })
	stops("plate", "plateHostile", { 208, 74, 67 }, { 179, 59, 54 })
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 14 })
	bar:SetBarTexture("Glass")
	local r, g, b = K.Tokens.Color("hudPlayerHealth")
	bar:SetFillRamp(r, g, b, "health")
	local plain = W.LastCall(bar, "SetStatusBarColor")
	assert(plain and W.Near(plain[1], r) and W.Near(plain[2], g) and W.Near(plain[3], b), "a Glass texture keeps the plain colour")
	bar:SetBarTexture("Flat")
	bar:SetFillRamp(r, g, b, "health")
	local secret = env.Secret(r)
	bar:SetFillRamp(secret, g, b, "health")
	local gradient = bar:GetStatusBarTexture()._state.Gradient
	assert(gradient and not env.issecretvalue(gradient[2].r) and not env.issecretvalue(gradient[3].r), "a secret colour never enters the gradient")
	local fallback = W.LastCall(bar, "SetStatusBarColor")
	assert(fallback and fallback[1] == secret, "a secret colour goes to SetStatusBarColor")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}

local function edgePixels(K, bar)
	local edge = bar.innerEdge and bar.innerEdge[1]
	return edge and edge:GetHeight() / (K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar))
end

for _, screen in ipairs(SCREENS) do
	for _, setup in ipairs({
		{ uiScale = 1, size = 1 },
		{ uiScale = 768 / 1080, size = "default" },
	}) do
		local env, K = W.New({
			width = screen[1], height = screen[2], uiScale = setup.uiScale, size = setup.size, setup = withColor,
		})
		local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 14 })
		bar:SetBarTexture("Flat")
		bar:SetInnerEdge(true, "barEdge")
		local px = edgePixels(K, bar)
		local where = string.format("%dx%d ui %s size %s", screen[1], screen[2], tostring(setup.uiScale), tostring(setup.size))
		assert(px and math.abs(px - 2) < 0.01, "the inner edge is two physical pixels at " .. where .. ", got " .. tostring(px))
		assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	end
end

print("widgets status bar ok")
