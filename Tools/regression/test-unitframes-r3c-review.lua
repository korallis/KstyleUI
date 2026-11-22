-- test-unitframes-r3c-review.lua: the PR #626 review probes: the druid bar gets red, green and blue, secret values meet no truth test before their guard, the overshield glow hides without SetAlphaFromBoolean, casts clear only their own cost and the spark stops when off, power-type text ignores the fill, offsets move every visible text and unwrap at zero, the druid text has a lane and a preview, texture rows use the swatch picker with persistable values, Above the health bar hides without a power bar, lost health reaches 100 percent, hidden prediction overlays are not re-hidden, and the enabled rows change their widgets.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local env, K, ns = U.New({
	setup = function(e)
		e._lost = 0.95
		e.GetUnitTotalModifiedMaxHealthPercent = function() return e._lost end
		e.C_Spell = e.C_Spell or {}
		e.C_Spell.GetSpellPowerCost = function() return { { type = 0, cost = 400 } } end
	end,
})
local Widgets = K.Widgets
local GLASS = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\BarGlass.png"

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function point(region)
	local _, rel, _, x, y = region:GetPoint(1)
	return rel, x or 0, y or 0
end

local player = ns.Frames.Get("player").views[1]
local me = env._units.player
local native, captionNative = player.name.SetPoint, player.caption.SetPoint

-- 2. A secret absorb total or spell ID never meets a truth test or a comparison before its guard; Lua proxies cannot trap truth tests.
for path, patterns in pairs({ ["KstyleUI_UnitFrames/Unit.lua"] = { "and total or", "spellID == nil or IsSecret" }, ["KstyleUI_UnitFrames/Frames.lua"] = { "and spellID or" } }) do
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a")
	file:close()
	for _, pattern in ipairs(patterns) do
		assert(not source:find(pattern, 1, true), path .. ": '" .. pattern .. "' tests a secret value; branch on the setting or event, and check IsSecret first")
	end
end

-- 6. Zero offsets unwrap SetPoint; on Frames a caption anchored to the name takes its own level offset.
write("player.fonts.level.y", 9)
write("player.fonts.level.y", 0)
write("player.fonts.name.x", 4)
write("player.fonts.name.x", 0)
assert(player.name.SetPoint == native and player.caption.SetPoint == captionNative, "zero offsets restore the native SetPoint")
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
local _, _, cy = point(player.caption)
write("player.fonts.level.y", 9)
local _, _, cy2 = point(player.caption)
assert(player.caption:IsShown() and near(cy2 - cy, Widgets.Snap(player.parent, 9)), "the class caption moves by the level offset: " .. (cy2 - cy))
write("player.fonts.level.y", 0)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()

-- 5. Power-type text keeps the power type's colour under a custom fill.
write("player.powerColor", "custom")
write("player.powerCustom", { r = 1, g = 0, b = 0 })
write("player.powerTextColor", "power")
local r, g, b = player.powerText:GetTextColor()
local er, eg, eb = ns.Unit.PowerTypeColor("player", player.form == "column")
assert(near(r, er) and near(g, eg) and near(b, eb), "power-type text ignores the custom fill: " .. r .. " " .. g .. " " .. b)
write("player.powerTextColor", "")
write("player.powerColor", ns.Settings.defaults.player.powerColor)

-- 4. A cast's cost mark ends with that cast, and the spark stops when switched off.
write("player.powerCost", true)
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-A", 116)
local cost = assert(player.costBar, "a mana spell marks its cost")
assert(cost:IsShown(), "Cast-A shows its cost")
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-B", 116)
assert(cost:IsShown(), "another cast's success leaves Cast-A's cost")
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-A", 116)
assert(not cost:IsShown(), "Cast-A's stop clears its cost")
write("player.powerCostColor", { r = 0, g = 1, b = 0 })
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-C", 116)
local c = cost.colorRGBA
assert(c[1] == 0 and c[2] == 1 and c[3] == 0, "the cost mark takes its colour")
write("player.powerCostColor", ns.Settings.defaults.player.powerCostColor)
assert(cost.colorRGBA[1] == 1, "reset restores the cost colour")
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-C", 116)
write("player.powerCost", false)
write("player.manaSpark", true)
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-D", 116)
local spark = assert(player.manaSpark, "spending mana starts the spark")
assert(spark:IsShown() and spark.group:IsPlaying(), "the spark sweeps")
write("player.manaSpark", false)
assert(not spark:IsShown() and not spark.group:IsPlaying(), "off stops and hides a live spark")

