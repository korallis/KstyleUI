-- combat_readability_hud.lua: real unit frames and combat text together, with a power readout, a half-health target, two target debuffs and live player/target hits.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local U = dofile("Tools/regression/unitframes_env.lua")
	local CT = dofile("Tools/regression/combattext_env.lua")
	local Load = dofile("Tools/regression/load_files.lua")
	local rogue = os.getenv("RENDER_POWER_CLASS") == "ROGUE"
	local env, K, ns = U.New(Common.ScreenOpts({
		login = false,
		saved = Gallery.Saved({ "UnitFrames", "CombatText", HudStyle = { style = (os.getenv("RENDER_HUD_STYLE") or "Medallions"):lower() } }),
		setup = function(env)
			Common.ForceScreen(env, true)
			CT.Fakes(env)
			CT.CVars(env)
			env._units.player = { name = "Korallis", class = rogue and "ROGUE" or "SHAMAN", race = "Dwarf", sex = 2, isPlayer = true, level = 11, health = 203, healthMax = 237, power = rogue and 80 or 214, powerMax = rogue and 100 or 335, powerType = rogue and 3 or 0, powerToken = rogue and "ENERGY" or "MANA", reaction = 5,
				cast = { name = "Lightning Bolt", texture = 136048, start = 8500, finish = 11000, spellID = 403 } }
			env._units.target = { name = "Poacher", creature = "Humanoid", level = 12, health = 118, healthMax = 236, reaction = 2, canAttack = true,
				cast = { name = "Shadow Bolt", texture = 136197, start = 8500, finish = 11000, spellID = 686 } }
			env.RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41 }, SHAMAN = { r = 0, g = 0.44, b = 0.87 } }
		end,
	}))
	Load(CT.Files(), env)
	U.W.CoreEnv.Login(env)
	env.RunTimers()
	assert(K.Setup.Apply({ layout = "DPS", modules = { UnitFrames = true, CombatText = true } }))
	env.RunTimers()
	if os.getenv("RENDER_POWER_SEPARATE") then
		K.Options.Write("UnitFrames", "player.powerSeparate", os.getenv("RENDER_POWER_SEPARATE") ~= "0")
	end
	if os.getenv("RENDER_POWER_FULL") == "1" then
		env._units.player.power = env._units.player.powerMax
		env.FireEvent("UNIT_POWER_UPDATE", "player")
	end
	if os.getenv("RENDER_COMBAT_LEGACY") == "1" then
		K.Options.Write("UnitFrames", "player.powerText", "legacy")
		K.Options.Write("UnitFrames", "target.percentLead", false)
		K.Options.Write("UnitFrames", "player.powerSeparate", true)
		K.Options.Write("UnitFrames", "player.powerSeparate", false)
		K.Options.Write("CombatText", "clearLanes", false)
	end
	env.SetTarget(true)
	env._time = 10
	for _, unit in ipairs({ "player", "target" }) do env.FireEvent("UNIT_SPELLCAST_START", unit, "Cast-1") end
	for _ = 1, 40 do U.W.Tick(env, 0.05) end
	local target = ns.Frames.Get("target").views[1]
	local container = target.auras
	if container and container.host then
		local host = container.container
		local group = host._groups.debuffs
		local buttons = {}
		for i = 1, math.min(2, #group.buttons) do
			local button = group.buttons[i]
			for _, entry in ipairs(container.buttons) do
				if entry.button == button then
					entry.icon:SetTexture(i == 1 and 135813 or 136026)
					entry.timer:SetText(i == 1 and "9s" or "3s")
				end
			end
			buttons[i] = button
		end
		Hud.PlaceAuras(host, group, buttons, 6)
	end
	CT.Hit(env, "player", "WOUND", "", env.Secret(120), 1)
	CT.Hit(env, "target", "WOUND", "CRITICAL", env.Secret(240), 1)
	local scene = Gallery.Build(env, { time = env._time })
	assert(not Common.Errors(env, K), Common.Errors(env, K))
	return scene
end)
