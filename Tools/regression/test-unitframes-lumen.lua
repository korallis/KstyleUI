-- test-unitframes-lumen.lua: the Lumen styles: the player's vitals line, the target's sigil, the boss and focus cards and the compact pill rows, the low-health ring glow through a colour curve, and the cast lines inside each frame.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local Settings, Geometry, Frames, CastBars = ns.Settings, ns.Geometry, ns.Frames, ns.CastBars
local Tokens = K.Tokens

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function mid(r)
	return r.y + r.h / 2
end

local function inside(part, w, h, what)
	assert(part.x >= -1e-6 and part.y >= -1e-6 and part.x + part.w <= w + 1e-6 and part.y + part.h <= h + 1e-6, what .. " stays inside the frame")
end

local function glass(view)
	return view.chrome.fill[5]:IsShown()
end

local function reveal(value)
	if env.issecretvalue(value) then
		return env.Reveal(value)
	end
	return value
end

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

noErrors("enable")

-- Every frame is Lumen by default; the classic plate stays a choice.
for _, kind in ipairs(Settings.KINDS) do
	assert(Settings.Value(kind, "style") == "lumen", kind .. " is Lumen by default")
end
local FORMS = { player = "vitals", target = "sigil", focus = "card", boss = "card", targettarget = "row", focustarget = "row", pet = "row" }
for kind, form in pairs(FORMS) do
	assert(Settings.Form(kind) == form, kind .. " takes the " .. form .. " form, got " .. tostring(Settings.Form(kind)))
	assert(Settings.Snapshot(kind).form == form, kind .. "'s snapshot carries its form")
end
K.Options.Write("UnitFrames", "pet.style", "plate")
assert(Settings.Form("pet") == "plate", "the classic plate is a choice")
K.Options.Write("UnitFrames", "pet.style", "nonsense")
assert(Settings.Form("pet") == "row", "a value that is not a choice falls back to Lumen")
K.Options.Write("UnitFrames", "pet.style", "lumen")
assert(Settings.Value("player", "powerColor") == "power", "power bars keep the power type's colour")
assert(Settings.Value("player", "portraitShape") == "round", "portraits stay round by default")

local function lumen(form, overrides)
	local s = {
		form = form, portrait = true, portraitSide = "LEFT", level = true, name = true, power = true, powerHeight = 5,
		healthText = "both", powerText = "none", castbar = true,
		fonts = { name = { size = 17 }, health = { size = 15 }, power = { size = 10 }, level = { size = 12 } },
	}
	for k, v in pairs(overrides or {}) do
		s[k] = v
	end
	return s
end

-- The vitals line at its Lumen footprint, 490 by 80: a 62-unit ring at the left with the level disc on its lower
-- right, then one column: the name and the health value on one row, a 12-unit health pill, a 5-unit power pill, its
-- foot level with the ring's, and the cast line under it all.
local v = Geometry.Frame(lumen("vitals"), 490, 80, 1)
assert(v.form == "vitals" and not v.compact and v.chrome == false, "the vitals line is a full frame with no glass of its own")
assert(near(v.portrait.x, 0) and near(v.portrait.y, 0) and near(v.portrait.w, 62) and near(v.portrait.h, 62), "the ring is 62 units at the top left")
local disc = v.badge
assert(disc and near(disc.w, disc.h) and disc.w >= 20 and disc.w <= 24, "the level disc is about 22 units, got " .. tostring(disc and disc.w))
assert(disc.x + disc.w > 62 and disc.y + disc.h > 62 and disc.x > 31 and disc.y > 31, "the disc sits on the ring's lower right, standing a little past it")
assert(near(v.health.h, 12) and near(v.power.h, 5), "a 12-unit health pill over a 5-unit power pill")
assert(near(v.power.y + v.power.h, 62, 0.5), "the power pill's foot is level with the ring's")
assert(v.power.y >= v.health.y + v.health.h + 3 and v.power.y <= v.health.y + v.health.h + 5, "4 units between the two pills")
assert(near(v.health.x, v.power.x) and near(v.health.w, v.power.w), "both pills span the column")
local col = v.health.x
assert(col > 62 + 10 and col < 62 + 22, "the column starts about 16 units past the ring, got " .. col)
assert(near(v.health.x + v.health.w, 490), "and runs to the frame's right edge")
assert(v.name and v.name.y + v.name.h <= v.health.y - 4, "the name sits over the health pill")
assert(near(v.name.x, col), "the name starts the column")
assert(v.healthSub and near(v.healthSub.x + v.healthSub.w, 490), "the max ends at the column's right edge")
assert(v.healthText.x + v.healthText.w <= v.healthSub.x + 1e-6, "the current value sits before the max")
assert(near(v.healthText.y + v.healthText.h, v.name.y + v.name.h, 1) and near(v.healthSub.y + v.healthSub.h, v.name.y + v.name.h, 1), "the values share the name's row, on its baseline")
assert(v.caption and v.caption.x >= v.name.x, "a stance or spec caption follows the name")
assert(v.cast and near(v.cast.x, col) and near(v.cast.x + v.cast.w, 490) and v.cast.y >= 62, "the cast line runs under the column, below the ring")
assert(v.cast.h >= 10 and v.cast.h <= 14 and near(v.cast.y + v.cast.h, 80) and v.cast.y >= v.power.y + v.power.h + 5, "a thin line at the frame's foot, clear of the power pill")
for key, part in pairs(v) do
	if type(part) == "table" and part.w and key ~= "badge" then
		inside(part, 490, 80, "vitals " .. key)
	end
