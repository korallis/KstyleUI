-- actionbars_spells.lua: the real combined new-rank and new-spell offer, in the selected HUD style.
local Common = dofile("Tools/render/scenes/_common.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

return Common.Run(function()
	local env, K = AB.New(Common.ScreenOpts({ setup = Common.ForceScreen, saved = Gallery.Saved() }))
	local g = env._game
	AB.Enable(env, K)
	g.spells[78] = { name = "Heroic Strike", subtext = "Rank 1" }
	g.spells[284] = { name = "Heroic Strike", subtext = "Rank 2" }
	g.spells[100] = { name = "Charge", subtext = "" }
	g.bookSpells[20] = { spellID = 100, itemType = env.Enum.SpellBookItemType.Spell, isPassive = false, isOffSpec = false }
	g.slots[1] = { type = "spell", id = 78 }
	env.C_Spell.GetSpellTexture = function(id) return id == 100 and 132337 or 132282 end
	env.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", 284, 1, false)
	if os.getenv("RENDER_SPELLS") ~= "ranks" then
		env.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", 100, 1, false)
	end
	env.RunTimers()
	AB.W.Settle(env)
	local scene = Gallery.Build(env)
	local err = Common.Errors(env, K)
	if err then scene.log[#scene.log + 1] = "error: " .. err end
	return scene
end)
