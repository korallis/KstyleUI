-- test-cooldowns-parity-more.lua: artwork crop in all four groups and the cooldown edge switch apply on both paths, restore defaults, and survive combat.
local C = dofile("Tools/regression/cooldowns_env.lua")
for _, path in ipairs({ "mirror", "reskin" }) do
	local env, K, ns = C.New({ saved = { version = 42, profiles = { Default = { Cooldowns = { enabled = true, path = path } } }, characters = {} }, setup = C.Game })
	env.RunTimers()
	for group, viewer in pairs({ essential = "EssentialCooldownViewer", utility = "UtilityCooldownViewer", buffs = "BuffIconCooldownViewer", bars = "BuffBarCooldownViewer" }) do
		local texture
		if path == "mirror" then
			local row = ns.Mirror.Row(group)
			texture = group == "bars" and row:Bar(1).icon or row:Icon(1).icon
		else
			local item = env._viewers[viewer]._items[1]
			texture = group == "bars" and item.Icon.Icon or item.Icon
		end
		local function crop(expected)
			local call = assert(C.W.LastCall(texture, "SetTexCoord"))
			assert(math.abs(call[1] - expected) < 0.00001 and math.abs(call[2] - (1 - expected)) < 0.00001, path .. " " .. group .. " crop expected " .. expected .. " got " .. tostring(call[1]))
		end
		assert(ns.Settings.current[group].iconZoom == 0.07, "v0.2.8 profile inherits the original crop")
		crop(0.07)
		K.Options.Write("Cooldowns", group .. ".iconZoom", 0.2); env.RunTimers()
		assert(K.Store.Module("Cooldowns")[group].iconZoom == 0.2, "zoom is saved")
		crop(0.2)
		K.Callbacks.Fire("ScaleChanged"); env.RunTimers(); crop(0.2)
		K.Options.Write("Cooldowns", group .. ".iconZoom", 0); env.RunTimers(); crop(0)
		K.Options.Write("Cooldowns", group .. ".iconZoom", 0.07); env.RunTimers(); crop(0.07)
		env.SetCombat(true)
		K.Options.Write("Cooldowns", group .. ".iconZoom", 0.2); env.RunTimers()
		env.SetCombat(false); env.RunTimers(); crop(0.2)
		K.Options.Write("Cooldowns", group .. ".iconZoom", 0.07); env.RunTimers()
	end
	for group, viewer in pairs({ essential = "EssentialCooldownViewer", utility = "UtilityCooldownViewer" }) do
		local icon = path == "mirror" and ns.Mirror.Row(group):Icon(1)
		local cooldown = icon and icon.cooldown or env._viewers[viewer]._items[1].Cooldown
		local function edge(expected, what)
			if icon then icon.onCooldown = true; icon:Paint() else cooldown:SetDrawEdge(true) end
			assert(C.W.LastCall(cooldown, "SetDrawEdge")[1] == expected, path .. " " .. group .. ": " .. what)
		end
		assert(ns.Settings.current[group].edge == true, "v0.2.8 profile keeps the cooldown edge")
		edge(true, "the edge shows by default")
		K.Options.Write("Cooldowns", group .. ".edge", false); env.RunTimers()
		assert(K.Store.Module("Cooldowns")[group].edge == false, "the edge choice is saved")
		assert(C.W.LastCall(cooldown, "SetDrawEdge")[1] == false, path .. " " .. group .. " hides the edge at once")
		edge(false, "a later paint or native call keeps the edge hidden")
		env.SetCombat(true)
		K.Options.Write("Cooldowns", group .. ".edge", true); env.RunTimers()
		env.SetCombat(false); env.RunTimers()
		edge(true, "the edge returns")
		if icon then icon.onCooldown = nil; icon:Paint() end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, path .. " has no errors")
end
print("more cooldown parity ok")