-- 1, 7. Druids: the bar gets three channels either way, its text has a lane clear of the pips, and the preview shows both.
me.class, me.powerType, me.powerToken, me.power, me.powerMax = "DRUID", 3, "ENERGY", 60, 100
me.powers, me.powerMaxes = { [0] = 2500, [3] = 60 }, { [0] = 5000, [3] = 100 }
env.FireEvent("UNIT_DISPLAYPOWER", "player")
local res = ns.Resource.state
assert(res.showMana and W.LastCall(res.mana, "SetStatusBarColor").n >= 3, "the default druid mana bar gets red, green and blue")
write("player.powerMana", true)
assert(res.flipped and W.LastCall(res.mana, "SetStatusBarColor").n >= 3, "the form's power colour gets red, green and blue")
write("player.powerMana", false)
write("resource.manaText", "current")
local text = res.text
local _, size = text:GetFont()
local function lane()
	local _, x = point(text)
	local w, h = text:GetSize()
	return x, x + w, h
end
local function pips()
	local _, first = point(res.pips[1])
	local _, last = point(res.pips[#res.pips])
	return first, last + Widgets.Snap(res.holder, res.pips[#res.pips].opts.width)
end
local left, _, h = lane()
local pipLeft, pipRight = pips()
assert(res.showCombo and h >= size, "the druid text has a lane as tall as its font: " .. h .. " < " .. size)
assert(left >= pipRight, "the druid text sits right of the combo pips")
write("resource.manaTextAlign", "LEFT")
local _, right = lane()
assert(right <= pipLeft and text:GetJustifyH() == "LEFT", "Left puts the druid text left of the pips")
write("resource.manaTextAlign", "")
assert(text:GetJustifyH() == "CENTER", "reset restores the text position")

write("edit", "player")
write("player.powerColor", "power")
local pane = ns.Preview.Build(env.UIParent)
local sample = pane.views.player
local strip = assert(pane.resource, "the preview shows the druid bar while its text is on")
assert(strip:IsShown() and U.Shown(env, strip.text) ~= "", "the preview writes the druid bar's text")
local function rgb(bar)
	local call = W.LastCall(bar, "SetStatusBarColor")
	return table.concat({ call[1], call[2], call[3] }, " ")
end
local offPower, offStrip = rgb(sample.power), rgb(strip.bar)
write("player.powerMana", true)
pane:Refresh()
assert(rgb(sample.power) ~= offPower and rgb(strip.bar) ~= offStrip, "Mana in forms flips the preview's power bar and druid bar")
write("player.powerMana", false)
write("resource.manaTextAlign", "RIGHT")
pane:Refresh()
assert(strip.text:GetJustifyH() == "RIGHT", "the preview follows the druid text position")
write("resource.manaTextAlign", "")
write("resource.manaText", "none")
pane:Refresh()
assert(not strip:IsShown() and not text:IsShown(), "None hides the druid text and its preview")
me.class, me.powerType, me.powerToken, me.power, me.powerMax, me.powers, me.powerMaxes = "HUNTER", 0, "MANA", 2000, 4000, nil, nil
env.FireEvent("UNIT_DISPLAYPOWER", "player")

-- 8. Texture rows use the swatch picker, keep the inheritance choice, and offer only values Options can save.
local health = K.Options.Row("UnitFrames", "target.healthTexture")
env.LibStub = function() return { List = function() return { "Numeric" } end, Fetch = function() return 123456 end } end
for _, key in ipairs({ "incomingTexture", "absorbTexture", "healAbsorbTexture" }) do
	local row = K.Options.Row("UnitFrames", "target." .. key)
	local options = row.options()
	assert(row.type == health.type and options[1].value == "", key .. " is a texture row with Same as the health bar first")
	for _, option in ipairs(options) do
		assert(type(option.value) == "string", key .. " offers only textures Options can save")
	end
end
env.LibStub = nil

-- 9. Above the health bar is offered only where the style has a power bar to move.
local above = K.Options.Row("UnitFrames", "target.powerAbove")
write("edit", "target")
write("target.power", true)
assert(not above.showWhen(ns.Settings.Module()), "the slab has no power bar to move")
write("target.style", "plate")
assert(above.showWhen(ns.Settings.Module()), "the plate target keeps the row")
write("target.style", "column")
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
write("target.style", "bar")
assert(not above.showWhen(ns.Settings.Module()), "Frames' Wide bar has no power bar to move")
write("target.style", "column")
assert(above.showWhen(ns.Settings.Module()), "the Frames column target keeps the row")
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
write("target.power", false)

U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, power = 30, powerMax = 100,
	absorb = 500, reaction = 2, canAttack = true, isPlayer = true, class = "WARRIOR" })
local target = ns.Frames.Get("target").views[1]

-- 10. Lost maximum health reads up to 100 percent without dividing by zero.
write("target.maxHealthLoss", true)
local loss = assert(target.lossBar, "the lost part is marked")
assert(near(W.LastCall(loss, "SetValue")[1], 0.95), "95 percent lost shows 95 percent: " .. W.LastCall(loss, "SetValue")[1])
env._lost = 1
env.FireEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "target", 1)
local _, _, top = U.Bar(env, target.health)
assert(top == top and top < math.huge and W.LastCall(loss, "SetValue")[1] == 1, "full loss marks the whole bar with a finite range")
write("target.maxHealthAlpha", 0.8)
assert(near(loss.colorRGBA[4], 0.8), "the lost mark takes its opacity")
write("target.maxHealthAlpha", 0.5)
assert(near(loss.colorRGBA[4], 0.5), "reset restores its opacity")
env._lost = 0
write("target.maxHealthLoss", false)

-- 12. The texture rows change their overlays and reset to the health texture.
write("target.incomingTexture", GLASS)
assert(target.incoming.texturePath == GLASS, "the incoming heal texture applies")
write("target.incomingTexture", "")
assert(target.incoming.texturePath == target.health.texturePath, "blank restores the health texture")
write("target.healAbsorbs", true)
write("target.healAbsorbTexture", GLASS)
assert(target.healAbsorb.texturePath == GLASS, "the heal absorb texture applies")
write("target.healAbsorbTexture", "")
assert(target.healAbsorb.texturePath == target.health.texturePath, "blank restores the health texture")
write("target.healAbsorbs", false)
-- The Medallions slab's health and power bars take their texture settings.
local FLAT = K.Tokens.MediaList("statusbar")[1].path
write("target.healthTexture", GLASS)
write("target.powerTexture", GLASS)
assert(target.health.texturePath == GLASS and target.power.texturePath == GLASS, "the slab's health and power bars take their textures")
write("target.healthTexture", FLAT)
write("target.powerTexture", FLAT)
assert(target.health.texturePath == FLAT and target.power.texturePath == FLAT, "and return to the flat default")

-- 3. Without SetAlphaFromBoolean, a secret clamp flag hides the glow instead of erroring.
write("target.absorbGlow", true)
local glow = assert(target.shieldGlow, "the glow is made when switched on")
env._units.target.overshield = env.Secret(true)
glow.SetAlphaFromBoolean = false
local ok, err = pcall(ns.Unit.Prediction, target, "target")
assert(ok and not glow:IsShown(), "the glow hides when it cannot take a secret flag: " .. tostring(err))
glow.SetAlphaFromBoolean = nil
env._units.target.overshield = nil
write("target.absorbGlow", false)

-- 11. With incoming heals off, shield updates do not re-hide the hidden overlays.
write("target.healPrediction", false)
write("target.absorbBar", "TOP")
local hides, hide = 0, target.incoming.Hide
target.incoming.Hide = function(self, ...)
	hides = hides + 1
	return hide(self, ...)
end
for _ = 1, 10 do
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "target")
end
target.incoming.Hide = nil
assert(hides == 0, "a hidden incoming bar is not hidden again: " .. hides)
write("target.absorbBar", "")
write("target.healPrediction", true)

