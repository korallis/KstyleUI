-- _encounter.lua: the encounter warnings in a HUD scene: the stand-in RaidWarningFrame (Tools/regression/encounter_warnings.lua,
-- built from Forever's Blizzard_RaidWarning) at the anchor Layout > Apply writes into the "KstyleUI <layout>" Edit Mode
-- layout, skinned by KstyleUI_Skins/Encounter/Warnings.lua, showing a boss emote as RAID_BOSS_EMOTE adds it.
--
--   local Encounter = dofile("Tools/render/scenes/_encounter.lua")
--   local scene, frame = Encounter.Build(Hud, opts)   -- opts.layout, opts.guide, opts.saved (KstyleUIDB), opts.messages
--
-- Forever 1.60.1 has no encounter timeline: Blizzard_EncounterTimeline and Blizzard_EncounterWarnings load only on the
-- standard game type, Camelot/EditModeManagerOverrides.lua hides their Edit Mode switch and Camelot/InterfaceOverrides.lua
-- answers HasBossWarnings() false. A boss's warnings reach a Forever player through RAID_BOSS_EMOTE and
-- RAID_BOSS_WHISPER, which RaidWarningFrame shows; this is that surface.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local Warnings = dofile("Tools/regression/encounter_warnings.lua")

local Encounter = {}

-- The boss emote the combat board shows: the matriarch's cast, as the encounter script announces it.
Encounter.MESSAGES = {
	{ "Bloodtalon Matriarch begins to cast Terrifying Screech!", Warnings.BOSS, Warnings.BOSS_EMOTE },
}

-- Anchor(Hud, layout, guide) -> RaidWarningFrame's Edit Mode anchor after Layout > Apply, or nil when Apply placed none.
function Encounter.Anchor(Hud, layout, guide)
	local written = Hud.EditModeLayout(layout, guide)
	local entry = written and EditModeFake.Find(written, EditModeFake.RAID_WARNING)
	return entry and not entry.isInDefaultPosition and entry.anchorInfo or nil
end

function Encounter.Build(Hud, opts)
	local S = dofile("Tools/regression/skins_env.lua")
	local frame
	local anchor = Encounter.Anchor(Hud, opts.layout or "DPS", opts.guide == true)
	local env, K = S.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = opts.saved,
		loaded = { Blizzard_RaidWarning = true },
		setup = function(env)
			Common.ForceScreen(env)
		end,
		before = function(env)
			frame = Warnings.Build(env, S.Blizzard(env))
			if anchor then
				frame:ClearAllPoints()
				frame:SetPoint(anchor.point, env.UIParent, anchor.relativePoint, anchor.offsetX, anchor.offsetY)
			end
		end,
	})
	if not K.Modules.IsRunning("Skins") then
		K.Modules.Enable("Skins")
	end
	env.RunTimers()
	for _, m in ipairs(opts.messages or Encounter.MESSAGES) do
		frame:AddMessage(m[1], m[2], 6, m[3])
	end
	env.RunTimers()
	local scene = Scene.Build(env, { iconDirs = Common.IconDirs() })
	Hud.envs[scene] = env
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	scene.log[#scene.log + 1] = "the raid and boss warnings are a stand-in RaidWarningFrame laid out as Blizzard_RaidWarning does, "
		.. (anchor and "at the anchor Layout > Apply wrote into the KstyleUI Edit Mode layout" or "at Forever's preset")
		.. "; the boss emote's colour is a stand-in for ChatTypeInfo.RAID_BOSS_EMOTE"
	for i, line in ipairs(scene.log) do
		scene.log[i] = "encounter: " .. line
	end
	return scene, frame
end

return Encounter
