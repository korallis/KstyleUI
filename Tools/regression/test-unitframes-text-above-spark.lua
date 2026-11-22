-- test-unitframes-text-above-spark.lua: the health hit spark stays a frame level under the unit's text, so "2.7K / 3.3K" reads above it.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New()
local checked = 0
for _, style in ipairs({ "medallions" }) do
	env.RunTimers()
	for _, kind in ipairs({ "player", "target", "focus" }) do
		for _, view in ipairs(ns.Frames.Get(kind).views) do
			local spark = view.health and view.health.sparkFrame
			if spark and view.top then
				view.health:Show()
				checked = checked + 1
				assert(spark:GetFrameLevel() < view.top:GetFrameLevel(), style .. " " .. kind .. ": the health spark (level " .. spark:GetFrameLevel()
					.. ") must sit under the text layer (level " .. view.top:GetFrameLevel() .. "); keep UnitBar's SyncLevels spark offset below Style's LEVEL_TEXT")
			end
		end
	end
end
assert(checked >= 3, "the player, target and focus health bars were checked, got " .. checked)
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors")
print("ok")