end
local noCast = Geometry.Frame(lumen("vitals", { castbar = false }), 490, 80, 1)
assert(noCast.cast == nil and noCast.portrait.h > 62, "without the cast line the ring takes the room")
local narrow = Geometry.Frame(lumen("vitals"), 220, 70, 1)
assert(narrow.caption == nil and narrow.name.w > 0, "a narrow vitals line drops the caption and gives the name a fixed width to cut it short")
for key, part in pairs(narrow) do
	if type(part) == "table" and part.w and key ~= "badge" then
		inside(part, 220, 70, "narrow vitals " .. key)
		assert(part.w >= 0 and part.h >= 0, "no negative sizes")
	end
end
local bare = Geometry.Frame(lumen("vitals", { portrait = false }), 490, 80, 1)
assert(bare.portrait == nil and bare.badge == nil and near(bare.health.x, 0), "without the portrait the column takes the whole line")

-- The sigil at 640 units: centred name, the level line under it, a 12-unit pill between two gems.
local t = Geometry.Frame(lumen("sigil", { fonts = { name = { size = 20 }, health = { size = 12 }, power = { size = 10 }, level = { size = 13 } } }), 640, 80, 1)
assert(t.form == "sigil" and t.chrome == false and t.portrait == nil and t.badge == nil and t.power == nil, "the sigil is text and one pill: no glass, portrait, badge or power")
assert(near(t.name.x, 0) and near(t.name.w, 640), "the name row spans the sigil, centred")
assert(t.caption and t.caption.y >= t.name.y + t.name.h - 1e-6 and near(t.caption.w, 640), "the level line is under the name, centred")
assert(near(t.health.h, 12) and t.health.y > t.caption.y + t.caption.h, "the 12-unit pill is under the level line")
assert(t.gemLeft and t.gemRight and near(mid(t.gemLeft), mid(t.health)) and near(mid(t.gemRight), mid(t.health)), "a gem at each end of the pill, on its middle")
assert(near(t.gemLeft.x, 0) and near(t.gemRight.x + t.gemRight.w, 640), "the gems close the row")
assert(t.health.x > t.gemLeft.x + t.gemLeft.w + 8 and near(t.health.x - (t.gemLeft.x + t.gemLeft.w), t.gemRight.x - (t.health.x + t.health.w)), "the pill keeps an equal gap to each gem")
assert(t.healthText == nil, "the sigil shows no numbers, as the mockup")
assert(t.cast and t.cast.y > t.health.y + t.health.h and near(t.cast.x + t.cast.w / 2, 320), "the target's cast line is centred under the pill")
for key, part in pairs(t) do
	if type(part) == "table" and part.w then
		inside(part, 640, 80, "sigil " .. key)
	end
end
local squeezed = Geometry.Frame(lumen("sigil", { fonts = { name = { size = 20 }, health = { size = 12 }, power = { size = 10 }, level = { size = 13 } } }), 640, 72, 1)
assert(squeezed.cast and squeezed.cast.y + squeezed.cast.h <= 72 + 1e-6 and squeezed.cast.y >= squeezed.health.y + squeezed.health.h, "a short sigil closes its gaps first and keeps the cast line")
assert(Geometry.Frame(lumen("sigil"), 640, 50, 1).cast == nil, "a sigil too short for its cast line leaves it out")

