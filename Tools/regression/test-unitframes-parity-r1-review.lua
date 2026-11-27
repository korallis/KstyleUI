-- test-unitframes-parity-r1-review.lua: the PR #597 review's probes, enabled: secret health colour, boss highlights, tooltip transitions, PvP filters, low-health and cast opacity, missing APIs, combat strata, preview shield and PvP, and repeated event work.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local env, K, ns = U.New()
local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end
local function plain(value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end
local function row(key)
	for _, spec in ipairs(ns.Settings.Schema()) do
		if spec.key == key then return spec end
	end
	error("no Options row " .. key)
end

-- 1. The game forbids testing a secret: decide By health left from the curve API, never from a returned channel.
local unitSource = read("KstyleUI_UnitFrames/Unit.lua")
assert(not unitSource:find("r ~= nil", 1, true) and not unitSource:find("if not r then", 1, true),
	"Unit.lua tests a UnitHealthPercent channel; branch on curve availability before reading the channels")

local p = ns.Frames.Get("player").views[1]
local t = ns.Frames.Get("target").views[1]
env._units.player.faction = "Alliance"
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, power = 30, powerMax = 100, reaction = 2,
	canAttack = true, classification = "elite", pvp = true, faction = "Alliance", isPlayer = true, ffa = true })

-- 4. Tooltips follow combat and the setting while the frame stays hovered.
write("unitTooltip", "noCombat")
W.Enter(p.button)
assert(env._tooltip == "player", "out of combat the hovered frame shows its tooltip")
env.SetCombat(true)
assert(env._tooltip == nil, "starting combat hides the hovered frame's tooltip")
env.SetCombat(false)
assert(env._tooltip == "player", "ending combat shows it again")
write("unitTooltip", "never")
assert(env._tooltip == nil, "switching to Never closes the open tooltip")
write("unitTooltip", "always")
assert(env._tooltip == "player", "switching back to Always reopens it")
W.Leave(p.button)
assert(env._tooltip == nil, "leaving hides it")

-- 5. Other faction only also filters a same-faction free-for-all player.
write("target.pvpEnemyOnly", true)
assert(not t.icons.pvp:IsShown(), "a same-faction free-for-all player shows no badge under Other faction only")
env._units.target.faction = "Horde"
env.FireEvent("UNIT_FACTION", "target")
assert(t.icons.pvp:IsShown(), "an other-faction free-for-all player still shows it")
env._units.target.faction, env._units.target.ffa = "Alliance", nil
write("target.pvpEnemyOnly", false)

-- 3. By health left: the live bar, the preview and the Options agree on the gradient.
write("target.healthColor", "health")
write("target.healthGradient", "HORIZONTAL")
assert(env.issecretvalue(t.health.colorRGBA[1]), "By health left paints the curve's secret channels")
assert(not t.gradient, "a secret colour cannot be shaded")
write("edit", "target")
local pane = ns.Preview.Build(env.UIParent)
pane:Refresh()
local sample = pane.views.target
assert(not sample.gradient, "the preview shows the same flat fill as the live bar")
assert(row("target.healthGradient").showWhen(K.Store.Module("UnitFrames")) == false, "Options hide Fill gradient under By health left")
write("target.healthColor", "hud")
assert(row("target.healthGradient").showWhen(K.Store.Module("UnitFrames")) == true, "and show it for the other colours")
write("target.healthGradient", "")

-- 8. The preview shows absorb shields and a PvP badge, and applies the PvP filters.
write("target.absorbAlpha", 0.55)
pane:Refresh()
assert(sample.absorb:IsShown(), "the preview shows a shield for absorb opacity")
assert(math.abs(W.LastCall(sample.absorb, "SetStatusBarColor")[4] - 0.55) < 1e-6, "at the chosen opacity")
write("target.absorbs", false)
pane:Refresh()
assert(not sample.absorb:IsShown(), "absorbs off hides the preview shield")
write("target.absorbs", true)
pane:Refresh()
assert(sample.icons.pvp:IsShown(), "the target sample shows a PvP badge")
write("target.pvpEnemyOnly", true)
pane:Refresh()
assert(sample.icons.pvp:IsShown(), "the sample is of the other faction, so Other faction only keeps it")
write("target.pvpPlayersOnly", true)
pane:Refresh()
assert(not sample.icons.pvp:IsShown(), "the sample is an NPC, so Players only hides it")
write("target.pvpPlayersOnly", false)
write("target.pvpEnemyOnly", false)
write("edit", "player")

-- 3. The low-health overlay stays off when it would cover the chosen fill.
write("player.healthAlpha", 0.1)
env._units.player.health = 1000
env.FireEvent("UNIT_HEALTH", "player")
assert(plain(W.LastCall(p.health.lowFill, "SetAlpha")[1]) == 0, "a see-through fill is not covered by the low-health red")
write("player.healthAlpha", 1)
write("player.healthColor", "health")
assert(plain(W.LastCall(p.health.lowFill, "SetAlpha")[1]) == 0, "By health left is not covered by the low-health red")
write("player.healthColor", "hud")
env.FireEvent("UNIT_HEALTH", "player")
assert(plain(W.LastCall(p.health.lowFill, "SetAlpha")[1]) > 0, "the default friendly bar keeps its low-health red")
env._units.player.health = env._units.player.healthMax

