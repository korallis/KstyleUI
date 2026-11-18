local G = dofile("Tools/regression/group_env.lua")
local env, K, ns = G.New({ setup = function(e)
	e.UnitHasIncomingResurrection = function() return e.Secret(true) end
	e.UnitIsAFK = function() return e.Secret(false) end
	e.C_IncomingSummon = { HasIncomingSummon = function() return e.Secret(false) end }
end })
G.SetRoster(env, "party", { { name = "Tank", role = "TANK", class = "WARRIOR" } })
K.Modules.Enable("GroupFrames")
env.RunTimers()
local found
ns.Unit.ForEach(function(f) if f.unit == "party1" then found = f end end)
assert(found and found.role:IsShown() and not found.pipFill:IsShown(), "roles need a shape in every colour mode")
local status = found.statusIcons
assert(status and status.resurrection:GetWidth() == 14, "status icons use the ready-check slot at 14 units")
assert(env.Reveal(status.resurrection:GetAlpha()) == 1 and env.Reveal(status.afk:GetAlpha()) == 0, "secret status booleans go straight to engine alpha setters")
env.UnitIsAFK = function() return env.Secret(true) end
env.C_IncomingSummon.HasIncomingSummon = function() return env.Secret(true) end
env.FireEvent("INCOMING_SUMMON_CHANGED", "party1")
assert(env.Reveal(status.afk:GetAlpha()) == 0 and env.Reveal(status.summon:GetAlpha()) == 0, "resurrection wins the status slot without comparing secret flags")
env.FireEvent("READY_CHECK")
assert(status.resurrection:GetAlpha() == 0, "the ready check owns the shared slot while active")
K.Options.Write("GroupFrames", "presets.raid", "Healer")
env.RunTimers()
for _, count in ipairs({ 5, 20, 40 }) do
	G.SetRoster(env, "raid", G.Members(count))
	env.RunTimers()
	local cfg = ns.Settings.Refresh()
	ns.AutoLayout.Overlay(cfg, { healer = true, bracket = count == 40 and "LARGE" or "SMALL" })
	assert(cfg.party.width == 200 and cfg.party.height == 44 and cfg.party.spacing == 6)
	assert(cfg.raid.width == 128 and cfg.raid.height == 44 and cfg.raid.groupsPerRow == 4)
	assert(cfg.raid.healthText == "DEFICIT" and cfg.raid.healthTextSize == 12, "Healer keeps a 12-unit deficit at " .. count)
	assert(cfg.indicator1.size == 16)
	local visible = 0
	ns.Unit.ForEach(function(f)
		if f.kind == "raid" and f.unit then
			visible = visible + 1
			assert(f.healthText:IsShown() and select(2, f.healthText:GetFont()) >= 12, "the live raid keeps its deficit")
		end
	end)
	assert(visible >= count)
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("group accessibility ok")
