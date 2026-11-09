-- test-unitframes-kit.lua: unit frames and cast bars wear the kit's chrome, in Lumen's rounded material until the unit frame slice restyles them: one glass panel under a square portrait in the accent, a level badge, a round portrait as a setting, and cast bars with their spell icon in its own square beside a glass bar.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

-- These checks pin the classic plate, the style setting's other choice; test-unitframes-lumen.lua covers the Lumen styles.
local env, K, ns = U.New({ plate = true })
local Tokens = K.Tokens
local Frames, CastBars = ns.Frames, ns.CastBars

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

local function mid(r)
	return r.y + r.h / 2
end

-- Pieces(frame, name) -> how many of the frame's textures draw the named kit texture, and how many of those show.
local function pieces(frame, name)
	local path = (Tokens.Texture(name))
	local total, shown = 0, 0
	for _, region in ipairs(W.Regions(frame, "Texture")) do
		local set = W.LastCall(region, "SetTexture")
		if set and set[1] == path then
			total = total + 1
			if region:IsShown() then
				shown = shown + 1
			end
		end
	end
	return total, shown
end

local function maskPath(view)
	return (view.mask:GetTexture())
end

noErrors("enable")
local player = Frames.Get("player").views[1]
assert(K.Store.Module("UnitFrames").player.portraitShape == "round", "the portrait is round by default, as the owner's mockup draws it")
K.Options.Write("UnitFrames", "player.portraitShape", "chamfered")
local g = player.geometry

-- The glass: one Lumen panel, laid where Geometry puts it, under the portrait.
local _, panelBevels = pieces(player.panel, "lumenFrost")
assert(panelBevels == 9, "the player's glass wears the panel's nine frost pieces, got " .. panelBevels)
local point, rel, relPoint, x, y = player.panel:GetPoint(1)
assert(point == "TOPLEFT" and rel == player.button and relPoint == "TOPLEFT", "the glass is placed from the frame's top left")
assert(near(x, g.glass.x, 1) and near(-y, g.glass.y, 1), "the glass sits where Geometry puts it: " .. tostring(x) .. ", " .. tostring(y))
local pw, ph = player.panel:GetSize()
assert(near(pw, g.glass.w, 1) and near(ph, g.glass.h, 1), "the glass takes Geometry's size")
assert(g.glass.x < g.portrait.x + g.portrait.w, "the glass runs under the portrait")
assert(player.portraitFrame:GetFrameLevel() > player.panel:GetFrameLevel(), "the portrait draws over the glass's outer end")
assert(near(player.chrome:Chamfer(), math.min(14, g.glass.h / 2), 0.01), "the glass rounds its corners 14 units, at most half its height, got " .. tostring(player.chrome:Chamfer()))
assert(player.power.backgroundName == "buttonFill", "the power bar's track is the mockup's dark #101214 track, the button body, like the health track")
local _, _, _, _, iconY = player.icons.leader:GetPoint(1)
assert(near(-iconY, g.glass.y, 1), "the status icons sit on the glass's top edge: " .. tostring(iconY))

-- The square portrait setting ("chamfered" in the settings): framed in a panel with the rim in the accent.
local total, shown = pieces(player.portraitFrame, "lumenShape")
assert(total == 9 and shown == 9, "the square portrait shows the panel's fill pieces, got " .. shown .. " of " .. total)
assert(not player.ring:IsShown() and not player.portraitBack:IsShown(), "the chamfered portrait hides the round ring and disc")
assert(near(player.portraitChrome:Chamfer(), 0.15 * g.portrait.w, 0.01), "the portrait's corners round 15% of its size, got " .. tostring(player.portraitChrome:Chamfer()))
assert(maskPath(player) == (Tokens.Texture("portraitMask")) and not maskPath(player):find("Chamfer", 1, true), "the portrait image is masked to the rounded icon mask")
assert(env._unmasked[player.portrait] == true, "the chamfered portrait asks for the square, unmasked 2D portrait")
local ar, ag, ab = K.Theme.Accent()
local function rim(r, g2, b)
	return r + (1 - r) * 0.15, g2 + (1 - g2) * 0.15, b + (1 - b) * 0.15
end
assert(player.portraitChrome.fillName == "buttonFill", "the portrait frame is the button body, the mockup's one dark tone behind icons and portraits")
assert(W.SameRGB(player.portraitChrome.rim[1], rim(ar, ag, ab)), "the portrait's inner bevel line is the accent lifted 15% towards white, as on the design file")
assert(W.SameRGB(player.portraitChrome.rim[5], rim(ar, ag, ab)), "on its straight edges too")
local layer, sublevel = player.portrait:GetDrawLayer()
local lineLayer, lineSublevel = player.portraitChrome.rim[1]:GetDrawLayer()
assert((layer == lineLayer and sublevel < lineSublevel) or layer == "ARTWORK" or layer == "BACKGROUND", "the image draws under the rim, so its corners never cover it")
K.Options.Write("UnitFrames", "accent", "custom")
K.Options.Write("UnitFrames", "accentColor", { r = 0.9, g = 0.1, b = 0.1 })
assert(W.SameRGB(player.portraitChrome.rim[1], rim(0.9, 0.1, 0.1)), "the portrait's line takes the custom accent")
K.Options.Write("UnitFrames", "accent", "class")
assert(W.SameRGB(player.portraitChrome.rim[1], rim(ar, ag, ab)), "and follows the class accent again")
noErrors("chamfered portrait")

