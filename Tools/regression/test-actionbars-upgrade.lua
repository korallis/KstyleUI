-- test-actionbars-upgrade.lua: released profiles and extra-bars snapshots acquire new per-bar defaults on restore.
local AB = dofile("Tools/regression/actionbars_env.lua")
local env, K = AB.New({})
AB.Enable(env, K)
K.Options.Write("ActionBars", "extraBarsLayout", "rows")
env.RunTimers(); AB.W.Settle(env)
local saved = AB.CoreEnv.DeepCopy(env.KstyleUIDB)
local settings = saved.profiles.Default.ActionBars
local fields = { "placement", "swipeOpacity", "desaturateCooldown", "rarityBorder", "moverOptions" }
for _, bar in pairs(settings) do
	if type(bar) == "table" then for _, field in ipairs(fields) do bar[field] = nil end end
end
for _, snapshot in pairs(settings.extraBarsPrevious) do
	for _, field in ipairs(fields) do snapshot.settings[field] = nil end
end
local reload, RK, ns = AB.New({ saved = saved })
AB.Enable(reload, RK)
RK.Options.Write("ActionBars", "extraBarsLayout", "off")
reload.RunTimers(); AB.W.Settle(reload)
assert(#reload._errors == 0 and RK.ErrorCount() == 0, AB.Errors(reload))
local restored = RK.Store.Module("ActionBars")
for _, key in ipairs({ "bar4", "bar5" }) do
	for _, field in ipairs(fields) do
		assert(RK.Options.Equal(restored[key][field], ns.defaults[key][field]), key .. ": restore missing " .. field .. " from defaults")
	end
	assert(restored[key].placement ~= ns.defaults[key].placement, "restored tables must not alias defaults")
end
assert(restored.extraBarsApplied == "off", "old extra bars snapshot restores successfully")
print("actionbars upgrade ok: v0.2.7 profile and snapshots load and apply without errors")
