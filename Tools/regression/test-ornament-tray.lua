-- test-ornament-tray.lua: tray finials require a genuinely adjacent, aligned and enabled pair of rows.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local G = dofile("Tools/regression/ornament_guard_lib.lua")
local env, K = W.New()
local profile = K.Store.Module("Widgets")
profile.ornaments, profile.cardMaterial = "Full", "ForgedBrackets"
local main = env.CreateFrame("Frame", nil, K.Scale.Root())
local second = env.CreateFrame("Frame", nil, K.Scale.Root())
local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(main)
main:SetPoint("BOTTOMLEFT", K.Scale.Root(), "BOTTOMLEFT", 300 * pixel, 400 * pixel)
main:SetSize(300 * pixel, 21 * pixel)
second:SetSize(300 * pixel, 21 * pixel)
local function place(x, gap)
	second:ClearAllPoints()
	second:SetPoint("BOTTOMLEFT", K.Scale.Root(), "BOTTOMLEFT", (300 + x) * pixel, (400 + main:GetHeight() / pixel + gap) * pixel)
end
place(0, 3)
local handle = K.Widgets.Ornament(main, "row")
handle.keystone, handle.pair, handle.pairGap = true, second, 3 * pixel
handle:Restyle()
handle.expected = { "Tray40", "Tray40" }
G.Check(Scene.Build(env).items, { tray = handle }, {}, "adjacent Full rows", { 1920, 1080 }, K.Widgets.OrnamentAssets, 1)
for _, entry in ipairs({ { 3, 3 }, { 0, 8 }, { 0, -1 } }) do
	place(entry[1], entry[2])
	handle:Restyle()
	assert(handle.used == 0, "misaligned, separated or overlapping rows omit the combined tray")
	for _, texture in ipairs(handle.textures) do assert(not texture:IsShown(), "invalid pair hides stale tray finials") end
end
place(0, 3)
handle.pairEnabled = false
handle:Restyle()
assert(handle.used == 0, "a disabled or independently faded paired row omits the tray")
handle.pairEnabled = true
profile.ornaments = "Subtle"
handle:Restyle()
handle.expected = { "Arrow16", "Arrow16" }
G.Check(Scene.Build(env).items, { tray = handle }, {}, "Subtle keeps a quieter tray of plain arrow caps without the keystone", { 1920, 1080 }, K.Widgets.OrnamentAssets, 1)
handle.expected = nil
profile.ornaments = "Full"
local blocker = env.CreateFrame("Frame", nil, K.Scale.Root())
blocker:SetSize(21 * pixel, 21 * pixel)
blocker.IsShown = function() error("tray avoidance must use the bar's known shown state") end
local function block(x, y)
	blocker:ClearAllPoints()
	blocker:SetPoint("BOTTOMLEFT", K.Scale.Root(), "BOTTOMLEFT", x * pixel, y * pixel)
end
handle.avoidBars = { blocker }
block(1000, 409)
handle:Restyle()
handle.expected = { "Tray40", "Tray40" }
G.Check(Scene.Build(env).items, { tray = handle }, {}, "unobstructed pair", { 1920, 1080 }, K.Widgets.OrnamentAssets, 1)
for _, x in ipairs({ 619, 280 }) do
	block(x, 409)
	handle:Restyle()
	assert(handle.used == 0, "a right bar3 or left-side bar collision omits both complete finials")
	for _, texture in ipairs(handle.textures) do assert(not texture:IsShown(), "blocked finials leave no stale art") end
end
local rightEdge = 602 + K.Widgets.OrnamentAssets.Tray40[1]
local gap = math.max(4 / K.Scale.Pixel(1), 3)
block(rightEdge + gap - 0.25, 409)
handle:Restyle()
assert(handle.used == 0, "finials reserve both the four-root and three-physical-pixel clearance")
block(rightEdge + gap + 0.25, 409)
handle:Restyle()
G.Check(Scene.Build(env).items, { tray = handle }, {}, "clearance restored", { 1920, 1080 }, K.Widgets.OrnamentAssets, 1)
block(619, 470)
handle:Restyle()
assert(handle.used == 2, "a bar outside the finials' vertical span does not hide them")
block(1000, 409)
for _, method in ipairs({ "GetLeft", "GetRight", "GetTop", "GetBottom" }) do
	local original = blocker[method]
	for _, value in ipairs({ env.Secret(1000), false }) do
		blocker[method] = function() return value or nil end
		assert(pcall(handle.Restyle, handle) and handle.used == 0, "secret or unknown blocker geometry omits finials safely")
	end
	blocker[method] = original