-- 7. Missing APIs take the safe path.
write("focus.targetBorder", true)
U.SetUnit(env, "focus", env._units.target)
local focus = ns.Frames.Get("focus").views[1]
local orig = env.UnitIsUnit
env.UnitIsUnit = nil
local ok, err = pcall(ns.Frames.Edge, focus)
env.UnitIsUnit = orig
assert(ok, "a missing UnitIsUnit shows no target highlight: " .. tostring(err))
write("target.pvpPlayersOnly", true)
orig = env.UnitIsPlayer
env.UnitIsPlayer = nil
ok, err = pcall(ns.Indicators.PvP, t, "target")
env.UnitIsPlayer = orig
assert(ok and not t.icons.pvp:IsShown(), "a missing UnitIsPlayer hides the badge under Players only: " .. tostring(err))
write("target.pvpPlayersOnly", false)
U.SetUnit(env, "pet", { name = "Wolf", level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
env.C_PetInfo = { GetPetHappiness = function() return 3 end }
env.HasPetUI = nil
write("pet.happiness", "always")
local pet = ns.Frames.Get("pet").views[1]
assert(not (pet.extraIcon and pet.extraIcon:IsShown()), "unknown hunter status shows no happiness badge")
write("pet.happiness", "unhappy")

-- 6. Cast fill opacity survives a failed cast on the Medallions player cast bar.
write("player.castbarAlpha", 0.35)
local cb = ns.CastBars.Inline("player")[1]
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-1", 116)
assert(cb.error and math.abs(W.LastCall(cb.bar, "SetStatusBarColor")[4] - 0.35) < 1e-6, "a failed cast keeps the fill opacity")
write("player.castbarAlpha", 1)
-- On Frames Icon on the right is offered only where the icon can show.
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
local store = K.Store.Module("UnitFrames")
write("boss.castbarIcon", true)
write("edit", "boss")
assert(row("boss.castbarIconRight").showWhen(store) == false, "the boss's lined cast bar never shows its icon, so the row hides")
write("edit", "player")
assert(row("player.castbarIconRight").showWhen(store) == true, "the player's cast bar shows its icon, so the row shows")
write("boss.castbarIcon", false)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()

-- 9. Repeated event work.
local atlasCalls = 0
env.C_Texture = { GetAtlasInfo = function()
	atlasCalls = atlasCalls + 1
	return { leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
end }
write("player.portraitStyle", "class")
atlasCalls = 0
env.FireEvent("UNIT_PORTRAIT_UPDATE", "player")
assert(atlasCalls == 0, "class art reads its atlas only for mirror or zoom")
write("player.portraitStyle", "portrait")
env.FireEvent("PLAYER_TARGET_CHANGED")
local edge = assert(focus.edge, "the focus is outlined while it is the target")
local shows, colours = #W.Calls(edge, "Show"), #W.Calls(edge.line[1], "SetVertexColor")
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(#W.Calls(edge, "Show") == shows and #W.Calls(edge.line[1], "SetVertexColor") == colours, "an unchanged highlight is not shown or repainted again")
local uhp, shareCalls = env.UnitHealthPercent, 0
env.UnitHealthPercent = function(unit, predicted, curve)
	if curve and curve.points and #curve.points == 3 and curve.points[2][1] == 0.5 then shareCalls = shareCalls + 1 end
	return uhp(unit, predicted, curve)
end
write("target.healthColor", "health")
shareCalls = 0
env.FireEvent("UNIT_FACTION", "target")
env.UnitHealthPercent = uhp
assert(shareCalls == 3, "one faction change evaluates the three colour curves once, not " .. shareCalls)
write("target.healthColor", "hud")
write("target.elite", true)
local atlases = #W.Calls(t.extraIcon, "SetAtlas")
env.FireEvent("GROUP_ROSTER_UPDATE")
assert(#W.Calls(t.extraIcon, "SetAtlas") == atlases, "an unchanged elite badge is not set again")

-- 7. A secret frame level and combat lockdown.
write("player.hoverBorder", true)
local level = p.top.GetFrameLevel
p.top.GetFrameLevel = function() return env.Secret(5) end
p.hovered = true
ok, err = pcall(ns.Frames.Edge, p)
p.top.GetFrameLevel, p.hovered = level, false
assert(ok, "a secret frame level makes no arithmetic: " .. tostring(err))
write("player.hoverBorder", false)
cb.frame:SetFrameStrata("MEDIUM")
env.SetCombat(true)
write("castbarRaise", true)
assert(cb.frame:GetFrameStrata() == "MEDIUM", "the protected strata change waits for combat's end")
env.SetCombat(false)
env.RunTimers()
assert(cb.frame:GetFrameStrata() == "HIGH", "and applies after it")
write("castbarRaise", false)

-- 2. Boss highlights use the visible chip or card.
U.SetUnit(env, "boss1", env._units.target)
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
write("boss.targetBorder", true)
env.FireEvent("PLAYER_TARGET_CHANGED")
local boss = ns.Frames.Get("boss").views[1]
assert(boss.chip:IsShown() and boss.edge and boss.edge:IsShown(), "a targeted boss shows its chip and highlight")
local frame = boss.edge
while frame do
	assert(frame:GetAlpha() > 0, "no ancestor of the targeted boss's highlight is faded out")
	frame = frame:GetParent()
end
assert(W.LastCall(boss.edge, "SetAllPoints")[1] == boss.chip, "the highlight outlines the Targeted chip")
U.SetUnit(env, "boss2", { name = "second", level = 62, health = 600, healthMax = 800, reaction = 2 })
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
write("boss.hoverBorder", true)
local idle = ns.Frames.Get("boss").views[2]
W.Enter(idle.button)
assert(W.LastCall(idle.edge, "SetAllPoints")[1] == idle.panel, "an idle boss's hover outline follows the painted card, not the click area")
W.Leave(idle.button)

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-unitframes-parity-r1-review: ok")