-- The card: a section cap, the name with the percentage, a pill, the cast line, on a glass card.
local c = Geometry.Frame(lumen("card", { power = false, fonts = { name = { size = 16 }, health = { size = 14 }, power = { size = 9 }, level = { size = 12 } } }), 318, 120, 1)
assert(c.form == "card" and c.chrome == true, "the card wears the glass")
assert(near(c.glass.x, 0) and near(c.glass.w, 318) and near(c.glass.h, 120), "the glass is the whole card")
assert(c.cap and c.capGem and c.capLabel and near(mid(c.capGem), mid(c.cap)), "a section cap: the gem on the cap's middle, then the label")
assert(c.capGem.x >= 12 and c.capLabel.x > c.capGem.x + c.capGem.w, "inside the card's padding, label after the gem")
assert(c.caption and near(c.caption.x + c.caption.w, c.cap.x + c.cap.w) and near(mid(c.caption), mid(c.cap)), "the classification at the cap's right")
assert(c.name.y > c.cap.y + c.cap.h and c.healthText and near(mid(c.healthText), mid(c.name), 1), "the name under the cap, the percentage on its row")
assert(c.name.x + c.name.w <= c.healthText.x + 1e-6, "the name stops before the percentage")
assert(c.health.y > c.name.y + c.name.h - 1e-6 and c.health.h >= 8 and c.health.h <= 12, "a 10-unit pill under the name")
assert(c.power == nil, "no power pill unless it is on")
assert(c.cast and c.cast.y > c.health.y + c.health.h and near(c.cast.x, c.health.x) and near(c.cast.w, c.health.w), "the cast line under the pill, as wide")
assert(c.cast.y + c.cast.h <= 120 - 10, "the card keeps its bottom padding")
assert(c.portrait == nil and c.badge == nil, "the card has no portrait")
for _, h in ipairs({ 24, 40, 60, 80, 100 }) do
	local short = Geometry.Frame(lumen("card", { power = true, powerHeight = 4 }), 318, h, 1)
	for key, part in pairs(short) do
		if type(part) == "table" and part.w then
			inside(part, 318, h, "a " .. h .. "-unit card's " .. key)
		end
	end
	assert(short.health and short.health.h > 0, "a " .. h .. "-unit card keeps its pill")
end
local cp = Geometry.Frame(lumen("card", { power = true, powerHeight = 4 }), 318, 120, 1)
assert(cp.power and cp.power.y > cp.health.y + cp.health.h and near(cp.power.h, 4), "with power on, a thin power pill under the health pill")

-- The compact row: the name and the percentage on one line over a 6-unit pill, no glass.
local r = Geometry.Frame(lumen("row", { portrait = false, power = false, healthText = "percent", fonts = { name = { size = 12 }, health = { size = 12 }, power = { size = 9 }, level = { size = 10 } } }), 88, 22, 1)
assert(r.form == "row" and r.compact and r.chrome == false, "a row is compact, with no glass")
assert(near(r.health.h, 6) and near(r.health.y + r.health.h, 22) and near(r.health.w, 88), "a 6-unit pill across the row's foot")
assert(r.name and near(r.name.x, 0) and r.name.y + r.name.h <= r.health.y + 1e-6, "the name over the pill")
assert(r.healthText and near(r.healthText.x + r.healthText.w, 88) and r.name.x + r.name.w <= r.healthText.x + 1e-6, "the percentage at the right, after the name")
assert(r.portrait == nil and r.badge == nil and r.cast == nil, "no portrait, badge or cast line")

-- The classic plate is unchanged: a full frame with its glass.
local plate = Geometry.Frame(lumen("plate"), 220, 70, 1)
assert(plate.form == "plate" and plate.chrome == true and plate.glass.x > 0 and plate.cast == nil, "the plate keeps its glass under the portrait")
noErrors("geometry")