-- The level badge: a regular octagon on the portrait's corner, its line the kit's neutral grey, filled like the glass.
local badgeTotal, badgeShown = pieces(player.badge, "lumenShape")
assert(badgeTotal == 9 and badgeShown == 9, "the badge is a rounded panel, got " .. badgeShown .. " of " .. badgeTotal)
local nr, ng, nb = Tokens.Color("text")
assert(W.SameRGB(player.badgeChrome.rim[1], nr, ng, nb), "the badge's line is neutral, as on the kit sheet")
local bw, bh = player.badge:GetSize()
assert(near(bw, bh) and near(bw, g.badge.w, 1), "the badge is square")
assert(near(player.badgeChrome:Chamfer(), bw / (2 + math.sqrt(2)), 0.05), "its corners round where the octagon cut them, got " .. tostring(player.badgeChrome:Chamfer()))
assert(player.badgeChrome.fillName == "buttonFill", "the octagon is filled with the button body: the mockup's badges measure #101214")
local _, _, _, badgeX, badgeY = player.badge:GetPoint(1)
assert(near(badgeX, g.badge.x, 1) and near(-badgeY, g.badge.y, 1), "the badge sits where Geometry puts it, straddling the corner")

-- Texts: the percentage at the track's end and current and max under it, from secret health.
assert(U.Shown(env, player.healthText) == "78%", "the percentage at the track's end: " .. U.Shown(env, player.healthText))
assert(U.Shown(env, player.healthSub) == "3120 / 3980", "current and max under it: " .. U.Shown(env, player.healthSub))
assert(player.healthText:GetJustifyH() == "RIGHT", "the percentage is right-aligned at the track's end")
assert(player.healthSub:GetJustifyH() == "RIGHT" and player.powerText:GetJustifyH() == "LEFT", "the detail row: health at the right, power at the left")
env._units.player.health = 1990
env.FireEvent("UNIT_HEALTH", "player")
assert(U.Shown(env, player.healthText) == "50%" and U.Shown(env, player.healthSub) == "1990 / 3980", "health events update both texts")
env._units.player.health = 3120
env.FireEvent("UNIT_HEALTH", "player")
local line = player.trackLine
assert(line and line:IsShown(), "a hairline runs under the health track, as on the kit sheet")
local _, lineRel, _, lineX, lineY = line:GetPoint(1)
assert(lineRel == player.button and near(lineX, g.trackLine.x, 1) and near(-lineY, g.trackLine.y, 1), "the hairline sits where Geometry puts it")
assert(near(line:GetWidth(), g.trackLine.w, 1) and line:GetWidth() > g.health.w and near(line:GetHeight(), K.Widgets.Border(player.button)), "it spans the track and the percentage, one border thick")
local lr, lg, lb, la = line:GetVertexColor()
local er, eg, eb, ea = K.Tokens.Color("edgeBar")
assert(W.Near(lr, er) and W.Near(lg, eg) and W.Near(lb, eb) and W.Near(la, ea), "the bar grade's edgeBar line, got " .. tostring(la))
assert(K.Layout.Set("unitframes.player", "height", 30), "Layout can make the player frame compact")
assert(player.geometry.compact and not player.healthSub:IsShown(), "a compact frame has no row under its bar")
assert(not line:IsShown(), "a compact frame's bar fills its glass, with no hairline")
assert(U.Shown(env, player.healthText) == "3120 / 3980  78%", "resizing rewrites the health text at once: " .. U.Shown(env, player.healthText))
K.Layout.Reset("unitframes.player")
assert(U.Shown(env, player.healthText) == "78%" and player.healthSub:IsShown() and U.Shown(env, player.healthSub) == "3120 / 3980", "and back again")
noErrors("texts")

