-- test-combattext-safe-lane.lua: Medallions player text starts above the cast stack and target text stays above the 60-unit debuff lane, including its fall and pop.
local CT = dofile("Tools/regression/combattext_env.lua")
local env, K, ns = CT.New()
K.Options.Write("HudStyle", "style", "medallions")
local target
K.Modules.Register(CT.CoreEnv.Module("UnitFrames", { onEnable = function()
	local _, buttons = CT.UnitHolder(env, K, "unitframes.target", "UnitFrames", { "target" })
	target = buttons[1]
end }))
K.Modules.Enable("UnitFrames")
CT.Enable(env, K)
local class = K.Scale.AspectClass(1920, 1080)
local layouts = K.Setup.Layouts
local field = layouts.Aspect(class, "medallions", "DPS", "combattext.player") or layouts.Style("medallions", "DPS", "combattext.player")
local cast = layouts.Aspect(class, "medallions", "DPS", "unitframes.castbar.target") or layouts.Style("medallions", "DPS", "unitframes.castbar.target")
assert(field and field.y == cast.y + cast.height + 12, "H10: the player lane starts 12 units above the cast stack")
assert(field.x == 0 and field.height == 80, "the default field clears the 16:9 pet stack and keeps room for the full 40-unit rise")
for _, style in ipairs({ "rise", "arc", "pop" }) do
	K.Options.Write("CombatText", "style", style)
	CT.Hit(env, "target", "WOUND", "CRITICAL", env.Secret(120), 1)
	local numbers = CT.On(ns, target)
	local number = numbers[#numbers]
	local _, _, point, _, y = number.frame:GetPoint(1)
	local scale = number.frame:GetScale()
	local move, fall, pop = CT.Anim(number, "move"), CT.Anim(number, "fall"), CT.Anim(number, "pop")
	local half = ns.Module.cfg.size * scale * math.max(1, pop.scaleFrom) / 2
	local low = y * scale + math.min(0, (move.offsetY + fall.offsetY) * scale) - half
	assert(point == "TOP" and low >= 60, "H10: " .. style .. " must clear the target's 60-unit debuff lane, bottom " .. low)
end
K.Options.Write("CombatText", "clearLanes", false)
CT.Hit(env, "target", "WOUND", "", 20, 1)
local old = CT.On(ns, target)
assert(select(3, old[#old].frame:GetPoint(1)) == "CENTER", "off restores the original target anchor")
assert(layouts.Style("medallions", "DPS", "combattext.player") == nil, "off restores the original inherited player-field position")
local previous = layouts.Place("DPS", "frames", class, "combattext.player")
local actual = K.Layout.Get("combattext.player")
assert(actual.anchor == previous.anchor and actual.x == previous.x and actual.y == previous.y, "off moves the actual player field back to its previous place")
K.Options.Write("HudStyle", "style", "frames")
CT.Hit(env, "target", "WOUND", "", 20, 1)
local numbers = CT.On(ns, target)
local _, _, point = numbers[#numbers].frame:GetPoint(1)
assert(point == "CENTER", "Frames keeps its existing text anchor")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("combattext safe lane ok")