-- The live player frame at the vitals footprint S6 gives it: the vitals line.
assert(K.Layout.Set("unitframes.player", "width", 490) and K.Layout.Set("unitframes.player", "height", 80), "Layout takes the vitals footprint")
assert(K.Layout.Set("unitframes.target", "width", 640) and K.Layout.Set("unitframes.target", "height", 80), "and the sigil's")
assert(K.Layout.Set("unitframes.boss", "height", 640) and K.Layout.Set("unitframes.boss", "width", 318), "and the boss cards'")
local player = Frames.Get("player").views[1]
local pg = player.geometry
assert(pg.form == "vitals", "the player frame draws the vitals line")
assert(not glass(player), "no glass behind the vitals line")
assert(player.ring:IsShown() and player.portraitBack:IsShown(), "the round portrait in its ring")
assert(player.disc:IsShown() and not player.badge:IsShown(), "the round level disc replaces the octagon badge")
assert(U.Shown(env, player.levelText) == "60", "the level shows in the disc")
local gold = { ns.Lumen.Color("gold") }
assert(W.SameRGB(player.ring, gold[1], gold[2], gold[3]), "the ring is gilt, whatever the accent")
local headingPath = Tokens.Font("heading")
assert(player.name:GetFont() == headingPath, "the name is in the heading face")
assert(U.Shown(env, player.healthText) == "3120", "the current health on the right: " .. U.Shown(env, player.healthText))
assert(U.Shown(env, player.healthSub) == "/ 3980", "then the max: " .. U.Shown(env, player.healthSub))
local point, rel, relPoint = player.healthText:GetPoint(1)
assert(point:find("RIGHT") and rel == player.healthSub and relPoint:find("LEFT"), "the current value hangs off the max, so neither is measured")
local cr, cg, cb = K.Theme.ClassColor("HUNTER")
local hc = player.health.colorRGBA
assert(near(hc[1], cr) and near(hc[2], cg) and near(hc[3], cb), "the health pill is the class colour")
local mr, mg, mb = ns.Unit.PowerTypeColor("player")
local pc = player.power.colorRGBA
assert(near(pc[1], mr) and near(pc[2], mg) and near(pc[3], mb), "the power pill is the power type's colour")
assert(near(select(2, player.health:GetSize()), 12, 0.6), "the health pill is 12 units tall")

-- The caption: the active stance's name, else the specialization's, else nothing.
env._forms, env._form = { { 2457, "Battle Stance" }, { 71, "Defensive Stance" } }, 1
env.FireEvent("UPDATE_SHAPESHIFT_FORM")
assert(U.Shown(env, player.caption) == "Battle Stance", "the stance shows after the name: " .. U.Shown(env, player.caption))
env._form = 0
env._spec = "Arms"
env.FireEvent("UPDATE_SHAPESHIFT_FORM")
assert(U.Shown(env, player.caption) == "Arms", "the spec when there is no stance: " .. U.Shown(env, player.caption))
env._spec = nil
env.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(U.Shown(env, player.caption) == "", "nothing when there is neither")
local _, crel, crelPoint = player.caption:GetPoint(1)
assert(crel == player.name and crelPoint:find("RIGHT"), "the caption hangs off the name's end")
noErrors("vitals")

-- Low health: the ring's glow takes its colour from a colour curve over the health percentage, never a comparison.
local glow = player.ringGlow
local function glowAlpha()
	local _, _, _, a = glow:GetVertexColor()
	return reveal(a) or 1
end
assert(glow:IsShown(), "the glow sits behind the ring")
local hr, hg, hb = Tokens.Color("healthHostile")
local gr, gg, gb = glow:GetVertexColor()
assert(near(reveal(gr), hr) and near(reveal(gg), hg) and near(reveal(gb), hb), "the glow is hostile red")
assert(env.issecretvalue((glow:GetVertexColor())), "the glow's colour comes straight from the curve: a secret the module never reads")
local healthy = glowAlpha()
env._units.player.health = 400
env.FireEvent("UNIT_HEALTH", "player")
local low = glowAlpha()
assert(low > 0.6 and healthy < 0.25 and low > healthy, "the glow is faint at 78% and strong at 10%: " .. healthy .. " then " .. low)
env._units.player.health = 3980
env.FireEvent("UNIT_HEALTH", "player")
assert(glowAlpha() < 0.01, "full health: no glow")
env._units.player.health = 3120
env.FireEvent("UNIT_HEALTH", "player")
noErrors("low health")

