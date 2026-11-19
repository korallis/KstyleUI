-- test-actionbars-drag.lua: mouse pickup never activates a spell; binding timing still follows the game's CVar.
local AB = dofile("Tools/regression/actionbars_env.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local env, K, ns = AB.New({ width = screen[1], height = screen[2], class = "DRUID", setup = function(e)
			e._game.forms = { { texture = 132276, spellID = 768 } }
			e._game.petExists = true
			e._game.pet[1] = { name = "Attack", texture = 132152 }
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end })
		K.Options.Write("HudStyle", "style", style)
		AB.Enable(env, K)
		for _, key in ipairs({ "bar1", "bar3", "pet", "stance" }) do
			local b = AB.Button(ns, key, 1)
			if b.kind == "action" then AB.Slot(env, b.slot, { type = "spell", id = 768, texture = 132276 }) end
			for _, mouse in ipairs({ "LeftButton", "RightButton" }) do
				local used = #env._game.used
				AB.Click(env, b, mouse, true)
				assert(#env._game.used == used, style .. " " .. key .. ": mouse down before a drag must not cast")
				local drag = b:GetScript("OnDragStart")
				assert(drag, key .. ": the spell can be picked up")
				drag(b)
				assert(#env._game.used == used, key .. ": pickup must not cast")
			end
		end
		assert(AB.PressKey(env, "1") and AB.Used(env) == 1, "binding still casts")
		assert(#env._blocked == 0 and #env._errors == 0, AB.Errors(env))
	end
end
print("action bar dragging never casts at all four screen sizes in Frames, Orbs and Medallions")
