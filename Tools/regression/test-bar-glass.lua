-- test-bar-glass.lua: one lit glass finish on every bar (v0.3.0): a soft top light, one-pixel rims and depth riding the fill on whole pixels at every screen, the light alone on meter bars, none on overlays or short and upright bars, and Appearance > Lit glass bars off restoring each bar's previous finish exactly.
local W = dofile("Tools/regression/widget_env.lua")
local M = dofile("Tools/regression/meters_env.lua")

local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }

local function withColor(e)
	e.CreateColor = function(r, g, b, a)
		return { r = r, g = g, b = b, a = a }
	end
end

local function pixels(K, frame, units)
	return units * K.Widgets.ScaleFactor(frame) / K.Scale.Pixel(1)
end

local function anchor(region, name)
	for _, p in ipairs(region._points or {}) do
		if p[1] == name then
			return p[2], p[3], p[4], p[5]
		end
	end
end

local function gradient(region)
	local g = region._state.Gradient
	return g[2], g[3]
end

local function alpha(region)
	return select(4, region:GetVertexColor())
end

local function shown(glass)
	return glass[1]:IsShown(), glass[2]:IsShown(), glass[3]:IsShown(), glass[4]:IsShown()
end

for _, screen in ipairs(SCREENS) do
	local where = screen[1] .. "x" .. screen[2]
	local env, K = W.New({ width = screen[1], height = screen[2], size = "auto", fit = true, setup = withColor })
	local Widgets = K.Widgets
	local bar = Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 14, background = "track", min = 0, max = 1, value = 0.5 })
	local fill, glass = bar:GetStatusBarTexture(), bar.glass
	assert(glass and bar.glassOn, where .. ": a bar wears the lit glass by default")
	for i = 1, 4 do
		assert(glass[i]:GetParent() == bar and glass[i]:GetDrawLayer() == "ARTWORK", where .. ": each glass layer draws over the fill")
	end
	local a, b, c, d = shown(glass)
	assert(a and b and c and d, where .. ": the light, the depth and both rims show")
	local rel, relPoint = anchor(glass[1], "TOPLEFT")
	assert(rel == fill and relPoint == "TOPLEFT" and pixels(K, bar, glass[1]:GetHeight()) == math.floor(pixels(K, bar, bar:GetHeight()) / 2 + 0.01), where .. ": the light rides the fill's top half in whole pixels, so it follows the value")
	local bottom, top = gradient(glass[1])
	assert(bottom.a == 0 and top.a > 0 and top.a <= 0.25, where .. ": a soft light, clear by the fill's middle where the bar's text sits")
	local depthTop, depthStart = anchor(glass[2], "TOPLEFT")
	bottom, top = gradient(glass[2])
	assert(depthTop == glass[1] and depthStart == "BOTTOMLEFT" and top.a == 0 and bottom.a > 0 and bottom.a <= 0.3, where .. ": depth darkens the lower half, never past 30%")
	for i = 3, 4 do
		assert(math.abs(pixels(K, bar, glass[i]:GetHeight()) - 1) < 1e-6, where .. ": each rim is one physical pixel")
	end
	assert(W.Near(alpha(glass[3]), 0.4) and W.Near(alpha(glass[4]), 0.45), where .. ": a lit top rim over a dark bottom rim")
	assert(alpha(bar.lit) == 0 and gradient(bar.shade).a == 0, where .. ": the bar's own lit line and shade give way to the glass")
	local anchored = #W.Calls(glass[1], "ClearAllPoints")
	bar:Restyle()
	assert(#W.Calls(glass[1], "ClearAllPoints") == anchored, where .. ": an unchanged restyle does not re-anchor the glass")
	bar:SetInnerEdge(true, "black")
	local edge = pixels(K, bar, select(4, anchor(glass[3], "TOPLEFT")))
	assert(math.abs(edge + bar:EdgeLine()) < 1e-6 and bar:EdgeLine() > 0, where .. ": the rims sit inside an inner edge")

	local light = Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 14, glass = "light" })
	a, b, c, d = shown(light.glass)
	assert(a and not b and c and not d, where .. ": a light-only bar takes the light and the top rim, nothing that darkens its colour")
	local overlay = Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 14, background = false, glass = false })
	assert(overlay.glass == nil and overlay.glassOn == false, where .. ": an overlay that opts out makes no glass")
	local upright = Widgets.StatusBar(K.Scale.Root(), { width = 14, height = 120, orientation = "VERTICAL" })
	assert(upright.glass == nil, where .. ": an upright bar makes no glass")
	local thin = Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 4 / Widgets.ScaleFactor(K.Scale.Root()) * K.Scale.Pixel(1) })
	a, b, c, d = shown(thin.glass)
	assert(a and b and not c and not d, where .. ": a four-pixel bar keeps the light and depth without rims")
	local hair = Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 2 / Widgets.ScaleFactor(K.Scale.Root()) * K.Scale.Pixel(1) })
	assert(hair.glass == nil, where .. ": a two-pixel bar stays plain")

	local unit = Widgets.UnitBar(K.Scale.Root(), { width = 200, height = 20 })
	assert(unit.glass and unit.glass[1]:GetParent() == unit.fillClip, where .. ": a unit bar's glass sits in its fill clip, over the low-health red")
	assert(not unit.cleanSheen:IsShown() and not unit.cleanShade:IsShown() and not unit.cleanLit:IsShown(), where .. ": and replaces its own sheen, shade and top line")
	unit:SetFinish("medallions")
	assert(unit.cleanLit:IsShown() and not unit.cleanSheen:IsShown(), where .. ": the Medallions fill-end line stays over the glass")
	unit:SetFinish(nil)

	K.Options.Write("Appearance", "litBars", false)
	a, b, c, d = shown(glass)
	assert(not (a or b or c or d) and not bar.glassOn, where .. ": off hides the glass")
	assert(W.Near(alpha(bar.lit), 0.3) and W.Near(gradient(bar.shade).a, 0.28), where .. ": off restores the lit line and shade")
	assert(unit.cleanSheen:IsShown() and unit.cleanShade:IsShown() and unit.cleanLit:IsShown() and not unit.glass[1]:IsShown(), where .. ": off restores a unit bar's sheen, shade and top line")
	K.Options.Write("Appearance", "litBars", true)
	assert(bar.glassOn and glass[1]:IsShown() and alpha(bar.lit) == 0, where .. ": on again restores the glass")
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": no errors")
end

