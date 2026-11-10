-- cooldowns_items.lua: synthetic item-backed rows rendered by the real mirror beside ordinary spell rows.
local Common = dofile("Tools/render/scenes/_common.lua")
local C = dofile("Tools/regression/cooldowns_env.lua")

return Common.Run(function()
	local category = C.CATEGORY.Essential
	local env, K, ns = C.New({
		saved = { version = 2, profiles = { Default = {} }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		cooldowns = {
			[101] = { equipSlot = 13, category = category },
			[102] = { spellCategoryID = 30, category = category },
			[103] = { spellID = 1003, category = category },
			[104] = { spellID = 1004, category = category },
			[105] = { spellID = 1005, category = category, charges = true },
			[106] = { spellID = 1006, category = category },
		},
		setup = function(e)
			Common.ForceScreen(e)
			C.Game(e)
			e._time = 10
			e.GetInventoryItemTexture = function(_, slot)
				return slot == 13 and 133283 or nil
			end
			e.GetInventoryItemCooldown = function(_, slot)
				assert(slot == 13, "the fixture reads the equipped trinket slot")
				return 4, 10, 1, false
			end
			e.C_Spell.GetLastCategoryCooldownSource = function(id)
				assert(id == 30, "the fixture reads the health-potion category")
				return 2002, 90002
			end
			e.C_Spell.GetItemCooldown = function(id)
				assert(id == 90002, "the cooldown belongs to the category's item")
				return { startTime = 4, duration = 18, modRate = 1, isActive = true, isEnabled = true, isOnGCD = false }
			end
			e.C_Spell.GetSpellCastCount = function(spell)
				return spell == 2002 and 3 or 0
			end
			e._cdm.textures[1003] = 135813
			e._cdm.textures[1004] = 136026
			e._cdm.textures[1005] = 135940
			e._cdm.textures[1006] = 136048
			e._cdm.durations[2002] = { start = -18, finish = 30 }
			e._cdm.cooldown[2002] = { active = true }
			e._cdm.durations[1004] = { start = -2, finish = 22 }
			e._cdm.cooldown[1004] = { active = true }
			e._cdm.charges[1005] = { current = 3, max = 3 }
			e._cdm.overlay[1003] = true
		end,
	})
	C.Enable(env, K)
	env.RunTimers()
	C.W.Settle(env)
	local errorText = Common.Errors(env, K)
	assert(not errorText, errorText)
	local scene = Common.Scene.Build(env, {
		time = env._time,
		paths = function(path)
			if path == ns.Data.CATEGORY_ICONS[30] then
				path = 134834
			end
			return Common.Scene.ResolvePath(path, Common.IconDirs())
		end,
	})
	scene.log[#scene.log + 1] = "item fixture: equipped slot 13 has four seconds left; health-potion item has twelve seconds left and three uses; its unrelated spell timer has twenty seconds left"
	scene.log[#scene.log + 1] = "item fixture: the canonical INV_Potion_54 texture resolves through file ID 134834 from Tools/data/icon_names.csv; item IDs and timings are synthetic, not a live client capture"
	return scene
end)