-- The round portrait is a setting: today's ring, disc and round badge, with the chamfered chrome hidden.
K.Options.Write("UnitFrames", "player.portraitShape", "round")
assert(player.ring:IsShown() and player.portraitBack:IsShown(), "round: the ring and disc show")
local _, roundBevels = pieces(player.portraitFrame, "lumenShape")
assert(roundBevels == 0, "round: the chamfered frame hides")
assert(maskPath(player) == (Tokens.Texture("dot")), "round: the image is masked to a circle")
assert(env._unmasked[player.portrait] == false, "round: the 2D portrait keeps the game's own round mask")
assert(select(2, pieces(player.badge, "lumenShape")) == 9, "round: the badge is still the octagon, as the mockup draws it on the ring")
assert(W.SameRGB(player.badgeChrome.rim[1], ar, ag, ab), "round: the octagon's line is the class colour, like the ring on the mockup")
assert(player.badgeChrome.fillName == "buttonFill", "round: filled with the button body, the mockup's #101214")
assert(W.LastCall(player.ring, "SetTexture")[1] == (Tokens.Texture("ringBevel")), "round: the ring is the bevelled ring texture, the mockup's thin metal ring")
assert(W.SameRGB(player.ring, K.Widgets.Mix(ar, ag, ab, 1, 1, 1, 1, 1, 0.3)), "round: the ring's tint is the class colour lifted 30% toward white, the mockup's #d7b89f line; the texture shades it down to the colour and below")
local _, _, _, discX, discY = player.badge:GetPoint(1)
assert(near(discX, player.geometry.badge.x, 1) and near(-discY, player.geometry.badge.y, 1) and player.geometry.badge.x > 0, "round: the badge sits on the ring's lower outer point, where Geometry puts it")
local shadowShown = 0
for _, piece in ipairs(player.portraitChrome.shadow) do
	if piece:IsShown() then
		shadowShown = shadowShown + 1
	end
end
K.Widgets.RestyleAll()
for _, piece in ipairs(player.portraitChrome.shadow) do
	assert(not piece:IsShown(), "round: a restyle never brings back the chamfered frame's shadow")
end
assert(shadowShown == 0 and select(2, pieces(player.portraitFrame, "lumenShape")) == 0, "round: the chamfered frame stays hidden")
K.Options.Write("UnitFrames", "player.portraitShape", "chamfered")
assert(select(2, pieces(player.portraitFrame, "lumenShape")) == 9 and not player.ring:IsShown(), "chamfered again")
assert(W.SameRGB(player.badgeChrome.rim[1], nr, ng, nb), "and the badge's line is neutral again")
noErrors("round portrait")

-- Compact frames wear the tile, the kit's shape for small parts: no frost.
local pet = Frames.Get("pet").views[1]
assert(select(2, pieces(pet.panel, "lumenShape")) == 9 and select(1, pieces(pet.panel, "lumenFrost")) == 0, "the pet frame's glass is a rounded tile")
assert(select(2, pieces(Frames.Get("target").views[1].panel, "lumenFrost")) == 9, "the target's glass is a frosted panel")

-- Cast bars. The player's, as the owner's mockup draws Slam: no icon, the glass across the whole width.
local cast = CastBars.Get("player")[1]
local cg = cast.geometry
assert(cg and cg.icon == nil and near(cg.panel.x, 0) and near(cg.panel.w, K.Setup.Layouts.Element("unitframes.castbar.player").width), "the player cast bar has no icon by default and its glass spans the width")
-- With the icon on, the design file's layout: the spell icon in its own chamfered square, a gap, then the glass bar.
K.Options.Write("UnitFrames", "player.castbarIcon", true)
K.Options.Write("UnitFrames", "player.castbarCaps", true)
cg = cast.geometry
local castW, castH = K.Setup.Layouts.Element("unitframes.castbar.player").width, K.Setup.Layouts.Element("unitframes.castbar.player").height
assert(cg and cg.icon and cg.panel and cg.bar, "the cast bar lays out an icon, a glass panel and a bar")
assert(near(cg.icon.x, 0) and near(cg.icon.w, cg.icon.h) and near(cg.icon.h, castH), "the icon is a square as tall as the cast bar")
local iw, ih = cast.iconFrame:GetSize()
assert(near(iw, castH, 1) and near(ih, castH, 1), "the icon frame takes that square")
assert(select(2, pieces(cast.iconFrame, "lumenShape")) == 9, "the icon square is a rounded tile")
assert(near(cg.panel.x, cg.icon.x + cg.icon.w + math.floor(0.21 * castH + 0.5)) and near(cg.panel.x + cg.panel.w, castW) and near(cg.panel.h, castH), "the glass starts after the design's gap, 0.21 of the bar's height (6 on 28), and runs to the end")
assert(near(cg.panel.y + cg.panel.h - (cg.bar.y + cg.bar.h), math.floor(0.22 * castH + 0.5)), "the bar sits 0.22 H above the glass's bottom, under the text as the mockup draws Slam's bar")
assert(near(cg.bar.x - cg.panel.x, math.floor(0.5 * castH + 0.5)), "the bar and the spell name start 0.5 H in: the mockup's 18 units on a 37-unit bar")
assert(select(2, pieces(cast.panel, "lumenFrost")) == 9, "the cast bar's glass is a frosted panel")
assert(near(cast.chrome:Chamfer(), math.min(14, cg.panel.h / 2), 0.01), "the glass rounds 14 units, at most half its height, got " .. tostring(cast.chrome:Chamfer()))
assert(W.SameColor(cast.chrome.rim[7], K.Tokens.Color("edgeInner")), "with the panel's rim, not the bars' faint line")
assert(cast.bar.chrome == nil, "the bar inside the glass has no border of its own")