-- The vitals cast line: a thin pill inside the frame, under the column, shown only while casting.
local inline = CastBars.Inline("player")[1]
local element = CastBars.Get("player")[1]
assert(inline and inline.frame:GetParent() == player.button, "the vitals line carries its own cast line")
assert(not inline.frame:IsShown(), "no cast, no line")
env._time = 1
env._units.player.cast = { name = "Slam", texture = 132340, start = 1000, finish = 3500, spellID = 1464 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 1464)
assert(inline.frame:IsShown(), "a cast shows the line")
assert(not element.frame:IsShown(), "the classic cast bar element stays hidden under the Lumen frame")
assert(not ns.CastBars.ElementLive("player"), "the classic cast bar element is not live")
assert(U.Shown(env, inline.text) == "Slam", "the spell's name")
assert(U.Shown(env, inline.label) == K.L["Casting"], "after the word Casting")
assert(not inline.iconFrame:IsShown() and not inline.chrome.fill[5]:IsShown(), "no icon tile, no glass: a line")
local _, lineH = inline.bar:GetSize()
assert(lineH <= 5, "the line's bar is thin, got " .. tostring(lineH))
local fx = inline.frame:GetPoint(1)
assert(fx == "TOPLEFT", "the line sits where the geometry puts it")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 1464)
settle()
assert(not inline.frame:IsShown(), "the line goes with the cast")
noErrors("vitals cast")

-- The target sigil: centred texts, gems, the level line, your debuffs centred under it, the cast line.
U.SetUnit(env, "target", { name = "Bloodtalon Matriarch", level = 10, classification = "elite", creature = "Beast", health = 620, healthMax = 1000, power = 0, powerMax = 0, reaction = 2, canAttack = true })
env.SetTarget(true)
settle()
local target = Frames.Get("target").views[1]
assert(target.button:IsShown() and target.geometry.form == "sigil", "the target frame draws the sigil")
assert(target.name:GetJustifyH() == "CENTER" and target.caption:GetJustifyH() == "CENTER", "its texts are centred")
assert(target.name:GetFont() == headingPath, "the name is in the heading face")
assert(U.Shown(env, target.caption) == "Level 10 elite \194\183 Beast", "the level line: " .. U.Shown(env, target.caption))
assert(target.gemLeft:IsShown() and target.gemRight:IsShown(), "the gems close the pill")
local _, grel = target.glowFrame:GetPoint(1)
assert(grel == target.health, "the threat glow hugs the sigil's pill, not an empty box around the frame")
assert(not glass(target) and not target.portraitFrame:IsShown() and not target.power:IsShown(), "no glass, portrait or power")
local tc = target.health.colorRGBA
assert(near(tc[1], hr) and near(tc[2], hg) and near(tc[3], hb), "a hostile target's pill is hostile red")
U.SetUnit(env, "target", { name = "Wolf", level = 9, health = 50, healthMax = 100, reaction = 2, canAttack = true, secretCreature = true, creature = "Beast" })
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(U.Shown(env, target.caption) == "Level 9 \194\183 Beast", "a secret creature type still shows, through the setter: " .. U.Shown(env, target.caption))
U.SetUnit(env, "target", { name = "Bloodtalon Matriarch", level = 10, classification = "elite", creature = "Beast", health = 620, healthMax = 1000, power = 50, powerMax = 100, reaction = 2, canAttack = true })
K.Options.Write("UnitFrames", "target.style", "plate")
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(target.power:IsShown(), "the plate shows a mana user's power bar")
K.Options.Write("UnitFrames", "target.style", "lumen")
env.FireEvent("UNIT_POWER_UPDATE", "target")
assert(not target.power:IsShown(), "back on the sigil, power updates never bring the plate's power bar back")