do
	local _, K = W.New({ setup = withColor, saved = { version = 2, profiles = { Default = { Appearance = { litBars = false } } }, characters = {}, layouts = {}, account = {}, devlog = {} } })
	K.Appearance.Apply()
	local bar = K.Widgets.StatusBar(K.Scale.Root(), { width = 200, height = 14, background = "track" })
	local unit = K.Widgets.UnitBar(K.Scale.Root(), { width = 200, height = 20 })
	assert(bar.glass == nil and unit.glass == nil, "off from the start makes no glass layers at all")
	assert(#W.Calls(bar.lit, "SetVertexColor") > 0 and W.Near(alpha(bar.lit), 0.3) and W.Near(gradient(bar.shade).a, 0.28), "and keeps the previous lit line and shade")
end

do
	local env, K, ns = M.New({ game = function(e)
		withColor(e)
		e._group = { raid = false, size = 2 }
	end })
	env._session = { combatSources = { { name = "Kragar", classFilename = "WARRIOR", totalAmount = 2840, amountPerSecond = 28.4, sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0 } }, maxAmount = 2840, totalAmount = 2840, durationSeconds = 30 }
	M.Enable(env, K)
	local row = ns.Damage.list.rows[1]
	local a, b, c, d = shown(row.bar.glass)
	assert(a and c and not b and not d, "a damage meter bar takes the light alone, so its class colour stays full")
	assert(alpha(row.bar.lit) == 0 and gradient(row.bar.shade).a == 0, "and its old shade no longer darkens it")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "meters: no errors")
end

-- Review of #746: the glass reuses each bar's own lit line, shade and sheen, so a nameplate stays at 172 regions.
do
	local _, K = W.New({ setup = withColor })
	local Widgets, root = K.Widgets, K.Scale.Root()
	local function added(opts)
		local plain = {}
		for k, v in pairs(opts) do
			plain[k] = v
		end
		plain.glass = false
		local glass = Widgets.StatusBar(root, opts)
		return select("#", glass:GetRegions()) - select("#", Widgets.StatusBar(root, plain):GetRegions()), glass
	end
	assert(added({ width = 200, height = 14, background = "track", border = true }) == 2, "a bordered bar adds only the light and the bottom rim; its shade and lit line are the depth and top rim")
	assert(added({ width = 200, height = 14, background = "barTrack", glass = "light" }) == 1, "a light-only meter row adds only the light and makes no dark layer")
	assert(added({ width = 200, height = 14, background = false }) == 4, "a bar with no finish of its own adds all four layers")
	local unit, flat = Widgets.UnitBar(root, { width = 200, height = 20 }), Widgets.UnitBar(root, { width = 200, height = 20, glass = false })
	assert(select("#", unit.fillClip:GetRegions()) - select("#", flat.fillClip:GetRegions()) == 1, "a unit bar paints its sheen, shade and top line as the glass and adds only the bottom rim")

	local bar = Widgets.StatusBar(root, { width = 200, height = 14, glass = "light" })
	local calls = 0
	for i = 1, 4 do
		local layer = bar.glass[i]
		if layer then
			local show = layer.SetShown
			layer.SetShown = function(self, ...)
				calls = calls + 1
				return show(self, ...)
			end
		end
	end
	bar:PlaceGlass()
	assert(calls == 0, "an unchanged placement sets no visibility, got " .. calls .. " SetShown calls")
	local off = Widgets.StatusBar(root, { width = 200, height = 14, glass = false })
	local reads = 0
	for _, key in ipairs({ "GetStatusBarTexture", "GetHeight", "GetWidth" }) do
		local read = off[key]
		off[key] = function(self, ...)
			reads = reads + 1
			return read(self, ...)
		end
	end
	off:PlaceGlass()
	assert(reads == 0, "a bar that opts out reads neither its fill nor its size, got " .. reads .. " reads")
