-- test-actionbars-drag.lua: mouse pickup never activates a spell; binding timing still follows the game's CVar.
local AB = dofile("Tools/regression/actionbars_env.lua")

for _, style in ipairs({ "medallions" }) do
	local env, K, ns = AB.New({ width = 1920, height = 1080, class = "DRUID", setup = function(e)
		e._game.forms = { { texture = 132276, spellID = 768 } }
		e._game.petExists = true
		e._game.pet[1] = { name = "Attack", texture = 132152 }
		e._game.bindings.ACTIONBUTTON1 = { "1" }
	end })
	K.Options.Write("ActionBars", "bar3.enabled", true)
	AB.Enable(env, K)
	local stance = AB.Button(ns, "stance", 1)
	assert(not stance:GetScript("OnDragStart") and not stance:GetScript("OnReceiveDrag"), "stance buttons remain non-draggable")
	env._game.modified = true
	for _, key in ipairs({ "bar1", "bar3", "pet" }) do
		local b = AB.Button(ns, key, 1)
		for _, mouse in ipairs({ "LeftButton", "RightButton" }) do
			env.ClearCursor()
			if b.kind == "action" then AB.Slot(env, b.slot, { type = "spell", id = 768, texture = 132276 }) end
			local used = #env._game.used
			AB.Click(env, b, mouse, true)
			assert(#env._game.used == used, style .. " " .. key .. ": mouse down before a drag must not cast")
			local drag = b:GetScript("OnDragStart")
			assert(drag, key .. ": the spell can be picked up")
			drag(b)
			assert(#env._game.used == used, key .. ": pickup must not cast")
			assert(env.GetCursorInfo(), key .. ": pickup must put the spell on the cursor")
			if b.kind == "action" then
				local target = AB.Button(ns, "bar1", 2)
				target:GetScript("OnReceiveDrag")(target)
				assert(env._game.slots[2].id == 768 and #env._game.used == used, "dropping on another button must place without casting")
			end
		end
		env.ClearCursor()
		if b.kind == "action" then AB.Slot(env, b.slot, { type = "spell", id = 768, texture = 132276 }) end
		local used = #env._game.used
		AB.Click(env, b, "LeftButton", true)
		AB.Click(env, b, "LeftButton", false)
		assert(#env._game.used == used + 1, key .. ": an ordinary click still acts once, on release")
	end
	for _, keyDown in ipairs({ true, false }) do
		env._game.useKeyDown = keyDown
		local used = #env._game.used
		assert(AB.PressKey(env, "1", true))
		assert(#env._game.used == used + (keyDown and 1 or 0), "key down follows ActionButtonUseKeyDown")
		assert(AB.PressKey(env, "1", false))
		assert(#env._game.used == used + 1, "a full key press casts exactly once")
	end
	env._game.useKeyDown = true
	local main = AB.Button(ns, "bar1", 1)
	local used, picked = #env._game.used, #env._game.picked
	env._game.modified = false
	main:GetScript("OnDragStart")(main)
	assert(#env._game.picked == picked, "locked bars still require the pickup modifier")
	env.SetCombat(true)
	for _, key in ipairs({ "bar1", "bar3", "pet" }) do
		local button = AB.Button(ns, key, 1)
		button:GetScript("OnDragStart")(button)
		button:GetScript("OnReceiveDrag")(button)
	end
	assert(#env._game.picked == picked and not env.GetCursorInfo(), "combat refuses action and pet pickup")
	AB.Click(env, main, "LeftButton", true)
	assert(#env._game.used == used, "mouse down remains safe in combat")
	AB.Click(env, main, "LeftButton", false)
	assert(#env._game.used == used + 1, "mouse release still works in combat")
	K.Options.Write("ActionBars", "safeDragging", false)
	assert(main:GetAttribute("safeDragging"), "changing the option in combat defers protected work")
	env.SetCombat(false)
	env.RunTimers()
	used = #env._game.used
	AB.Click(env, main, "LeftButton", true)
	assert(#env._game.used == used + 1, "opting out restores mouse-down casting")
	AB.Click(env, main, "LeftButton", false)
	assert(#env._game.used == used + 1, "opting out does not double cast")
	K.Options.Write("ActionBars", "safeDragging", true)
	env.RunTimers()
	AB.Click(env, main, "LeftButton", true)
	assert(#env._game.used == used + 1, "reenabling safe dragging restores release timing")
	assert(#env._blocked == 0 and #env._errors == 0, AB.Errors(env))
end
print("action bar dragging never casts in Frames, Orbs and Medallions (1920x1080)")