assert(Settings.Value("target", "auras") and Settings.Value("target", "auraFilter") == "mine" and Settings.Value("target", "auraPosition") == "CENTER", "your debuffs ride on the sigil, centred")
local a = target.auras
assert(a and a.container and a.host:IsShown(), "the sigil's debuff row shows")
local hp, hrel, hrelPoint = a.host:GetPoint(1)
assert(hp == "TOP" and hrel == target.button and hrelPoint == "BOTTOM", "the row hangs centred under the sigil")
local cpnt, crl, crp = a.container:GetPoint(1)
assert(cpnt == "TOP" and crl == a.host and crp == "TOP", "the engine's row is centred in its host, so it stays centred at any count")
local entry = a.buttons[1]
-- Round 4 (Fable #3): the sigil's default is one row of 28-unit sockets, each timer in its own lane under the socket.
local tp, trel, trp = entry.timer:GetPoint(1)
assert(tp == "TOP" and trel == entry.skin and trp == "BOTTOM", "a single centred row hangs each timer under its socket, as the mockup draws it")
assert(not entry.badge:IsShown(), "under the socket the timer needs no badge")
-- Round 3 (Opus #5, Fable R3-11): a timer inside its socket sits in a corner badge, not across the icon's foot.
K.Options.Write("UnitFrames", "target.auraRows", 2)
tp, trel, trp = entry.timer:GetPoint(1)
assert(tp == "BOTTOMRIGHT" and trel == entry.skin and trp == "BOTTOMRIGHT", "two rows of sockets keep each timer in its socket's corner badge, so the rows pack inside the sigil's reserve")
assert(entry.badge:IsShown(), "on its dark badge")
K.Options.Write("UnitFrames", "target.auraRows", 1)

env._units.target.cast = { name = "Terrifying Screech", texture = 132127, start = 1000, finish = 3500, spellID = 5000 }
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 5000)
local tinline = CastBars.Inline("target")[1]
assert(tinline.frame:IsShown() and tinline.frame:GetParent() == target.button, "the target's cast line shows inside the sigil")
assert(not CastBars.Get("target")[1].frame:IsShown(), "the classic target cast bar stays hidden")
local gr2, gg2, gb2 = ns.Lumen.Color("cast")
local tcol = tinline.bar.colorRGBA
assert(near(tcol[1], gr2) and near(tcol[2], gg2) and near(tcol[3], gb2), "the target's cast line is gold")
assert(U.Shown(env, tinline.text) == "Terrifying Screech", "the spell's name")
assert(tinline.text:GetWidth() == 0, "on a wide line the name takes its own width, so the bar follows it")
CastBars.Layout(tinline, 180, 16)
local capped = tinline.text:GetWidth()
assert(capped > 0 and capped < 180 - 40, "on a narrow line the name is cut to leave the bar its room: " .. tostring(capped))
CastBars.Layout(tinline, 294, 16)
env._units.target.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "target", "Cast-1", 5000)
settle()
noErrors("sigil")

