-- unitframes_design.lua: the player and target frames and the target cast bar with the design file's chamfered
-- octagon portraits, at the design file's sections, for the side-by-side against the design at 2 px per unit.
--
--   Tools/render/shoot.sh unitframes_design --ppu 2.0 --out Tools/render/out/unitframes_design.png
--
-- The HUD scene shows the default round portraits against the owner's mockup; this one switches both frames to
-- the chamfered shape, the design file's look, so each shape has its own side-by-side.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene

local SECTIONS = { player = { x = 288, y = 132 }, target = { x = 624, y = 132 }, targetCast = { x = 660, y = 232 } }

local function move(K, key, x, y)
	assert(K.Layout.Set(key, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(key, "x", x))
	assert(K.Layout.Set(key, "y", -y))
end

return Common.Run(function()
	local U = dofile("Tools/regression/unitframes_env.lua")
	local player = { name = "Valerin", class = "WARRIOR", level = 42, health = 3120, healthMax = 3980, power = 60, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5 }
	local target = { name = "Frost Howler", level = 40, health = 2240, healthMax = 4020, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true,
		cast = { name = "Frost Bite", texture = 135846, start = 8000, finish = 11000, spellID = 116 } }
	local env, K = U.New(Common.ScreenOpts({
		saved = {
			version = 2,
			profiles = { Default = { UnitFrames = { enabled = true, player = { portraitShape = "chamfered" }, target = { portraitShape = "chamfered" } } } },
			characters = {},
			layouts = {},
			account = { setupSeen = true },
			devlog = {},
		},
		setup = function(env)
			Common.ForceScreen(env)
			env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
			env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
			env._units.player = player
			env._units.target = target
			env.UnitClass = function(token)
				local u = env._units[token]
				if u and u.class then
					return u.class:sub(1, 1) .. u.class:sub(2):lower(), u.class, 1
				end
			end
		end,
	}))
	env._time = 10
	env.SetTarget(true)
	env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 116)
	env.RunTimers()
	move(K, "unitframes.player", SECTIONS.player.x, SECTIONS.player.y)
	move(K, "unitframes.target", SECTIONS.target.x, SECTIONS.target.y)
	move(K, "unitframes.castbar.target", SECTIONS.targetCast.x, SECTIONS.targetCast.y)
	for _, key in ipairs({ "unitframes.castbar.player", "unitframes.targettarget", "unitframes.pet", "unitframes.focus", "unitframes.focustarget", "unitframes.boss", "unitframes.resource" }) do
		K.Layout.Set(key, "shown", "never")
	end
	for _ = 1, 40 do
		U.W.Tick(env, 0.05)
	end
	for texture in pairs(env._portraits) do
		texture:SetColorTexture(0.33, 0.28, 0.22, 1)
	end
	local scene = Scene.Build(env, { time = env._time })
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "unitframes error: " .. err
	end
	scene.log[#scene.log + 1] = "unitframes: portraits are flat stand-ins; the game draws the unit's model"
	return scene
end)