-- At 30 units the kit's two rows fit: the spell name and the time on top, a thin bar under them.
assert(cg.stacked, "a 30-unit cast bar stacks its text over a thin bar")
assert(cg.bar.x > cg.panel.x and cg.bar.x + cg.bar.w < cg.panel.x + cg.panel.w, "the bar sits inside the glass")
assert(cg.bar.y + cg.bar.h <= cg.panel.y + cg.panel.h and cg.bar.h == math.floor(0.22 * castH), "the bar is a thin line inside the glass's bottom edge: 22% of the bar's height, the mockup's 7 on 37")
assert(mid(cg.text) < cg.bar.y and near(mid(cg.text), mid(cg.timer)), "the spell name and the time share the row above the bar")
assert(near(cg.text.x, cg.bar.x) and near(cg.timer.x + cg.timer.w, cg.bar.x + cg.bar.w), "the name starts and the time ends with the bar")
local _, _, _, bx, by = cast.bar:GetPoint(1)
assert(near(bx, cg.bar.x, 1) and near(-by, cg.bar.y, 1), "the bar is placed from the geometry")

-- The target cast bar at its 24-unit footprint: the icon square, then the glass with the spell name and the time
-- stacked over a thin bar, as the kit sheet draws it. Made 14 units tall in Layout, the name and time sit on the bar.
local target = CastBars.Get("target")[1]
local tg = target.geometry
local targetCastH = K.Setup.Layouts.Element("unitframes.castbar.target").height
assert(near(tg.icon.w, targetCastH) and near(tg.icon.h, targetCastH) and near(tg.panel.x, targetCastH + math.floor(0.21 * targetCastH + 0.5)), "the target's icon is its own square as tall as the bar, then the design's 0.21 H gap")
assert(select(2, pieces(target.panel, "lumenFrost")) == 9, "the target cast bar's glass is a frosted panel too")
assert(tg.stacked and mid(tg.text) < tg.bar.y and near(mid(tg.text), mid(tg.timer)), "24 units: the name and time stack over a thin bar")
assert(K.Layout.Set("unitframes.castbar.target", "height", 14), "the target cast bar can be 14 units tall")
tg = target.geometry
assert(not tg.stacked and near(mid(tg.text), mid(tg.bar)) and near(mid(tg.timer), mid(tg.bar)), "14 units: the name and time sit on the bar")
assert(tg.text.x < tg.timer.x and tg.text.x + tg.text.w <= tg.timer.x + 1e-6, "the name at the left stops before the time at the right")
assert(tg.bar.x >= tg.panel.x and tg.bar.x + tg.bar.w <= tg.panel.x + tg.panel.w and tg.bar.y >= tg.panel.y and tg.bar.y + tg.bar.h <= tg.panel.h, "the bar sits inside the glass")
K.Layout.Reset("unitframes.castbar.target")
assert(target.geometry.stacked, "and the reset stacks them again")

-- A short cast bar keeps its text on the bar, inside the same glass.
local boss = CastBars.Get("boss")[1]
assert(boss.geometry and not boss.geometry.stacked, "a 10-unit boss cast bar is too short for two rows")
assert(near(mid(boss.geometry.text), mid(boss.geometry.bar)), "its text sits on the bar")
assert(boss.geometry.bar.h > boss.geometry.panel.h / 2, "its bar fills the glass")
noErrors("cast layout")

-- The spell name is in capitals. A secret name reaches the text untouched.
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(U.Shown(env, cast.text) == "FROSTBOLT", "the spell name in capitals: " .. U.Shown(env, cast.text))
local THIN = "\226\128\137"
assert(W.LastCall(cast.text, "SetText")[1] == table.concat({ "F", "R", "O", "S", "T", "B", "O", "L", "T" }, THIN), "the capitals are tracked with thin spaces, as the design file's caption")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
U.SetUnit(env, "target", { name = "Summoner", level = 51, health = 50, healthMax = 100, reaction = 2, secretCast = true,
	cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, spellID = 999 } })
env.SetTarget(true)
local set = W.LastCall(target.text, "SetText")
assert(set and env.issecretvalue(set[1]), "a secret spell name reaches the text untouched")
U.SetUnit(env, "target", nil)
env.SetTarget(false)
env.RunTimers()
W.Settle(env)
noErrors("cast text")

print("unitframes kit ok")
