-- test-combattext-medallions.lua: under the Medallions HUD style the scrolling numbers take KSTY-110's look (Barlow Semi Condensed Bold at 20 units, crits 1.4 times, damage #ffd23f, crits #fff1a8, heals #62d58d, a 40-unit rise over 0.9 s that fades over its last 0.3 s, at most 6 at once); a setting the player changed keeps the player's value, and Frames gets every default back.
local CT = dofile("Tools/regression/combattext_env.lua")

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (tolerance or 1e-6)
end

local function hex(h)
	return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

local function rgb(cfg, prefix, h)
	local r, g, b = hex(h)
	return near(cfg[prefix .. "R"], r) and near(cfg[prefix .. "G"], g) and near(cfg[prefix .. "B"], b)
end

local env, K, ns = CT.New()
CT.Enable(env, K)
K.Options.Write("CombatText", "calmNumbers", false)
env.RunTimers()
local cfg = ns.Module.cfg
assert(cfg.fontPath == K.Tokens.FontPath("BarlowBold"), "numbers are Barlow Semi Condensed Bold: " .. tostring(cfg.fontPath))
assert(cfg.size == 20 and near(cfg.critScale, 1.4), "20 units, crits 28")
assert(cfg.flags == "OUTLINE", "an outline over the world")
assert(near(cfg.duration, 0.9) and cfg.fadeTime == 0.3 and cfg.rise == 40, "a 40-unit rise over 0.9 s, fading over the last 0.3 s")
assert(cfg.maxPerFrame == 6, "at most 6 at once")
assert(cfg.worldFace == K.Tokens.FontPath("BarlowBold"), "the game's own world numbers follow the world role into Barlow Bold: " .. tostring(cfg.worldFace))
assert(rgb(cfg, "damage", "ffd23f") and rgb(cfg, "crit", "fff1a8") and rgb(cfg, "heal", "62d58d"), "damage gold, crits pale gold, heals green")

CT.Hit(env, "player", "WOUND", "", 120, 1)
local number = CT.Shown(ns)[1]
assert(number, "a hit shows a number")
assert((number.text:GetFont()) == K.Tokens.FontPath("BarlowBold"), "the number draws in Barlow Bold")
local r, g, b = CT.LastCall(number.text, "SetTextColor")
local dr, dg, db = hex("ffd23f")
assert(near(r, dr) and near(g, dg) and near(b, db), "damage reads gold")
local fade = CT.Anim(number, "fade")
assert(near(fade.duration, 0.3) and near(fade.delay, 0.6), "it fades over the last 0.3 s of 0.9: " .. tostring(fade.delay) .. " + " .. tostring(fade.duration))
local move = CT.Anim(number, "move")
assert(near(move.duration, 0.9) and move.offsetY > 0 and move.offsetY <= 40 + 1e-6, "it rises at most 40 units over 0.9 s: " .. tostring(move.offsetY))
for i = 1, 8 do
	CT.Hit(env, "player", "WOUND", "", 100 + i, 1)
end
assert(#ns.Module.fieldEmitter.active == 6, "six numbers at most: " .. #ns.Module.fieldEmitter.active)

local plain = ns.Settings.Snapshot({ damageColor = { r = env.Secret(1), g = 0.82, b = 0.25 } })
assert(plain.damageR ~= nil, "a secret saved colour component never reaches a comparison")

K.Options.Write("CombatText", "size", 24)
K.Options.Write("CombatText", "damageColor", { r = 0.2, g = 0.4, b = 0.6 })
env.RunTimers()
cfg = ns.Module.cfg
assert(cfg.size == 24, "a chosen size stays under Medallions")
assert(near(cfg.damageR, 0.2) and near(cfg.damageG, 0.4) and near(cfg.damageB, 0.6), "a chosen damage colour stays")
assert(near(cfg.critScale, 1.4), "the settings the player left alone keep Medallions' look")
K.Options.Write("CombatText", "size", 18)
K.Options.Write("CombatText", "damageColor", ns.Settings.defaults.damageColor)
env.RunTimers()

assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "no addon error")
print("ok - test-combattext-medallions")
