local G = dofile("Tools/regression/group_env.lua")
local env, K, ns = G.New({ saved = { version = 35, profiles = { Default = { GroupFrames = { blizzard = { manager = true } } } } }, setup = function(e)
	e.UnitHasIncomingResurrection = function() return e.Secret(true) end
	e.UnitIsAFK = function() return e.Secret(false) end
	e.C_IncomingSummon = { HasIncomingSummon = function() return e.Secret(false) end }
end })
G.SetRoster(env, "party", { { name = "Tank", role = "TANK", class = "WARRIOR" } })
K.Modules.Enable("GroupFrames")
env.RunTimers()
local manager = env.CompactRaidFrameManager
local parent = manager:GetParent()
K.Options.Write("GroupFrames", "blizzard.keepManager", false)
env.RunTimers()
assert(manager:GetParent() ~= parent, "Hide the raid manager restores the previous hidden manager")
K.Options.Write("GroupFrames", "blizzard.keepManager", true)
env.RunTimers()
assert(manager:GetParent() == parent, "the default keeps the raid manager available")
local found
ns.Unit.ForEach(function(f) if f.unit == "party1" then found = f end end)
assert(found and found.role:IsShown() and not found.pipFill:IsShown(), "roles need a shape in every colour mode")
K.Options.Write("GroupFrames", "icons.roleShapes", false)
env.RunTimers()
assert(found.pipFill:IsShown() and not found.role:IsShown(), "Role shapes off restores the coloured pip")
assert(found.parts.icons.role.width == 13, "Role shapes off restores the previous pip footprint")
K.Options.Write("GroupFrames", "icons.roleShapes", true)
env.RunTimers()
assert(found.role:IsShown() and not found.pipFill:IsShown(), "Role shapes can be re-enabled")
local status = found.statusIcons
assert(status and status.resurrection:GetWidth() == 14, "status icons use the ready-check slot at 14 units")
assert(env.Reveal(status.resurrection:GetAlpha()) == 1 and env.Reveal(status.afk:GetAlpha()) == 0, "secret status booleans go straight to engine alpha setters")
K.Options.Write("GroupFrames", "icons.statuses", false)
env.RunTimers()
assert(status.resurrection:GetAlpha() == 0 and status.summon:GetAlpha() == 0 and status.afk:GetAlpha() == 0, "Status icons off restores the ready-check-only slot")
K.Options.Write("GroupFrames", "icons.statuses", true)
env.RunTimers()
env.UnitIsAFK = function() return env.Secret(true) end
env.C_IncomingSummon.HasIncomingSummon = function() return env.Secret(true) end
env.FireEvent("INCOMING_SUMMON_CHANGED", "party1")
assert(env.Reveal(status.afk:GetAlpha()) == 0 and env.Reveal(status.summon:GetAlpha()) == 0, "resurrection wins the status slot without comparing secret flags")
local A = dofile("Tools/regression/auras_env.lua")
A.Assign(env, found.auras, "debuffs", 1)
local button = found.auras._groups.debuffs.frames[1]
local letter
for _, entry in ipairs(button._aura.dispel) do if entry.options.customDispelAssetMap then letter = entry.texture end end
assert(letter, "the aura engine owns the dispel classification map")
A.Dispel(button, "Magic")
assert(letter:IsShown() and letter:GetTexture() == (K.Tokens.Texture("dispelM")), "the engine selects M for Magic")
K.Options.Write("GroupFrames", "auras.typeLetters", false)
env.RunTimers()
assert(letter:GetAlpha() == 0, "Type letters off restores the old aura border alone")
K.Options.Write("GroupFrames", "auras.typeLetters", true)
env.RunTimers()
assert(letter:GetAlpha() == 1)
A.Dispel(button, nil)
assert(not letter:IsShown(), "an unclassified aura has no guessed type letter")
env.UnitThreatSituation = function() return 2 end
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "party1")
assert(found.threatShape:IsShown())
K.Options.Write("GroupFrames", "threat.shapes", false)
env.RunTimers()
assert(found.threat:IsShown() and not found.threatShape:IsShown(), "Threat shapes off keeps the previous border")
K.Options.Write("GroupFrames", "threat.shapes", true)
env.RunTimers()
assert(found.threatShape:IsShown())
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
K.Options.Write("GroupFrames", "presets.raid", "Compact")
env.RunTimers()
assert(ns.Settings.current.party.width == ns.Settings.defaults.party.width, "Compact restores the previous party dimensions")
assert(ns.Settings.current.raid.healthText ~= "DEFICIT", "Compact restores the previous automatic raid text")
assert(#env._errors == 0, tostring(env._errors[1]))
print("group accessibility ok")
