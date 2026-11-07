-- test-unitframes-preview.lua: the settings window shows the unit frames page, one frame's rows at a time, and a live preview of the frame being customised.
local U = dofile("Tools/regression/unitframes_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = U.W

local env, K, ns = O.New({
	setup = U.Install,
	saved = { version = 2, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {} },
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
assert(view.geometry.glass.x < view.geometry.portrait.x + view.geometry.portrait.w, "the sample's glass runs under its portrait")
assert(view.portraitChrome.inner[1]:IsShown() and not view.ring:IsShown(), "the sample portrait is the kit's chamfered octagon")
assert(env._unmasked[view.portrait] == true, "the sample asks for the square portrait the chamfer masks")
assert(view.badgeChrome.inner[1]:IsShown() and not view.badgeRing:IsShown(), "the sample's level badge is a chamfered square")
local cast = preview.casts.player
assert(cast and cast.frame:IsShown() and U.Shown(env, cast.text) == "FROSTBOLT", "the player sample shows a cast bar under the frame, its spell in capitals")
assert(cast.geometry and cast.geometry.icon and cast.geometry.panel.x > cast.geometry.icon.x + cast.geometry.icon.w, "the sample cast bar has its icon in its own square")
K.Options.Write("UnitFrames", "player.portraitShape", "round")
settle()
assert(view.ring:IsShown() and not view.portraitChrome.inner[1]:IsShown(), "a round portrait shows in the preview")
assert(view.badgeRing:IsShown() and not view.badgeChrome.inner[1]:IsShown(), "with its round badge")
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
	if set and set[1] == (K.Tokens.Texture("bevelTileInner")) then
		bevels = bevels + 1
	end
end
assert(bevels == 4, "the sample aura icons wear the live aura tile")
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

assert(uf.Frames.Get("player"), "the live frames exist alongside the preview")
assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "KstyleUI caught no errors")
print("unitframes preview ok")