-- Boss and focus cards: the section cap, the name, a pill, the cast line inside the card.
U.SetUnit(env, "boss1", { name = "Bloodtalon Matriarch", level = 10, classification = "elite", health = 620, healthMax = 1000, reaction = 2, canAttack = true,
	cast = { name = "Terrifying Screech", texture = 132127, start = 1000, finish = 3500, spellID = 5000 } })
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
env.FireEvent("UNIT_SPELLCAST_START", "boss1", "Cast-1", 5000)
env.RunTimers()
local boss = Frames.Get("boss").views[1]
assert(boss.button:IsShown() and boss.geometry.form == "card", "boss frames are cards")
assert(glass(boss), "the card wears its glass")
assert(boss.capGem:IsShown() and U.Shown(env, boss.capLabel) == K.L["Boss"], "the section cap reads Boss: " .. U.Shown(env, boss.capLabel))
assert(U.Shown(env, boss.caption) == K.L["Elite"], "the classification at the cap's right: " .. U.Shown(env, boss.caption))
assert(U.Shown(env, boss.healthText) == "62%", "the percentage on the name's row: " .. U.Shown(env, boss.healthText))
local bcb = boss.castbar
assert(bcb.frame:IsShown() and bcb.label and U.Shown(env, bcb.label) == K.L["Casting"], "the boss's cast line shows inside the card")
local _, by = select(4, bcb.frame:GetPoint(1))
local _, bh = boss.button:GetSize()
assert(-by + select(2, bcb.frame:GetSize()) <= bh + 0.5, "the cast line sits inside the card")
env._units.boss1.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "boss1", "Cast-1", 5000)
settle()
U.SetUnit(env, "focus", { name = "Elunara", level = 11, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_FOCUS_CHANGED")
local focus = Frames.Get("focus").views[1]
assert(focus.geometry.form == "card" and U.Shown(env, focus.capLabel) == K.L["Focus"], "the focus card's cap reads Focus")
assert(U.Shown(env, focus.caption) == K.L["Level %s"]:format(11), "a plain unit's cap shows its level: " .. U.Shown(env, focus.caption))
noErrors("cards")

-- The compact rows: target of target, focus target, pet.
U.SetUnit(env, "targettarget", { name = "Tester", class = "HUNTER", isPlayer = true, level = 60, health = 300, healthMax = 400, reaction = 5 })
env.FireEvent("UNIT_TARGET", "target")
local tot = Frames.Get("targettarget").views[1]
assert(tot.geometry.form == "row" and not glass(tot), "the target of target is a pill row, no glass")
assert(U.Shown(env, tot.healthText) == "75%", "with its percentage: " .. U.Shown(env, tot.healthText))
-- Round 6 (Fable #2): a row draws over the world with no glass, so it reads as the sigil does there: the sigil's soft
-- scrim behind it, sized to the row, and its name and value in the world role's outline.
do
	assert(tot.scrim:IsShown(), "the row has the sigil's soft scrim behind it")
	local sw, sh = tot.scrim:GetSize()
	local rw, rh = tot.button:GetSize()
	assert(sw > rw and sh > rh and sw <= rw + 64 and sh <= rh + 40, "the scrim hugs the row, " .. sw .. " by " .. sh .. " for " .. rw .. " by " .. rh)
	for _, key in ipairs({ "name", "healthText" }) do
		local font = W.LastCall(tot[key], "SetFont")
		assert(font and font[3] == "OUTLINE", "the row's " .. key .. " wears the world role's outline, got " .. tostring(font and font[3]))
	end
	assert(not focus.scrim:IsShown(), "a card has glass and no scrim")
end
U.SetUnit(env, "targettarget", nil)
noErrors("rows")

-- The classic plate comes back with the style setting, its glass and its own cast bar element.
K.Options.Write("UnitFrames", "player.style", "plate")
settle()
assert(player.geometry.form == "plate" and glass(player), "the plate is back with its glass")
assert(not player.disc:IsShown() and player.badge:IsShown(), "and its octagon badge")
assert(not player.ringGlow:IsShown(), "the low-health glow belongs to the vitals ring")
assert(ns.CastBars.ElementLive("player"), "the classic cast bar element is live again")
env._units.player.cast = { name = "Slam", texture = 132340, start = 1000, finish = 3500, spellID = 1464 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 1464)
assert(element.frame:IsShown() and not inline.frame:IsShown(), "the plate's cast bar element runs; the vitals line's does not")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 1464)
settle()
K.Options.Write("UnitFrames", "player.style", "lumen")
settle()
assert(player.geometry.form == "vitals" and not ns.CastBars.ElementLive("player"), "and back to the vitals line")
noErrors("plate")

-- A Lumen player frame switched off still leaves a cast bar: the classic element takes over.
K.Options.Write("UnitFrames", "player.enabled", false)
assert(ns.CastBars.ElementLive("player"), "with the vitals line off, the classic cast bar element runs")
K.Options.Write("UnitFrames", "player.enabled", true)
assert(not ns.CastBars.ElementLive("player"), "and steps back when the vitals line returns")

-- Centred sockets in stacked rows keep their timers on the socket, so the rows sit one spacing apart; a single
-- centred row leaves the timer's height under it.
K.Options.Write("UnitFrames", "target.auraRows", 2)
local layout = target.auras.container._groups.debuffs.layout
assert(layout.lineSpacing == layout.elementSpacing, "stacked rows sit one spacing apart: " .. layout.lineSpacing)
K.Options.Write("UnitFrames", "target.auraRows", 1)
layout = target.auras.container._groups.debuffs.layout
local _, sizeAura = ns.Settings.Font("target", "aura")
assert(layout.lineSpacing >= layout.elementSpacing + sizeAura, "a single row keeps the timer's height: " .. layout.lineSpacing)
K.Options.Write("UnitFrames", "target.auraRows", 2)
noErrors("fallbacks")

-- No colour curve API: the glow stays off and the devlog says so once.
do
	local env2, K2, ns2 = U.New({ setup = function(e)
		e.C_CurveUtil.CreateColorCurve = nil
	end })
	local view = ns2.Frames.Get("player").views[1]
	assert(not view.ringGlow:IsShown(), "no colour curve: no glow")
	assert(#env2._errors == 0 and K2.ErrorCount() == 0, "and no error")
end

print("unitframes lumen ok")
