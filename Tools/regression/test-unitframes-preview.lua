-- test-unitframes-preview.lua: the settings window shows the unit frames page, one frame's rows at a time, and a live preview of the frame being customised.
local U = dofile("Tools/regression/unitframes_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = U.W

-- These checks pin the classic plate's preview, the style setting's other choice; the Lumen preview is checked at the end.
local PLATE = { enabled = true }
for _, kind in ipairs(U.KINDS) do
	PLATE[kind] = { style = "plate" }
end
PLATE.target.auras = false
local env, K, ns = O.New({
	setup = U.Install,
	saved = { version = 2, profiles = { Default = { UnitFrames = PLATE } }, characters = {} },
	before = function(e)
		Load(U.Files(), e)
	end,
})
local uf = env._addons.KstyleUI_UnitFrames
assert(K.Modules.IsRunning("UnitFrames"), "the module runs")

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function has(list, label)
	for _, value in ipairs(list) do
		if value == label then
			return true
		end
	end
	return false
end

K.Options.Open("UnitFrames")
settle()
assert(ns.Window.State().page == "UnitFrames", "the unit frames page opens")
local labels = O.Labels(ns.Window.State().items)
assert(has(labels, "Frame to customise"), "the page has the frame picker")
assert(has(labels, "Player: frame") and not has(labels, "Target: frame"), "only the player frame's rows show at first")

-- The preview is the module's own builder, drawing the player frame with sample values.
local pane = ns.Window.Parts().preview
local preview = pane.current
assert(preview and preview ~= pane.placeholder and preview.Refresh, "the preview is the module's frame")
assert(preview.kind == "player", "the preview starts on the player frame")
local view = preview.views.player
assert(U.Shown(env, view.name) == "VALERIN", "the sample name in capitals")
assert(U.Shown(env, view.healthText) == "78%", "the sample health text follows the format")
assert(U.Shown(env, view.healthSub) == "3120 / 3980", "the sample shows current and max under the track")
assert(view.icons.leader:IsShown(), "the player sample shows where the leader icon sits")
do
	-- The sample's power bar reads the player's own power type (the owner's ruling of 2026-11-08: power is never
	-- class-coloured by default), so a warrior's preview shows a rage-red bar, not the class colour or a flat blue.
	local c = view.power.colorRGBA
	local pr, pg, pb = c[1], c[2], c[3]
	local er, eg, eb = uf.Unit.PowerTypeColor("player")
	assert(math.abs(pr - er) < 1e-6 and math.abs(pg - eg) < 1e-6 and math.abs(pb - eb) < 1e-6, "the player sample's power bar wears the player's power type colour")
	local cr, cg, cb = K.Theme.ClassColor(K.Theme.Class())
	assert(not (math.abs(pr - cr) < 1e-6 and math.abs(pg - cg) < 1e-6 and math.abs(pb - cb) < 1e-6), "and not the class colour")
end
assert(view.geometry.glass.x < view.geometry.portrait.x + view.geometry.portrait.w, "the sample's glass runs under its portrait")
assert(view.ring:IsShown() and not view.portraitChrome.rim[1]:IsShown(), "the sample portrait is round by default, as the owner's mockup draws it")
assert(view.badgeChrome.rim[1]:IsShown(), "with the octagon level badge on the ring")
K.Options.Write("UnitFrames", "player.portraitShape", "chamfered")
settle()
assert(view.portraitChrome.rim[1]:IsShown() and not view.ring:IsShown(), "the square portrait is the other choice")
assert(env._unmasked[view.portrait] == true, "the sample asks for the square portrait the rounded mask masks")
assert(view.badgeChrome.rim[1]:IsShown(), "the sample's level badge is the octagon there too")
local cast = preview.casts.player
assert(cast and cast.frame:IsShown() and U.Shown(env, cast.text) == "Frostbolt", "the player sample shows a cast bar under the frame, its spell as the game writes it")
assert(cast.geometry and cast.geometry.icon == nil and cast.geometry.panel.x == 0, "the sample player cast bar has no icon, as on the mockup")
K.Options.Write("UnitFrames", "player.portraitShape", "round")
settle()
assert(view.ring:IsShown() and not view.portraitChrome.rim[1]:IsShown(), "a round portrait shows in the preview")
assert(view.badgeChrome.rim[1]:IsShown(), "with the octagon badge on its ring")
K.Options.Write("UnitFrames", "player.portraitShape", "chamfered")
settle()
for _, frame in ipairs(env._frames) do
	if frame:GetParent() == preview or (frame:GetParent() and frame:GetParent():GetParent() == preview) then
		assert(frame._template == nil, "the preview makes no secure frames")
	end
end

-- Picking another frame shows its rows and its preview.
K.Options.Write("UnitFrames", "edit", "target")
settle()
labels = O.Labels(ns.Window.State().items)
assert(has(labels, "Target: frame") and not has(labels, "Player: frame"), "picking the target shows the target's rows")
assert(preview.kind == "target", "the preview follows the picked frame")
local target = preview.views.target
assert(U.Shown(env, target.name) == "FROST HOWLER", "the target sample")
assert(target.marker:IsShown() and target.glowFrame:IsShown(), "the target sample shows a raid marker and the threat glow")
local tr, tg, tb = K.Theme.ThreatColor(3)
assert(W.SameRGB(target.glow[1], tr, tg, tb), "the sample's threat glow is the tanking colour")
assert(target.geometry.portrait.x > target.geometry.panel.x, "the target sample mirrors the player frame")

-- Settings redraw the preview at once.
K.Options.Write("UnitFrames", "target.healthText", "currentMax")
settle()
assert(U.Shown(env, target.healthText) == "2240 / 4020", "a new text format shows in the preview")
K.Options.Write("UnitFrames", "target.portrait", false)
settle()
assert(target.portraitFrame:IsShown() == false, "switching the portrait off hides it in the preview")
K.Options.Write("UnitFrames", "target.healthColor", "custom")
K.Options.Write("UnitFrames", "target.healthCustom", { r = 0.3, g = 0.6, b = 0.9 })
settle()
local last = W.LastCall(target.health, "SetStatusBarColor")
assert(last[1] == 0.3 and last[2] == 0.6 and last[3] == 0.9, "a custom colour shows in the preview")
K.Options.Write("UnitFrames", "target.castbarColor", "reaction")
settle()
local castColor = W.LastCall(preview.casts.target.bar, "SetStatusBarColor")
local hr, hg, hb = K.Theme.ReactionColor(2)
assert(castColor[1] == hr and castColor[2] == hg and castColor[3] == hb, "a reaction cast bar shows the hostile sample's colour")
K.Options.Write("UnitFrames", "target.castbarOrientation", "LEFT")
settle()
assert(W.LastCall(preview.casts.target.bar, "SetReverseFill")[1] == true, "the sample cast bar fills the chosen way")
K.Options.Write("UnitFrames", "target.castbar", false)
settle()
assert(not preview.casts.target.frame:IsShown(), "switching the cast bar off hides it in the preview")
assert(preview.auraCount == 0, "the target sample shows no auras while they are off")
K.Options.Write("UnitFrames", "target.auras", true)
settle()
assert(preview.auraCount > 0 and preview.auraIcons.target[1]:IsShown(), "switching target auras on shows sample aura icons")
local bevels = 0
for _, region in ipairs(W.Regions(preview.auraIcons.target[1], "Texture")) do
	local set = W.LastCall(region, "SetTexture")
	if set and set[1] == (K.Tokens.Texture("lumenRimSmall")) then
		bevels = bevels + 1
	end
end
assert(bevels == 9, "the sample aura icons wear the live aura tile: the socket's nine-piece rim")
K.Options.Write("UnitFrames", "target.auraPosition", "RIGHT")
K.Options.Write("UnitFrames", "target.auraGrowth", "LEFT_DOWN")
settle()
local sampleHost = preview.auraHosts.target
local hp, hrel, hrp = sampleHost:GetPoint(1)
assert(hp == "TOPLEFT" and hrel == preview.holders.target and hrp == "TOPRIGHT", "the sample aura row sits right of the frame, as live")
for i, icon in ipairs(preview.auraIcons.target) do
	if icon:IsShown() then
		local ip, irel = icon:GetPoint(1)
		assert(irel == sampleHost and ip == "TOPRIGHT", "sample icon " .. i .. " grows from the row's right corner, inside the row")
	end
end
K.Options.Write("UnitFrames", "edit", "boss")
settle()
assert(preview.kind == "boss" and U.Shown(env, preview.views.boss.levelText) == "??", "the boss sample shows a skull level")
local liveBoss = uf.Frames.Get("boss").views[1].geometry.portrait.h
local _, sampleBoss = preview.holders.boss:GetSize()
assert(math.abs(sampleBoss - liveBoss) <= 2, "the boss sample is one live boss frame tall: " .. sampleBoss .. ", live " .. liveBoss)

-- The Lumen preview: the vitals line with its sample values and cast line, the sigil with its level line and its
-- sockets centred under it, and the boss card with its section cap.
K.Options.Write("UnitFrames", "player.style", "lumen")
K.Options.Write("UnitFrames", "edit", "player")
settle()
local vitals = preview.views.player
assert(vitals.geometry.form == "vitals", "the preview draws the vitals line")
assert(U.Shown(env, vitals.healthText) == "3120" and U.Shown(env, vitals.healthSub) == "/ 3980", "current, then the max: " .. U.Shown(env, vitals.healthText) .. " " .. U.Shown(env, vitals.healthSub))
assert(U.Shown(env, vitals.levelText) == "60" and vitals.disc:IsShown(), "the level in its disc")
assert(U.Shown(env, vitals.caption) == K.L["Battle Stance"], "a sample stance follows the name")
local line = preview.casts.player
assert(line and line.frame:IsShown() and line.line and U.Shown(env, line.label) == K.L["Casting"], "the sample cast is the vitals line's own cast line")
assert(line.frame:GetParent() == preview.holders.player, "inside the sample frame")
K.Options.Write("UnitFrames", "target.style", "lumen")
K.Options.Write("UnitFrames", "target.castbar", true)
K.Options.Write("UnitFrames", "edit", "target")
settle()
local sigil = preview.views.target
assert(sigil.geometry.form == "sigil" and U.Shown(env, sigil.caption) == "Level 61 elite \194\183 Beast", "the sigil sample with its level line: " .. U.Shown(env, sigil.caption))
K.Options.Write("UnitFrames", "target.auraPosition", "CENTER")
settle()
local cp, crel, crp = preview.auraHosts.target:GetPoint(1)
assert(cp == "TOP" and crel == preview.holders.target and crp == "BOTTOM", "the sample sockets hang centred under the sigil")
local first = preview.auraIcons.target[1]
local fp, frel, frp, fx = first:GetPoint(1)
assert(frel == preview.auraHosts.target and fp == "TOPLEFT" and frp == "TOP" and fx < 0, "the sample row is centred on the host's top")
K.Options.Write("UnitFrames", "boss.style", "lumen")
K.Options.Write("UnitFrames", "edit", "boss")
settle()
local card = preview.views.boss
assert(card.geometry.form == "card" and U.Shown(env, card.capLabel) == K.L["Boss"] and U.Shown(env, card.caption) == K.L["Boss"], "the boss sample is a card with its section cap")

assert(uf.Frames.Get("player"), "the live frames exist alongside the preview")
assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "KstyleUI caught no errors")
print("unitframes preview ok")