end
main:SetSize(300 * pixel, 31 * pixel)
second:SetSize(300 * pixel, 31 * pixel)
place(0, 3)
block(619, 409)
handle:Restyle()
handle.expected = { "Keystone6" }
G.Check(Scene.Build(env).items, { tray = handle }, {}, "blocked finials retain valid bottom keystone", { 1920, 1080 }, K.Widgets.OrnamentAssets, 1)
local AB = dofile("Tools/regression/actionbars_env.lua")
local ae, AK, ns = AB.New()
AB.Enable(ae, AK)
local mainBar = ns.bars.bar1
local restyle, refreshes = mainBar.ornament.Restyle, 0
function mainBar.ornament:Restyle()
	refreshes = refreshes + 1
	return restyle(self)
end
AK.Options.Write("ActionBars", "bar3.enabled", true)
ae.RunTimers()
local thirdBar = assert(ns.bars.bar3, "enabling bar3 creates its owned holder")
thirdBar.holder.IsShown = function() error("do not read holder visibility") end
local before = refreshes
thirdBar:Refresh()
assert(refreshes == before + 1, "refreshing bar3 refreshes the main tray")
local found = false
for _, holder in ipairs(mainBar.ornament.avoidBars) do
	assert(holder ~= mainBar.holder and holder ~= ns.bars.bar2.holder, "the paired rows never avoid themselves")
	if holder == thirdBar.holder then found = true end
end
assert(found, "a shown bar3 contributes its owned holder to the tray's avoidance list")
AK.Options.Write("ActionBars", "bar3.enabled", false)
thirdBar:Refresh()
for _, holder in ipairs(mainBar.ornament.avoidBars) do assert(holder ~= thirdBar.holder, "hidden bars leave the avoidance list") end
local function avoids(bar)
	for _, holder in ipairs(mainBar.ornament.avoidBars) do if holder == bar.holder then return true end end
	return false
end
local pet, stance = assert(ns.bars.pet), assert(ns.bars.stance)
mainBar:RefreshOrnament()
assert(stance.count == 0 and stance:Visibility() == "hide" and not avoids(stance), "an enabled empty stance bar does not obstruct the tray")
assert(ae._game.petExists == false and pet:Shown() and not avoids(pet), "an enabled no-pet holder does not obstruct the tray")
local update, style, mainUpdates = ns.Button.Update, ns.Button.StyleTexts, 0
ns.Button.Update = function(button, ...)
	if button.kbar == mainBar then mainUpdates = mainUpdates + 1 end
	return update(button, ...)
end
ns.Button.StyleTexts = function(button, ...)
	if button.kbar == mainBar then mainUpdates = mainUpdates + 1 end
	return style(button, ...)
end
ae._game.petExists = true
before = refreshes
ae.FireEvent("UNIT_PET", "player")
assert(avoids(pet) and refreshes == before + 1 and mainUpdates == 0, "pet appearance refreshes only the tray through the existing UNIT_PET event")
before = refreshes
for _, event in ipairs({ "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE_USABLE", "PET_BAR_UPDATE", "PLAYER_TARGET_CHANGED" }) do
	ae.FireEvent(event)
end
ae.FireEvent("UNIT_FLAGS", "pet")
assert(refreshes == before and mainUpdates == 0, "pet updates that change nothing neither restyle the tray nor touch the main action buttons")
ae._game.petExists = false
ae.FireEvent("UNIT_PET", "player")
assert(not avoids(pet) and mainUpdates == 0, "pet removal refreshes the tray without touching main buttons")
ns.Button.Update, ns.Button.StyleTexts = update, style
local unitExists = ae.UnitExists
for _, query in ipairs({ function() return nil end, function() return ae.Secret(false) end, false }) do
	ae.UnitExists = query
	mainBar:RefreshOrnament()
	assert(avoids(pet), "unknown, secret or unavailable pet existence conservatively includes the holder")
end
ae.UnitExists = unitExists
ae._game.forms = { { texture = 132349, isActive = true, spellID = 2457 } }
ae.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(stance.count == 1 and stance:Visibility() == "show" and avoids(stance), "new stance forms apply their layout and refresh tray avoidance")
ae._game.forms = {}
ae.FireEvent("UPDATE_SHAPESHIFT_FORMS")
assert(stance.count == 0 and stance:Visibility() == "hide" and not avoids(stance), "removing the last stance form refreshes the tray through Apply and Refresh")
assert(#ae._errors == 0, "bar refresh has no hidden errors: " .. tostring(ae._errors[1]))
print("ok tray avoidance, safe geometry and pet/stance visibility refresh")
