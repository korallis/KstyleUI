-- test-nameplates.lua: KstyleUI_Nameplates attaches a plate to each nameplate, fades Blizzard's plate and shows health, name, level, markers, threat and highlights.
local N = dofile("Tools/regression/nameplates_env.lua")
local Calls, Last, SameColor = N.Calls, N.Last, N.SameColor

local function token(K, name)
	local r, g, b = K.Tokens.Color(name)
	return r, g, b
end

local function barColor(bar)
	local r, g, b = bar:GetStatusBarColor()
	return r, g, b
end

local function edgeColor(bar)
	local r, g, b = bar.chrome.inner[1]:GetVertexColor()
	return r, g, b
end

-- Off by default: loading the module and logging in creates no plate and registers no event --------

do
	local env, K, ns = N.New({ enable = false })
	assert(K.Modules.IsEnabled("Nameplates") == false, "Nameplates is off by default")
	assert(type(ns.Plates) == "table" and type(ns.Plates.Get) == "function", "the module exposes Plates.Get")
	N.Add(env, "nameplate1")
	assert(ns.Plates.Get("nameplate1") == nil, "an off module attaches nothing")
	assert(env._bases.nameplate1.UnitFrame:GetAlpha() == 1, "an off module leaves Blizzard's plate alone")
end

-- Attach: a KstyleUI plate on the base, Blizzard's UnitFrame faded, never reparented -----------------

