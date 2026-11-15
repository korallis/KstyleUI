-- test-unitframes-medallions.lua: under the Medallions HUD style every unit frame is a slab, the player, target, focus, pet and boss frames carry a medallion on their outer end with a class or reaction ring and a level plaque, target of target and focus target are mini slabs, the resolver picks painted art only from plain identity strings, and the flip-in, low-health ring and sheen run as engine animations; Frames comes back untouched.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New()
local Settings, Frames, Medallions = ns.Settings, ns.Frames, K.Medallions

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 0.02)
end

local BUST, BADGE = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Bust_Dwarf_SHAMAN_2.png", "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Badge_Dwarf_SHAMAN_2.png"
local CREST = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Crest_Dwarf_SHAMAN.png"
K.MedallionAssets = {
	portraits = { Dwarf = { SHAMAN = { [2] = { bust = BUST, badge = BADGE } } } },
	crests = { Dwarf = { SHAMAN = { crest = CREST, glow = CREST .. "g", metal = CREST .. "m" } } },
}

local player = env._units.player
player.class, player.race, player.sex = "SHAMAN", "Dwarf", 2
U.SetUnit(env, "target", { name = "Galestrider", level = 6, health = 1206, healthMax = 1698, reaction = 2, canAttack = true, creature = "Beast" })
U.SetUnit(env, "focus", { name = "Bandit Highwayman", level = 9, health = 48, healthMax = 100, reaction = 2 })
U.SetUnit(env, "pet", { name = "Galewing", level = 6, health = 100, healthMax = 100, reaction = 5 })
U.SetUnit(env, "targettarget", { name = "Tester", class = "SHAMAN", isPlayer = true, health = 62, healthMax = 100, reaction = 5 })

do
	local texture = env.CreateFrame("Frame"):CreateTexture()
	assert(Medallions.Portrait(texture, "player", "badge") == true, "plain identity picks the painted badge")
	assert(texture:GetTexture() == BADGE and env._portraits[texture] == nil, "the badge path, and no engine portrait")
	assert(select(1, Medallions.Crest("player")) == CREST, "the crest for the player's race and class")
	player.secretIdentity = true
	local engine = env.CreateFrame("Frame"):CreateTexture()
	assert(Medallions.Portrait(engine, "player", "bust") == false, "a restricted identity never reaches the art table")
	assert(env._portraits[engine] == "player", "it falls back to the engine portrait")
	assert(Medallions.Identity("player") == nil and Medallions.Crest("player") == nil, "no identity and no crest while secret")
	player.secretIdentity = nil
	assert(Medallions.Portrait(engine, "target", "bust") == false and env._portraits[engine] == "target", "an NPC has no race, so the engine draws it")
	player.sex = 3
	assert(Medallions.PortraitPath("player", "bust") == nil, "a combination without art falls back")
	player.sex = 2
	noErrors("resolver")
end

env.SetTarget(true)
local frames = {}
for _, kind in ipairs(Settings.KINDS) do
	frames[kind] = Frames.Get(kind)
end
assert(frames.player.views[1].form ~= "slab", "Frames has no slabs")

K.Options.Write("HudStyle", "style", "medallions")
assert(K.HudStyle.Current() == "medallions", "the style switched")
noErrors("switch")

for _, kind in ipairs(Settings.KINDS) do
	assert(Settings.Form(kind) == "slab", kind .. " is a slab under Medallions, got " .. tostring(Settings.Form(kind)))
end

local view = frames.player.views[1]
assert(view.form == "slab" and view.geometry.form == "slab", "the player is laid out as a slab")
assert(view.slab and view.slab.fill:IsShown(), "the slab fill shows")
assert(view.geometry.chrome == false, "the glass chrome is off")
local m = view.medallion
assert(m and m:IsShown(), "the player medallion shows")
local g = view.geometry
assert(g.medal.x < 0 and g.medal.x + g.medal.w / 2 > 0, "the medallion hangs off the slab's outer end, centred just inside it")
assert(g.medalSide == "LEFT" and not g.mirror, "player medallion on the left")
assert(g.health.x > g.medal.x + g.medal.w / 2, "the bar starts clear of the medallion")
assert(m.plaque:IsShown() and U.Shown(env, m.levelText) == "60", "the level plaque shows the level, got " .. tostring(U.Shown(env, m.levelText)))
assert(m.portrait:GetTexture() == BUST, "the player medallion shows the painted bust")
local cr, cg, cb = K.Theme.ClassColorForWidget("SHAMAN")
local er, eg, eb = m.enamel:GetVertexColor()
assert(near(er, cr) and near(eg, cg) and near(eb, cb), "the player's ring takes the class colour")
assert(not view.portraitFrame:IsShown() and not view.disc:IsShown(), "the old portrait and level disc stay hidden")
assert(m:GetScript("OnUpdate") == nil and view.parent:GetScript("OnUpdate") == nil, "no per-frame Lua on the medallion")
assert(m.sheenAnim:IsPlaying(), "the player portrait carries the sheen")

