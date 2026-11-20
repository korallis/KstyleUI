-- test-combattext-parity.lua: direction, independent shadow and optional combat messages preserve legacy defaults and apply through real events without inspecting secret amounts.
local CT = dofile("Tools/regression/combattext_env.lua")
local env, K, ns = CT.New({ saved = CT.Saved({ enabled = true, outline = "NONE" }) })
CT.Enable(env, K)
local cfg = ns.Module.cfg
assert(cfg.direction == "up" and cfg.shadow and not cfg.combat, "v0.2.8 keeps upward motion, its outline's shadow and no combat messages")
env.FireEvent("PLAYER_REGEN_DISABLED")
assert(#CT.Shown(ns) == 0, "combat messages start off")
assert(ns.Module.stats.events == 0, "disabled combat messages do no emission or statistics work")
for _, direction in ipairs({ "up", "down" }) do
 K.Options.Write("CombatText", "direction", direction)
 CT.Hit(env, "player", "WOUND", "", env.Secret(1234), env.Secret(4))
 local number = CT.Shown(ns)[1]
 local motion = CT.Anim(number, "move")
 assert(number.frame._points[1][3] == (direction == "up" and "BOTTOM" or "TOP"), "the field starts at the matching edge so numbers travel inside it")
 assert(direction == "up" and motion.offsetY > 0 or direction == "down" and motion.offsetY < 0, "scroll direction applies to secret hits")
 CT.Finish(number)
end
for _, shadow in ipairs({ "show", "hide", "style" }) do
 K.Options.Write("CombatText", "shadow", shadow)
 CT.Hit(env, "player", "HEAL", "", env.Secret(100), 1)
 local number = CT.Shown(ns)[1]
 local x, y = CT.LastCall(number.text, "SetShadowOffset")
 assert(shadow == "hide" and x == 0 and y == 0 or shadow ~= "hide" and (x ~= 0 or y ~= 0), "the shadow choice applies")
 CT.Finish(number)
end
K.Options.Write("CombatText", "combatColor", { r = 0.3, g = 0.5, b = 0.7 })
K.Options.Write("CombatText", "combat", true)
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
 env.FireEvent(event)
 local number = CT.Shown(ns)[1]
 assert(CT.Text(env, number) == (event == "PLAYER_REGEN_DISABLED" and "Entering combat" or "Leaving combat"), "combat event emits the right localized message")
 local r, g, b = CT.LastCall(number.text, "SetTextColor")
 assert(r == 0.3 and g == 0.5 and b == 0.7, "combat message colour applies")
 CT.Finish(number)
end
K.Modules.Disable("CombatText"); env.FireEvent("PLAYER_REGEN_DISABLED")
assert(#CT.Shown(ns) == 0 and #env._errors == 0, "disabled combat text remains free of events and errors")
print("combat text parity ok")