-- 6. Medallions: the level offset moves the plaque, also when saved before the slab is first built.
local function medallions(level)
	return U.New({ before = function(_, core)
		if level then core.Store.Module("UnitFrames").player = { fonts = { level = { y = level } } } end
	end })
end
local medEnv, medK, med = medallions()
local mv = med.Frames.Get("player").views[1]
local _, mx, my = point(mv.medallion.levelText)
medK.Options.Write("UnitFrames", "player.fonts.level.y", 9)
medEnv.RunTimers()
local _, mx2, my2 = point(mv.medallion.levelText)
assert(mv.medallion.plaque:IsShown() and mx2 == mx and near(my2 - my, Widgets.Snap(mv.parent, 9)), "the plaque's level moves by its offset")
local savedEnv, _, saved = medallions(9)
local sv = saved.Frames.Get("player").views[1]
local _, _, sy = point(sv.medallion.levelText)
assert(near(sy - my, Widgets.Snap(sv.parent, 9)), "a saved level offset moves the plaque at load: " .. (sy - my))

for _, e in ipairs({ env, medEnv, savedEnv }) do
	assert(#e._errors == 0, tostring(e._errors[1]))
end
assert(K.ErrorCount() == 0, "no caught errors")
print("test-unitframes-r3c-review: ok")