local target = frames.target.views[1]
local tm = target.medallion
assert(tm and tm:IsShown() and target.geometry.medalSide == "RIGHT" and target.geometry.mirror, "the target medallion sits on the right")
assert(target.geometry.medal.x + target.geometry.medal.w > target.geometry.glass.w, "it hangs off the slab's right end")
local hr, hg, hb = K.Tokens.Color("healthHostile")
er, eg, eb = tm.enamel:GetVertexColor()
assert(near(er, hr) and near(eg, hg) and near(eb, hb), "a hostile NPC's ring takes the hostile colour")
assert(env._portraits[tm.portrait] == "target", "an NPC target shows the engine portrait")
assert(U.Shown(env, target.caption) == "BEAST", "the target slab names the creature type in capitals, got " .. tostring(U.Shown(env, target.caption)))
assert(tm.sheenAnim:IsPlaying(), "the target portrait carries the sheen")

tm.flip:Stop()
U.SetUnit(env, "target", { name = "Thessaly", class = "PALADIN", race = "Scourge", sex = 3, isPlayer = true, level = 12, health = 402, healthMax = 437, reaction = 5 })
env.SetTarget(true)
assert(tm.flip:IsPlaying(), "a new target flips its medallion in")
local pr, pg, pb = K.Theme.ClassColorForWidget("PALADIN")
er, eg, eb = tm.enamel:GetVertexColor()
assert(near(er, pr) and near(eg, pg) and near(eb, pb), "a player target's ring takes its class colour")
assert(U.Shown(env, target.caption) == "PALADIN", "a player target's slab names the class")
noErrors("target")

for _, kind in ipairs({ "focus", "pet" }) do
	local each = frames[kind].views[1]
	assert(each.medallion and each.geometry.medal, kind .. " carries a medallion")
	assert(not each.medallion.sheenAnim:IsPlaying(), kind .. " has no sheen")
end
for _, kind in ipairs({ "targettarget", "focustarget" }) do
	local each = frames[kind].views[1]
	assert(each.geometry.form == "slab" and each.geometry.medal == nil, kind .. " is a mini slab without a medallion")
	assert(not (each.medallion and each.medallion:IsShown()), kind .. " shows no medallion")
end

player.health = 600
env.FireEvent("UNIT_HEALTH", "player")
assert(m.lowFrame:IsShown() and m.pulse:IsPlaying(), "low health shows the pulsing ring")
local alpha = U.W.LastCall(m.low, "SetAlpha")
assert(alpha and env.issecretvalue(alpha[1]) and near(env.Reveal(alpha[1]), 1), "the ring's alpha is the curve's secret, full below 40 percent")
player.health = 3900
env.FireEvent("UNIT_HEALTH", "player")
alpha = U.W.LastCall(m.low, "SetAlpha")
assert(near(env.Reveal(alpha[1]), 0), "above 40 percent the curve hides the ring")

player.dead, player.health = true, 0
env.FireEvent("UNIT_HEALTH", "player")
assert(U.W.LastCall(m.portrait, "SetDesaturated")[1] == true, "a dead unit's portrait greys")
assert(not m.lowFrame:IsShown(), "no low-health ring on the dead")
player.dead, player.health = nil, 3000
env.FireEvent("UNIT_HEALTH", "player")
assert(U.W.LastCall(m.portrait, "SetDesaturated")[1] == false, "the portrait regains colour")
er, eg, eb = m.enamel:GetVertexColor()
assert(near(er, cr) and near(eg, cg) and near(eb, cb), "the class ring returns")
noErrors("effects")

K.Options.Write("HudStyle", "style", "frames")
assert(view.form ~= "slab" and not m:IsShown() and not view.slab.fill:IsShown(), "Frames hides the slab and the medallion")
assert(not m.sheenAnim:IsPlaying() and not m.pulse:IsPlaying(), "the medallion's animations stop")
noErrors("back to Frames")
print("ok unitframes medallions")