do
	local env, K, ns = N.New()
	local base = N.Add(env, "nameplate1", { name = "Dark Iron Summoner", health = 64, maxHealth = 100, level = 51 })
	local plate = ns.Plates.Get("nameplate1")
	assert(plate, "NAME_PLATE_UNIT_ADDED attaches a plate")
	assert(plate:GetParent() == base, "the plate is a child of the nameplate's base frame")
	assert(plate:IsShown(), "the plate shows")
	assert(base.UnitFrame:GetAlpha() == 0, "Blizzard's UnitFrame is faded with alpha")
	for _, frame in ipairs({ base, base.UnitFrame }) do
		for _, method in ipairs({ "SetParent", "SetScript", "Hide", "ClearAllPoints", "SetPoint", "SetSize" }) do
			assert(#Calls(frame, method) == 0, "KstyleUI never calls " .. method .. " on Blizzard's nameplate frames")
		end
	end

	-- Health passes through: the bar gets the secret, never a number made from it.
	local health = plate.health
	local range = Last(health, "SetMinMaxValues")
	assert(range and range[1] == 0 and range[2] == 100, "the health range is 0 to UnitHealthMax")
	local value = Last(health, "SetValue")
	assert(value and env.issecretvalue(value[1]) and env.Reveal(value[1]) == 64, "the health bar gets UnitHealth's secret")
	local pct = Last(plate.healthText, "SetFormattedText")
	assert(pct and env.issecretvalue(pct[2]) and env.Reveal(pct[2]) == 64, "the health text formats UnitHealthPercent's secret")

	env._units.nameplate1.health = 20
	env.FireEvent("UNIT_HEALTH", "nameplate1")
	assert(env.Reveal(Last(health, "SetValue")[1]) == 20, "UNIT_HEALTH updates the bar")
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(env.Reveal(Last(health, "SetValue")[1]) == 20, "health events for other units are ignored")

	-- Name: upper case when it can be read, passed through whole when it is secret.
	assert(plate.name:GetText() == "DARK IRON SUMMONER", "a readable name is upper case")
	assert(plate.levelText:GetText() == "51", "the level shows")

	-- Removal hides the plate and leaves the base to Blizzard; the same base gets the plate back.
	N.Remove(env, "nameplate1")
	assert(ns.Plates.Get("nameplate1") == nil, "NAME_PLATE_UNIT_REMOVED detaches the plate")
	assert(not plate:IsShown(), "a removed plate hides")
	K.Options.Write("Nameplates", "name.size", 13)
	local again = N.Add(env, "nameplate2", { name = "Fire Elemental", secretName = true }, { base = base })
	assert(Last(plate.name, "SetFont")[2] == 13, "a setting changed while the plate was detached applies when it attaches again")
	assert(again == base and ns.Plates.Get("nameplate2") == plate, "a base keeps its one plate")
	assert(plate:IsShown(), "the plate shows again")
	local name = Last(plate.name, "SetText")[1]
	assert(env.issecretvalue(name) and env.Reveal(name) == "Fire Elemental", "a secret name passes through whole")
end

-- Blizzard's code puts the UnitFrame's alpha back; the module fades it again while it runs ----------

do
	local env, K, ns = N.New()
	local base = N.Add(env, "nameplate1")
	base.UnitFrame:SetAlpha(1)
	assert(base.UnitFrame:GetAlpha() == 0, "a hook fades the UnitFrame again")
	local highlight = base.UnitFrame.selectionHighlight
	assert(highlight:GetAlpha() == 0, "the selection highlight, which ignores its parent's alpha, is faded too")
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	assert(base.UnitFrame:GetAlpha() == 1, "Disable gives Blizzard's plate its alpha back")
	assert(highlight:GetAlpha() == 0.25, "and the selection highlight its own")
	assert(not ns.Plates.Get("nameplate1"), "Disable detaches every plate")
	base.UnitFrame:SetAlpha(0.5)
	assert(base.UnitFrame:GetAlpha() == 0.5, "the hook does nothing while the module is off")
	N.Add(env, "nameplate2")
	assert(ns.Plates.Get("nameplate2") == nil, "a disabled module ignores new plates")
	K.Modules.Enable("Nameplates")
	env.RunTimers()
	assert(ns.Plates.Get("nameplate2"), "Enable attaches plates that are already shown")
	assert(env._bases.nameplate2.UnitFrame:GetAlpha() == 0, "and fades them")
end

-- The soft-target icon (gamepad interact prompt, accessibility target icons) stays visible on a faded plate --

do
	local env, K = N.New()
	local base = N.Add(env, "nameplate1")
	local unitFrame = base.UnitFrame
	local soft = unitFrame.SoftTargetFrame
	assert(unitFrame:GetEffectiveAlpha() == 0, "Blizzard's plate is faded")
	assert(soft.Icon:GetEffectiveAlpha() == 1, "the soft-target icon Blizzard draws on its plate stays visible")
	unitFrame:SetAlpha(1)
	assert(unitFrame:GetAlpha() == 0 and soft.Icon:GetEffectiveAlpha() == 1, "and stays visible when the fade is put back")

	N.Remove(env, "nameplate1")
	assert(not soft:IsIgnoringParentAlpha(), "a detached plate's soft-target frame follows its parent's alpha again")
	N.Add(env, "nameplate2", nil, { base = base })
	assert(soft.Icon:GetEffectiveAlpha() == 1, "a reattached plate keeps the icon visible")
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	assert(not soft:IsIgnoringParentAlpha(), "Disable gives the soft-target frame its own setting back")

	local env2 = N.New()
	local base2 = N.Base(env2)
	local soft2 = base2.UnitFrame.SoftTargetFrame
	soft2:SetIgnoreParentAlpha(true)
	N.Add(env2, "nameplate1", nil, { base = base2 })
	N.Remove(env2, "nameplate1")
	assert(soft2:IsIgnoringParentAlpha(), "a frame that already ignored its parent's alpha keeps doing so")

	local env3, _, ns3 = N.New()
	local bare = N.Base(env3)
	bare.UnitFrame.SoftTargetFrame = nil
	N.Add(env3, "nameplate1", nil, { base = bare })
	assert(ns3.Plates.Get("nameplate1") and bare.UnitFrame:GetAlpha() == 0, "a UnitFrame without a soft-target frame still fades")
	N.Remove(env3, "nameplate1")
	for _, e in ipairs({ env, env2, env3 }) do
		assert(#e._errors == 0, tostring(e._errors[1]))
	end
end

-- KstyleUI's handler can run before Blizzard's driver acquires the UnitFrame ------------------------

do
	local env, _, ns = N.New()
	local base = N.Add(env, "nameplate1", nil, { lateUnitFrame = true })
	assert(ns.Plates.Get("nameplate1"), "the plate attaches at once")
	env.RunTimers()
	assert(base.UnitFrame:GetAlpha() == 0, "the fade waits a frame for the UnitFrame")
end

-- The player's own plate and widget-only plates stay Blizzard's -------------------------------------

do
	local env, _, ns = N.New()
	env._playerPlate = "nameplate1"
	N.Add(env, "nameplate1", { canAttack = false })
	assert(ns.Plates.Get("nameplate1") == nil, "the personal nameplate is left to Blizzard")
	N.Add(env, "nameplate2", { widgetsOnly = true })
	assert(ns.Plates.Get("nameplate2") == nil, "a widgets-only plate is left to Blizzard")
	assert(env._bases.nameplate2.UnitFrame:GetAlpha() == 1, "and keeps its alpha")
end

-- Colours: enemy NPCs by reaction, players by class, tapped units grey, friends by their style -------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1", { reaction = 2 })
	local plate = ns.Plates.Get("nameplate1")
	local hr, hg, hb = token(K, "hostile")
	assert(SameColor(hr, hg, hb, barColor(plate.health)), "a hostile NPC uses the hostile colour")
	assert(plate.kind == "enemy", "an attackable unit uses the enemy style")

	N.Add(env, "nameplate2", { isPlayer = true, class = "MAGE" })
	local mage = N.CLASS.MAGE
	assert(SameColor(mage[1], mage[2], mage[3], barColor(ns.Plates.Get("nameplate2").health)), "an enemy player uses the class colour")

	N.Add(env, "nameplate5", { isPlayer = true, class = "MAGE", secretClass = true })
	local hidden = ns.Plates.Get("nameplate5")
	local sr, sg, sb = barColor(hidden.health)
	assert(env.issecretvalue(sr), "a secret class colour reaches the health bar as a secret")
	assert(SameColor(mage[1], mage[2], mage[3], env.Reveal(sr), env.Reveal(sg), env.Reveal(sb)), "and it is the class colour")
	local nr, ng, nb = hidden.name:GetTextColor()
	assert(env.issecretvalue(nr), "the name takes the secret class colour too")
	assert(SameColor(mage[1], mage[2], mage[3], env.Reveal(nr), env.Reveal(ng), env.Reveal(nb)), "the class colour")
	env.FireEvent("UNIT_HEALTH", "nameplate5")
	env.FireEvent("UNIT_FLAGS", "nameplate5")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "a secret class colour is never compared: " .. tostring(env._errors[1]))
	N.Remove(env, "nameplate5")

	N.Add(env, "nameplate3", { tapped = true })
	local tr, tg, tb = token(K, "textDisabled")
	assert(SameColor(tr, tg, tb, barColor(ns.Plates.Get("nameplate3").health)), "a tapped unit is grey")

	N.Add(env, "nameplate4", { canAttack = false, reaction = 5 })
	local friend = ns.Plates.Get("nameplate4")
	local fr, fg, fb = token(K, "friendly")
	assert(friend.kind == "friendly", "a unit the player cannot attack uses the friendly style")
	assert(SameColor(fr, fg, fb, barColor(friend.health)), "a friendly NPC uses the friendly colour")

	K.Options.Write("Nameplates", "enemy.colorSource", "custom")
	K.Options.Write("Nameplates", "enemy.color", { r = 0.1, g = 0.2, b = 0.3 })
	assert(SameColor(0.1, 0.2, 0.3, barColor(plate.health)), "a custom enemy colour applies at once")
	assert(SameColor(0.1, 0.2, 0.3, barColor(ns.Plates.Get("nameplate2").health)), "to players too")

	K.Options.Write("Nameplates", "friendly.nameOnly", true)
	assert(not friend.health:IsShown() and friend.name:IsShown(), "name-only friendly plates hide the bar")
	assert(plate.health:IsShown(), "enemy plates keep their bar")

	env._units.nameplate1.canAttack = false
	env._units.nameplate1.reaction = 5
	env.FireEvent("UNIT_FACTION", "nameplate1")
	assert(plate.kind == "friendly" and not plate.health:IsShown(), "UNIT_FACTION switches the style")
end

-- Level, classification and raid markers ---------------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1", { classification = "elite", level = -1 })
	local plate = ns.Plates.Get("nameplate1")
	assert(plate.levelText:GetText() == "??", "a skull level reads ??")
	assert(plate.marker:IsShown(), "an elite shows its marker")
	local nr, ng, nb = token(K, "neutral")
	local r, g, b = plate.marker:GetVertexColor()
	assert(SameColor(nr, ng, nb, r, g, b), "the elite marker is gold")

	N.Add(env, "nameplate2", { classification = "rare" })
	local rare = ns.Plates.Get("nameplate2")
	local rr, rg, rb = token(K, "rare")
	r, g, b = rare.marker:GetVertexColor()
	assert(rare.marker:IsShown() and SameColor(rr, rg, rb, r, g, b), "a rare shows a blue marker")

	N.Add(env, "nameplate3")
	local normal = ns.Plates.Get("nameplate3")
	assert(not normal.marker:IsShown(), "a normal unit shows no marker")
	assert(not normal.raid:IsShown(), "no raid marker without one")

	env._units.nameplate3.raid = 8
	env.FireEvent("RAID_TARGET_UPDATE")
	assert(normal.raid:IsShown(), "RAID_TARGET_UPDATE shows the marker")
	local cell = Last(normal.raid, "SetSpriteSheetCell")
	assert(cell and env.issecretvalue(cell[1]) and env.Reveal(cell[1]) == 8, "the secret index reaches the sprite sheet")
	env._units.nameplate3.raid = nil
	env.FireEvent("RAID_TARGET_UPDATE")
	assert(not normal.raid:IsShown(), "a cleared marker hides")

	K.Options.Write("Nameplates", "level.show", false)
	assert(not plate.level:IsShown(), "the level badge can be switched off")
	K.Options.Write("Nameplates", "markers.classification", false)
	assert(not plate.marker:IsShown(), "classification markers can be switched off")
	K.Options.Write("Nameplates", "name.show", false)
	assert(not plate.name:IsShown(), "the name can be switched off")
	K.Options.Write("Nameplates", "healthText.show", false)
	assert(not plate.healthText:IsShown(), "the health text can be switched off")
end

-- Threat: readable on Forever, coloured for the player's role ---------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate0", { threat = 3 })
	assert(not ns.Plates.Get("nameplate0").threatGlow[1]:IsShown(), "threat shows only in a group by default")
	env._inGroup = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	N.Add(env, "nameplate1", { threat = 3 })
	local plate = ns.Plates.Get("nameplate1")
	local glow = plate.threatGlow
	assert(glow[1]:IsShown(), "a mob attacking a damage dealer shows the threat glow")
	local dr, dg, db = token(K, "hostile")
	assert(SameColor(dr, dg, db, glow[1]:GetVertexColor()), "aggro on a damage dealer is danger red")

	env._units.nameplate1.threat = nil
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
	assert(not glow[1]:IsShown(), "no threat entry hides the glow")

	env._role = "TANK"
	env._units.nameplate1.threat = 3
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	local sr, sg, sb = token(K, "friendly")
	assert(glow[1]:IsShown() and SameColor(sr, sg, sb, glow[1]:GetVertexColor()), "a tank holding aggro is safe green")
	env._units.nameplate1.threat = 0
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	assert(SameColor(dr, dg, db, glow[1]:GetVertexColor()), "a tank who lost aggro sees danger")

	env._units.nameplate1.threat = env.Secret(3)
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
	assert(not glow[1]:IsShown(), "a secret threat status is never compared; the glow hides")

	env._units.nameplate1.threat = 2
	K.Options.Write("Nameplates", "threat.display", "health")
	local wr, wg, wb = token(K, "neutral")
	assert(not glow[1]:IsShown(), "the health display hides the glow")
	assert(SameColor(wr, wg, wb, barColor(plate.health)), "and colours the bar with the threat colour")
	K.Options.Write("Nameplates", "threat.display", "off")
	local hr, hg, hb = token(K, "hostile")
	assert(SameColor(hr, hg, hb, barColor(plate.health)), "threat off gives the bar its own colour back")
end

-- Target and focus highlight ------------------------------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	N.Add(env, "nameplate2")
	local one, two = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	assert(not one.targetGlow[1]:IsShown(), "no target, no highlight")
	N.Target(env, "nameplate1")
	assert(one.targetGlow[1]:IsShown() and not two.targetGlow[1]:IsShown(), "the target's plate is highlighted")
	local ar, ag, ab = K.Theme.Accent()
	assert(SameColor(ar, ag, ab, one.targetGlow[1]:GetVertexColor()), "the highlight follows the accent")
	assert(one:GetAlpha() == 1 and two:GetAlpha() == 1, "other plates stay opaque by default")

	K.Options.Write("Nameplates", "target.dimOthers", 0.5)
	assert(one:GetAlpha() == 1 and two:GetAlpha() == 0.5, "other plates dim while there is a target")
	N.Target(env, nil)
	assert(one:GetAlpha() == 1 and two:GetAlpha() == 1, "without a target nothing dims")
	assert(not one.targetGlow[1]:IsShown(), "clearing the target clears the highlight")

	K.Options.Write("Nameplates", "target.colorSource", "custom")
	K.Options.Write("Nameplates", "target.color", { r = 0.9, g = 0.1, b = 0.1 })
	N.Target(env, "nameplate2")
	assert(SameColor(0.9, 0.1, 0.1, two.targetGlow[1]:GetVertexColor()), "the highlight can use a custom colour")

	N.Focus(env, "nameplate1")
	local fr, fg, fb = token(K, "rare")
	assert(SameColor(fr, fg, fb, edgeColor(one.health)), "the focus's plate gets the focus edge")
	N.Focus(env, nil)
	assert(not SameColor(fr, fg, fb, edgeColor(one.health)), "clearing the focus clears the edge")
end

-- The target's plate leaves range and its base comes back for another unit: no stale highlight ---------

do
	local env, _, ns = N.New()
	local base = N.Add(env, "nameplate1")
	N.Target(env, "nameplate1")
	N.Remove(env, "nameplate1")
	env._targetUnit = "target"
	env._units.target = { name = "Far Away" }
	N.Add(env, "nameplate2", nil, { base = base })
	assert(not ns.Plates.Get("nameplate2").targetGlow[1]:IsShown(), "a reused base is not the target any more")
end

-- A client whose GetNamePlateForUnit takes only nameplate tokens: highlights fall back to UnitIsUnit ---

do
	local env, _, ns = N.New({ strictTokens = true })
	N.Add(env, "nameplate1")
	N.Add(env, "nameplate2")
	N.Target(env, "nameplate2")
	assert(ns.Plates.Get("nameplate2").targetGlow[1]:IsShown(), "the target is found with UnitIsUnit")
	assert(not ns.Plates.Get("nameplate1").targetGlow[1]:IsShown(), "and only the target")
	env.UnitIsUnit = function()
		return env.Secret(true)
	end
	N.Target(env, "nameplate1")
	assert(not ns.Plates.Get("nameplate1").targetGlow[1]:IsShown(), "a secret comparison is never tested; no highlight")
end

-- Settings restyle live plates ------------------------------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local path = K.Tokens.MediaList("statusbar")[3].path
	K.Options.Write("Nameplates", "health.texture", path)
	assert(Last(plate.health, "SetStatusBarTexture")[1] == path, "the bar texture follows the setting")
	K.Options.Write("Nameplates", "name.size", 14)
	local font = Last(plate.name, "SetFont")
	assert(font and font[2] == 14 and font[3] == "OUTLINE", "the name font size follows the setting")
	K.Options.Write("Nameplates", "name.outline", "NONE")
	assert(Last(plate.name, "SetFont")[3] == "", "no outline gives a soft shadow instead")
	K.Options.Write("Nameplates", "health.orientation", "VERTICAL")
	assert(Last(plate.health, "SetOrientation")[1] == "VERTICAL", "the bar orientation follows the setting")
	K.Options.Write("Nameplates", "health.reverse", true)
	assert(Last(plate.health, "SetReverseFill")[1] == true, "the fill direction follows the setting")
	K.Options.Write("Nameplates", "healthText.format", "value")
	local text = Last(plate.healthText, "SetText")[1]
	assert(env.issecretvalue(text) and env.Reveal(text) == "abbr:40", "the value format abbreviates UnitHealth")
end

-- Size: the mockup's plate, a 126 x 16 frame with a 23-unit level disc rimmed in the bar's colour -------

do
	local env, _, ns = N.New()
	assert(ns.Plate.DEFAULT_WIDTH == 122 and ns.Plate.DEFAULT_HEIGHT == 12, "the health bar is 122 x 12 inside its two-border frame: 126 x 16 outside")
	N.Add(env, "nameplate1", { name = "Riverglade Crocolisk", health = 40, maxHealth = 100, level = 38, reaction = 2 })
	local plate = ns.Plates.Get("nameplate1")
	assert(N.Same(plate.health:GetWidth(), 122) and N.Same(plate.health:GetHeight(), 12), "the bar takes the default size")
	local disc = plate.level
	assert(N.Same(disc:GetWidth(), 23) and N.Same(disc:GetHeight(), 23), "the level disc is 23 units across")
	assert(disc.chrome.shape.fill == "chamferPanel" and disc.chrome.shadowOn == false and disc.chrome.noise == nil, "an octagon: the panel chamfer, no shadow, no grain")
	local r, g, b = barColor(plate.health)
	assert(SameColor(r, g, b, disc.chrome.inner[1]:GetVertexColor()), "its rim takes the bar's colour")
	local point, relative, relativePoint, x = disc:GetPoint(1)
	assert(point == "RIGHT" and relative == plate.health and relativePoint == "LEFT" and x == 0, "it sits on the bar's left end")
	assert(select(2, plate.name:GetFont()) == 11, "the name reads at 11 units")
	assert(select(2, plate.levelText:GetFont()) == 10, "the level at 10")
	assert(plate.castBar.opts.height == 10, "the cast bar is 10 units tall")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("nameplates ok")

-- Size: a plate draws in KstyleUI root units whatever scale the game gives its base -----------------

do
	local env, K, ns = N.New()
	local root = K.Scale.Root():GetEffectiveScale()
	local ui = env.UIParent:GetEffectiveScale()
	-- The game scales a base by UIParent's effective scale times the plate's own factor: here 0.58,
	-- as the owner's Mac reads for a plate near the player.
	local base = N.Add(env, "nameplate1", nil, { scale = 0.58 })
	local plate = ns.Plates.Get("nameplate1")
	assert(N.Same(base:GetEffectiveScale(), 0.58), "the fake base draws at 0.58")
	assert(N.Same(plate:GetEffectiveScale(), root), "a plate on a base at 0.58 draws at KstyleUI_Root's scale")
	assert(N.Same(plate:GetWidth() * plate:GetEffectiveScale(), ns.state.width * root), "so its bar is as wide as the same units on the HUD")

	-- The unit walks away: C code shrinks the base per frame with no event.
	assert(#Calls(base, "SetScale") == 0, "KstyleUI never scales Blizzard's base")
	base:SetScale(0.4)
	assert(N.Same(plate:GetEffectiveScale(), root), "a distant base leaves the plate's size alone, with no update needed")
	assert(#Calls(base, "SetIgnoreParentScale") == 0 and #Calls(base, "SetSize") == 0, "only the plate's own scale changes")

	-- Shrink distant plates: the plate takes the base's share of the UI scale and follows it.
	K.Options.Write("Nameplates", "shrinkDistant", true)
	assert(N.Same(plate:GetEffectiveScale(), root * 0.4 / ui), "with the setting on, a base at 0.4 of the UI scale draws the plate at 0.4 of root units")
	base:SetScale(ui * 1.2)
	assert(N.Same(plate:GetEffectiveScale(), root * 1.2), "and the target's larger base grows the plate with it")
	K.Options.Write("Nameplates", "shrinkDistant", false)
	assert(N.Same(plate:GetEffectiveScale(), root), "off again, the plate holds its size")

	-- A base reused for a new unit keeps the plate's scale right.
	N.Remove(env, "nameplate1")
	N.Add(env, "nameplate2", { name = "Defias Pillager" }, { base = base })
	assert(ns.Plates.Get("nameplate2") == plate and N.Same(plate:GetEffectiveScale(), root), "a reused base keeps its plate at root scale")

	-- The sample plate lives on KstyleUI_Root and keeps scale 1.
	local sample = ns.Preview.samplePlate
	assert(sample and sample:GetScale() == 1 and not sample:IsIgnoringParentScale(), "the sample plate keeps scale 1 and its parent's scale")
	assert(N.Same(sample:GetEffectiveScale(), root), "so it draws at root scale too")
end
