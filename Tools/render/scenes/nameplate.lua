-- nameplate.lua: the target's plate over the crocolisk, mid-cast, on a base plate the game scaled to 0.58.
--
-- The game sets a nameplate base's scale to UIParent's effective scale times the plate's distance and target
-- factor; on the owner's Mac a plate near the player reads about 0.58. The plate ignores that scale and draws
-- in KstyleUI root units, so this scene puts the base at 0.58 to prove the plate still renders at the
-- mockup's size (mockup-leveling-warrior-2574.png, the plate above the crocolisk, 1.348 px per unit).
local Common = dofile("Tools/render/scenes/_common.lua")

local BASE_SCALE = 0.58
-- The bar's centre in the mockup, in screen units from the top left.
local PLATE_X, PLATE_Y = 1135, 403

return Common.Run(function()
	local N = dofile("Tools/regression/nameplates_env.lua")
	local env, K = N.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = {
			version = 2,
			profiles = { Default = { Nameplates = { enabled = true } } },
			characters = {},
			layouts = {},
			account = { setupSeen = true },
			devlog = {},
		},
		setup = function(env)
			Common.ForceScreen(env)
			env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
			env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
			env.UnitClass = function(unit)
				if unit == "player" or unit == nil then
					return "Warrior", "WARRIOR", 1
				end
			end
		end,
	})
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	local base = N.Add(env, "nameplate1", {
		name = "Riverglade Crocolisk", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true,
	}, { scale = BASE_SCALE })
	-- The base's anchors are in its own scale: a screen unit is 768 / 1080 world units over the base's scale.
	local toBase = (768 / 1080) / BASE_SCALE
	base:ClearAllPoints()
	base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", PLATE_X * toBase, (1080 - PLATE_Y) * toBase)
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = 132200, notInterruptible = false })
	for _ = 1, 20 do
		N.Tick(env, 0.05)
	end
	local scene = Common.Scene.Build(env, { time = env._time })
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "nameplate error: " .. err
	end
	scene.log[#scene.log + 1] = "the base plate is scaled to " .. BASE_SCALE .. ", as the owner's Mac scales a plate near the player; the plate ignores it"
	return scene
end)
