-- audit_dispels.lua: the engine classifies five party debuffs; the addon supplies only the matching type letters.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
return Common.Run(function()
	local env, K, ns = G.New(Common.ScreenOpts({ saved = Gallery.Saved({ "GroupFrames" }), setup = Common.ForceScreen }))
	dofile("Tools/render/scenes/_audit.lua").Apply(K)
	G.SetRoster(env, "party", G.Members(4), { name = "Magic", class = "PRIEST", health = 80, maxHealth = 100, role = "HEALER" })
	K.Modules.Enable("GroupFrames")
	K.Layout.Set("groupframes.party", "anchor", "CENTER")
	K.Layout.Set("groupframes.party", "x", 0)
	K.Layout.Set("groupframes.party", "y", 0)
	env.RunTimers()
	local types = { "Magic", "Curse", "Disease", "Poison", "Enrage" }
	ns.Unit.ForEach(function(f)
		local index = f.unit == "player" and 1 or tonumber(f.unit and f.unit:match("^party(%d)$"))
		if index and f.kind == "party" then
			if f.unit ~= "player" then index = index + 1 end
			A.Assign(env, f.auras, "debuffs", 1)
			local group = f.auras._groups.debuffs
			local button = group.frames[1]
			button._aura.icon:SetTexture(135813)
			if A.Dispel then A.Dispel(button, types[index]) end
			Hud.PlaceAuras(f.auras, group, { button }, 1)
		end
	end)
	dofile("Tools/render/scenes/_audit.lua").Apply(K)
	env.RunTimers()
	Hud.Tick(env, 0.5)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
end)
