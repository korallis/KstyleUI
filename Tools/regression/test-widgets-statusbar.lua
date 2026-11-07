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
	assert(plain.background == nil and plain.chrome, "no background, and a chamfered border when asked")
end

print("widgets status bar ok")
