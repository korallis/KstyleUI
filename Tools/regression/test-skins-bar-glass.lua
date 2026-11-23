-- test-skins-bar-glass.lua: the lit glass finish on the Blizzard bars the skins dress (part B and part C kit bars, as the trainer, legacy and RestedXP bars): it rides the fill on whole pixels at every screen, survives the strip each show runs (layers made after the skin too), follows a height change, and Lit glass bars off hides it, with no glass made when the switch starts off.
local W = dofile("Tools/regression/widget_env.lua")
local S = dofile("Tools/regression/skins_env.lua")

local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local OFF = { version = 2, profiles = { Default = { Appearance = { litBars = false } } }, characters = {}, layouts = {}, account = {}, devlog = {} }

local function withColor(e)
	e.CreateColor = function(r, g, b, a)
		return { r = r, g = g, b = b, a = a }
	end
end

local function Started(screen, saved)
	local env, K, ns = S.New({ width = screen[1], height = screen[2], size = "auto", fit = true, setup = withColor, saved = saved })
	K.Modules.Enable("Skins")
	return env, K, ns, S.Blizzard(env)
end

-- Bar(B, height) -> a stand-in Blizzard status bar with its fill and one piece of frame art.
local function Bar(B, height)
	local bar = B.frame("StatusBar")
	bar:SetSize(200, height)
	bar:SetStatusBarTexture("Interface\\Blizzard\\Bar")
	B.add(bar:GetStatusBarTexture())
	return bar, B.texture(bar)
end

local function Restrip(bar)
	bar:Hide()
	bar:Show()
end

local function pixels(K, frame, units)
	return units * K.Widgets.ScaleFactor(frame) / K.Scale.Pixel(1)
end

local function whole(K, frame, units, want)
	return W.Near(pixels(K, frame, units), want, 1e-6)
end

local function anchor(region, name)
	for _, p in ipairs(region._points or {}) do
		if p[1] == name then
			return p[2], p[3]
		end
	end
end

local KITS = {
	{ "part B", function(ns, bar) return ns.PartBKit.Bar(bar).edge end },
	{ "part C", function(ns, bar) return ns.PartC.Bar(bar) end },
}

for _, screen in ipairs(SCREENS) do
	for _, kit in ipairs(KITS) do
		local where = screen[1] .. "x" .. screen[2] .. " " .. kit[1]
		local env, K, ns, B = Started(screen)
		local bar, art = Bar(B, 14)
		local fill = bar:GetStatusBarTexture()
		local edge = kit[2](ns, bar)
		local glass = edge.glass
		assert(glass and edge.glassOn and art:GetAlpha() == 0 and fill:GetAlpha() == 1, where .. ": a skinned bar wears the lit glass; its frame art goes and its fill stays")
		for i = 1, 4 do
			assert(glass[i]:GetParent() == bar and glass[i]:GetDrawLayer() == "ARTWORK" and glass[i]:IsShown(), where .. ": each glass layer draws over the fill")
		end
		assert(anchor(glass[1], "TOPLEFT") == fill and anchor(glass[4], "BOTTOMRIGHT") == fill, where .. ": the glass rides the fill")
		assert(whole(K, bar, glass[1]:GetHeight(), math.floor(pixels(K, bar, bar:GetHeight()) / 2 + 0.01)) and whole(K, bar, glass[3]:GetHeight(), 1), where .. ": whole-pixel light, one-pixel rims")
		Restrip(bar)
		for i = 1, 4 do
			assert(glass[i]:GetAlpha() > 0, where .. ": the strip each show runs keeps the glass")
		end
		bar:SetHeight(6)
		edge:Restyle()
		assert(whole(K, bar, glass[1]:GetHeight(), math.floor(pixels(K, bar, 6) / 2 + 0.01)), where .. ": a new height re-places the light")

		K.Options.Write("Appearance", "litBars", false)
		assert(not edge.glassOn and not (glass[1]:IsShown() or glass[2]:IsShown() or glass[3]:IsShown() or glass[4]:IsShown()), where .. ": off hides every glass layer")
		K.Options.Write("Appearance", "litBars", true)
		assert(edge.glassOn and glass[1]:IsShown(), where .. ": on again brings it back")
		assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": no errors")
	end
end

-- A bar the game sizes after the skin, or a switch turned on later, makes its glass after the strip: the next show
-- must not hush it.
do
	local env, K, ns, B = Started(SCREENS[1], OFF)
	local bar = Bar(B, 14)
	local kids = select("#", bar:GetRegions())
	local edge = ns.PartC.Bar(bar)
	assert(not edge.glassOn and edge.glass[1] == nil and select("#", bar:GetRegions()) == kids + 3, "off from the start: the edge alone, no glass layers")
	K.Options.Write("Appearance", "litBars", true)
	Restrip(bar)
	assert(edge.glassOn and edge.glass[1]:GetAlpha() > 0 and edge.glass[4]:GetAlpha() > 0, "glass made after the skin survives the next show's strip")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors")
end

print("skins bar glass ok")