end

-- Review of #746: an upright bar wears the same glass turned on its side, whether it was built upright or turned by
-- the engine's own SetOrientation (data bars and cooldown charges), never a light half its height tall.
do
	local _, K = W.New({ setup = withColor })
	local Widgets, root = K.Widgets, K.Scale.Root()
	local function upright(bar, where)
		local fill, light = bar:GetStatusBarTexture(), bar.glass and bar.glass[1]
		assert(bar.glassOn and light, where .. ": an upright bar wears the glass")
		local rel, relPoint = anchor(light, "BOTTOMLEFT")
		assert(rel == fill and relPoint == "BOTTOMLEFT" and anchor(light, "TOPLEFT") == fill, where .. ": the light runs up the fill's left side")
		local across = math.floor(pixels(K, bar, bar:GetWidth()) / 2 + 0.01)
		assert(math.abs(pixels(K, bar, light:GetWidth()) - across) < 1e-6, where .. ": the light is half the bar's width, got " .. pixels(K, bar, light:GetWidth()) .. " pixels")
		local g = light._state.Gradient
		assert(g[1] == "HORIZONTAL" and g[2].a > 0 and g[3].a == 0, where .. ": the light fades from the left edge")
		g = bar.glass[2]._state.Gradient
		assert(g[1] == "HORIZONTAL" and g[2].a == 0 and g[3].a > 0, where .. ": the depth darkens toward the right edge")
		assert(anchor(bar.glass[4], "TOPRIGHT") == fill and math.abs(pixels(K, bar, bar.glass[4]:GetWidth()) - 1) < 1e-6, where .. ": the dark rim is one pixel down the right side")
	end
	upright(Widgets.StatusBar(root, { width = 14, height = 120, orientation = "VERTICAL", background = "track" }), "built upright")
	local turned = Widgets.StatusBar(root, { width = 14, height = 120, background = false })
	turned:SetOrientation("VERTICAL")
	turned:Restyle()
	upright(turned, "turned by SetOrientation")
	upright(Widgets.UnitBar(root, { width = 14, height = 120, orientation = "VERTICAL" }), "an upright unit bar")
end

-- Review of #746: the data bar that turns upright agrees with its siblings.
do
	local D = dofile("Tools/regression/databars_env.lua")
	local _, K, ns = D.New()
	K.Options.Write("DataBars", "rep.orientation", "VERTICAL")
	local fill = ns.Bars.views.rep.fill
	local light = fill.glass and fill.glass[1]
	assert(light and light._state.Gradient[1] == "HORIZONTAL" and pixels(K, fill, light:GetWidth()) <= pixels(K, fill, fill:GetWidth()) / 2 + 1e-6,
		"an upright reputation bar wears the glass on its side, not a light " .. tostring(light and pixels(K, fill, light:GetHeight())) .. " pixels tall")
end

-- Review of #746: the tooltip preview shows the finish the live tooltip health bar has.
do
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K, ns = T.New()
	K.Modules.Enable("Tooltips")
	local preview = K.Options.Preview("Tooltips")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	local live = assert(ns.Health.Build(env.GameTooltip))
	assert(preview.bar.glassMode == live.glassMode and not preview.bar.glassOn, "the preview's health bar wears the live bar's finish")
end

-- Review of #746: the stock meter fixture has the game's CreateColor, so screenshots and the pixel guard see the light.
do
	local env, K, ns = M.New({ game = function(e)
		e._group = { raid = false, size = 2 }
	end })
	env._session = { combatSources = { { name = "Kragar", classFilename = "WARRIOR", totalAmount = 2840, amountPerSecond = 28.4, sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0 } }, maxAmount = 2840, totalAmount = 2840, durationSeconds = 30 }
	M.Enable(env, K)
	assert(type(env.CreateColor) == "function" and ns.Damage.list.rows[1].bar.glassOn, "the stock meter fixture draws the light")
end

-- Review of #746: under Medallions the player's cast bar keeps the whole glass; the module no longer hides the lit
-- line and shade the glass is painted on.
do
	local U = dofile("Tools/regression/unitframes_env.lua")
	local env, K, ns = U.New()
	local element = ns.CastBars.Get("player")[1]
	env._time = 2.2
	env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 188196)
	U.W.Tick(env, 0.1)
	local bar = element.bar
	assert(element.medal and bar.glassOn, "the Medallions cast bar wears the glass")
	for i = 1, 4 do
		assert(bar.glass[i]:IsShown(), "under Medallions the cast bar's glass layer " .. i .. " shows")
	end
end

print("ok bar glass")
