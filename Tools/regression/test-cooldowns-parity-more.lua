-- test-cooldowns-parity-more.lua: artwork crop applies in all four groups on both paths, restores defaults, and survives combat.
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
	assert(#env._errors == 0 and K.ErrorCount() == 0, path .. " has no errors")
end
print("more cooldown parity ok")
