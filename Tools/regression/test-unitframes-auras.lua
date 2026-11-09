-- test-unitframes-auras.lua: frame auras run on the AuraContainer engine, touch aura buttons only while auras are not secret, and follow their settings.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local Frames = ns.Frames

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end
noErrors("enable")

-- Focus and boss frames show auras by default, and the target's sigil carries your debuffs; the player leaves them to the Auras module.
local focus = Frames.Get("focus").views[1]
local boss = Frames.Get("boss").views[2]
assert(focus.auras and focus.auras.container, "the focus frame has an aura container")
assert(boss.auras and boss.auras.container, "each boss frame has an aura container")
local sigil = Frames.Get("target").views[1].auras
assert(sigil and sigil.container and sigil.container._unit == "target", "the target's sigil carries an aura container by default")
assert(Frames.Get("player").views[1].auras == nil, "the player frame shows no auras by default")
local c = focus.auras.container
assert(c._unit == "focus" and boss.auras.container._unit == "boss2", "each container follows its unit")

-- The default filter shows the player's own debuffs.
assert(c._groups.debuffs.enabled and c._groups.debuffs.filter == "HARMFUL|PLAYER", "focus shows your debuffs")
assert(c._groups.buffs.enabled == false, "and no buffs")

-- initializeFrame dresses each engine button: icon, cooldown swipe, stack count and dispel border on a child frame.
local button = c._groups.debuffs.buttons[1]
local aura = button._aura
assert(aura.SetIcon and aura.SetIcon[1]:GetObjectType() == "Texture", "the engine gets an icon texture")
assert(aura.SetDurationCooldown and aura.SetDurationCooldown[1]:GetObjectType() == "Cooldown", "the engine gets a cooldown for the swipe")
assert(aura.SetApplicationCount and aura.SetApplicationCount[1]:GetObjectType() == "FontString", "the engine gets a stack count")
assert(aura.dispel and #aura.dispel > 0, "debuff borders follow the dispel type")
assert(aura.SetIcon[1]:GetParent() ~= button, "the art sits on a child frame of the button")
local w, h = button:GetSize()
assert(w == 20 and h == 20, "buttons take the aura size: " .. tostring(w))

-- Each button wears the kit's socket: a rounded fill whose corner is the socket share of the icon,
-- the socket's rim, the icon two borders in, and a swipe in the icon's rounded shape.
local Tokens = K.Tokens
local function tilePaths(skin)
	local paths = {}
	for _, region in ipairs(W.Regions(skin, "Texture")) do
		local set = W.LastCall(region, "SetTexture")
		if set then
			paths[set[1]] = (paths[set[1]] or 0) + 1
		end
	end
	return paths
end
local function cornerSizes(skin)
	local sizes = {}
	for _, region in ipairs(W.Regions(skin, "Texture")) do
		local set = W.LastCall(region, "SetTexture")
		local size = W.LastCall(region, "SetSize")
		if set and set[1] == (Tokens.Texture("chamferTile")) and size then
			sizes[#sizes + 1] = size
		end
	end
	return sizes
end
local skin = aura.SetIcon[1]:GetParent()
local paths = tilePaths(skin)

-- Each tile sits on the near-black button body with the accent rim every square icon shares.
local function TileColours(kit, frame)
	local body, raised, rim = false, false, false
	local fr, fg, fb = kit.Tokens.Color("buttonFill")
	local xr, xg, xb = kit.Tokens.Color("raised")
	local rr, rg, rb = kit.Widgets.IconRim()
	local function same(a, b)
		return math.abs(a - b) < 1e-3
	end
	for _, region in ipairs(W.Regions(frame, "Texture")) do
		local set = W.LastCall(region, "SetTexture")
		local r, g, b = region:GetVertexColor()
		if set and set[1] == (kit.Tokens.Texture("chamferTile")) and type(r) == "number" then
			body = body or (same(r, fr) and same(g, fg) and same(b, fb))
			raised = raised or (same(r, xr) and same(g, xg) and same(b, xb))
		elseif type(r) == "number" and same(r, rr) and same(g, rg) and same(b, rb) then
			rim = true
		end
	end
	return body, raised, rim
end
do
	local body, raised, rim = TileColours(K, skin)
	assert(body and not raised, "the tile's body is the near-black button fill, not a raised tile")
	assert(rim, "its hairline rests on the accent lifted 15% toward white, as an action button")
end
assert((paths[(Tokens.Texture("lumenShape"))] or 0) >= 9, "the tile has a rounded fill")
assert(paths[(Tokens.Texture("lumenRimSmall"))] == 9, "the tile has the socket's rim, nine pieces")
assert(paths[(Tokens.Texture("iconMask"))] == nil, "no texture stretches the icon mask over the button")
local corners = cornerSizes(skin)
assert(#corners >= 4, "the rounded corners are sized")
local want = K.Scale.Snap(20 * Tokens.Share("radiusSocket"))
for _, size in ipairs(corners) do
	assert(size[1] == want and size[2] == want, "each corner is the socket share of a 20-unit icon: " .. tostring(size[1]))
end
local _, iconRel, _, ix, iy = aura.SetIcon[1]:GetPoint(1)
assert(iconRel == skin and ix == 2 * K.Scale.Border() and iy == -2 * K.Scale.Border(), "the icon sits two borders in")
local cooldown = aura.SetDurationCooldown[1]
assert(W.LastCall(cooldown, "SetSwipeTexture")[1] == (Tokens.Texture("iconMask")), "the swipe has the icon's rounded shape")
assert(aura.dispelOptions and aura.dispelOptions.style == env.Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, "the engine tints the tile's own dispel border")

-- Layout: element size, capacity, line length and growth.
local layout = c._groups.debuffs.layout
assert(layout.elementWidth == 20 and layout.elementHeight == 20 and layout.elementSpacing == 2, "the group lays out 20-unit icons, 2 apart")
assert(c._groups.debuffs.max == 8, "one row of eight")
assert(c._line == 8 * 20 + 7 * 2, "the line holds eight icons")
assert(c._anchor == "TOPLEFT" and c._growth[1] == env.AnchorUtil.FlowDirection.Right and c._growth[2] == env.AnchorUtil.FlowDirection.Down, "growing right, then down")

-- The aura row sits over the focus card, inside the 112 the layouts keep beside the sigil (round 2, Q2).
local point, rel, relPoint = focus.auras.host:GetPoint(1)
assert(point == "BOTTOMLEFT" and rel == focus.button and relPoint == "TOPLEFT", "focus auras sit over the frame")

-- Settings: filter, rows, columns, spacing and growth reach the container at once.
K.Options.Write("UnitFrames", "focus.auraFilter", "both")
assert(c._groups.debuffs.enabled and c._groups.debuffs.filter == "HARMFUL" and c._groups.buffs.enabled and c._groups.buffs.filter == "HELPFUL", "both shows debuffs and buffs")
assert(c._groups.buffs.layout.forceNewLine == true, "buffs start on their own line")
K.Options.Write("UnitFrames", "focus.auraFilter", "buffs")
assert(not c._groups.debuffs.enabled and c._groups.buffs.enabled, "buffs only")
K.Options.Write("UnitFrames", "focus.auraRows", 2)
K.Options.Write("UnitFrames", "focus.auraColumns", 5)
K.Options.Write("UnitFrames", "focus.auraSpacing", 4)
assert(c._groups.buffs.max == 10 and c._line == 5 * 20 + 4 * 4, "two rows of five, four apart")
K.Options.Write("UnitFrames", "focus.auraGrowth", "LEFT_UP")
assert(c._anchor == "BOTTOMRIGHT" and c._growth[1] == env.AnchorUtil.FlowDirection.Left and c._growth[2] == env.AnchorUtil.FlowDirection.Up, "growing left, then up")
K.Options.Write("UnitFrames", "focus.auraPosition", "BELOW")
point, rel, relPoint = focus.auras.host:GetPoint(1)
assert(point == "TOPLEFT" and rel == focus.button and relPoint == "BOTTOMLEFT", "auras can sit under the frame")
noErrors("settings")

-- A Layout resize moves the aura row with the frame's panel.
assert(K.Layout.Set("unitframes.focus", "height", 120))
local _, _, _, ax = focus.auras.host:GetPoint(1)
assert(math.abs(ax - focus.geometry.panel.x) < 1e-6, "below the frame, the auras stay aligned with the resized panel")
K.Layout.Reset("unitframes.focus")

-- A size change waits while auras are secret: the group layout changes at once, the buttons after.
env._restricted = true
local sizes = #W.Calls(button, "SetSize")
K.Options.Write("UnitFrames", "focus.auraSize", 26)
assert(c._groups.buffs.layout.elementWidth == 26, "the group layout takes the new size at once")
assert(#W.Calls(button, "SetSize") == sizes, "no aura button is touched while auras are secret")
noErrors("secret gate")
env._restricted = false
env.SetCombat(true)
env.SetCombat(false)
local nw = button:GetSize()
assert(nw == 26, "the buttons take the new size once auras are readable again")
want = K.Scale.Snap(26 * Tokens.Share("radiusSocket"))
for _, size in ipairs(cornerSizes(skin)) do
	assert(size[1] == want and size[2] == want, "the rounded corner follows the icon to 26 units: " .. tostring(size[1]))
end
noErrors("after the gate")

-- A theme change while auras are secret leaves the tiles alone until aura data is readable.
env._restricted = true
local regionCalls = {}
for _, region in ipairs(W.Regions(skin, "Texture")) do
	regionCalls[region] = #W.Calls(region, "SetPoint")
end
local skinCalls = #skin._calls
K.Widgets.RestyleAll()
for region, n in pairs(regionCalls) do
	assert(#W.Calls(region, "SetPoint") == n, "no tile texture moves while auras are secret")
end
assert(#skin._calls == skinCalls, "the tile frame is left alone while auras are secret")
env._restricted = false
env.SetCombat(true)
env.SetCombat(false)
noErrors("theme gate")

-- A container built later takes the frame's current strata.
assert(K.Layout.Set("unitframes.target", "strata", "HIGH"))
-- Switching target auras on builds their container on demand.
K.Options.Write("UnitFrames", "target.auras", true)
local target = Frames.Get("target").views[1]
assert(target.auras and target.auras.container and target.auras.container._unit == "target", "target auras build on demand")
assert(target.auras.host:GetFrameStrata() == "HIGH", "the new aura row takes the frame's strata")
K.Layout.Reset("unitframes.target")
K.Options.Write("UnitFrames", "target.auras", false)
assert(target.auras.container._enabled == false and not target.auras.host:IsShown(), "switching them off disables the container")

-- The aura row hides with its frame and with the module.
U.SetUnit(env, "focus", nil)
assert(not focus.auras.host:IsShown(), "no focus, no focus auras")
U.SetUnit(env, "focus", { name = "Elunara", level = 60, health = 1, healthMax = 2, reaction = 2 })
assert(focus.auras.host:IsShown(), "the aura row shows with its frame")
K.Modules.Disable("UnitFrames")
assert(not focus.auras.host:IsShown() and c._enabled == false, "the module stopping disables the containers")
K.Modules.Enable("UnitFrames")
assert(c._enabled == true, "and enabling it again turns them back on")
noErrors("visibility")

-- At 1440p a unit is three quarters of a pixel, so sizes, gaps and offsets snap to whole pixels.
do
	local qenv, QK, qns = U.New({ width = 2560, height = 1440 })
	local px = QK.Scale.Pixel()
	assert(math.abs(px - 0.75) < 1e-6, "one pixel is 0.75 units at 1440p")
	local function whole(units)
		local n = units / px
		return math.abs(n - math.floor(n + 0.5)) < 1e-6
	end
	local qfocus = qns.Frames.Get("focus").views[1]
	local qc = qfocus.auras.container
	local qw, qh = qc._groups.debuffs.buttons[1]:GetSize()
	assert(whole(qw) and whole(qh), "an aura button covers whole pixels: " .. tostring(qw))
	local ql = qc._groups.debuffs.layout
	assert(ql.elementWidth == qw and ql.elementHeight == qh, "the engine lays out the snapped size")
	assert(whole(ql.elementSpacing) and whole(ql.lineSpacing), "the spacing is whole pixels: " .. tostring(ql.elementSpacing))
	assert(whole(qc._line), "the row length is whole pixels: " .. tostring(qc._line))
	local hw, hh = qfocus.auras.host:GetSize()
	assert(whole(hw) and whole(hh), "the aura row covers whole pixels")
	local _, _, _, ox, oy = qfocus.auras.host:GetPoint(1)
	assert(whole(ox) and whole(oy) and ox > 0, "the gap to the frame is whole pixels: " .. tostring(ox))
	assert(#qenv._errors == 0, "1440p: " .. tostring(qenv._errors[1]))
end

-- Without the engine, the frames still work and the devlog says why.
local nenv, NK = U.New({ setup = function(e)
	local create = e.CreateFrame
	e.CreateFrame = function(frameType, ...)
		if frameType == "AuraContainer" then
			error("Unknown frame type AuraContainer")
		end
		return create(frameType, ...)
	end
end })
local logged = false
for _, entry in ipairs(NK.Store.Data().devlog) do
	logged = logged or (entry.module == "UnitFrames" and entry.message:find("AuraContainer", 1, true) ~= nil)
end
assert(logged, "a missing engine is logged")
assert(#nenv._errors == 0, "no engine, no error: " .. tostring(nenv._errors[1]))

print("unitframes auras ok")
