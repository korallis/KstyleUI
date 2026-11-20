-- test-video-durability.lua: Apply gives native durability its own space beside the minimap and respects subsequent Edit Mode moves.
local W = dofile("Tools/regression/widget_env.lua")
local F = dofile("Tools/regression/editmode_fake.lua")
for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local state = { saved = {}, active = 1 }
		local env, K = W.New({ width = screen[1], height = screen[2], setup = function(e) F.Install(e, state) end })
		assert(K.Setup.Apply({ layout = "DPS", modules = {}, hudStyle = style }))
		local layout = F.Named(state, "KstyleUI DPS")
		local doll = F.Find(layout, 16)
		assert(doll and not doll.isInDefaultPosition, "issue 9: Apply must place the durability doll clear of the guide and coordinates")
		local a = doll.anchorInfo
		local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
		local rw, rh = K.Setup.RootSize()
		local map = K.Setup.Layouts.Positions("DPS", style, K.Scale.Aspect(), K.Scale.Band())["minimap.main"]
		local width, height = K.Setup.Layouts.Footprint("DPS", "minimap.main")
		local l, b, _, t = K.Setup.Layouts.Rect({ width = width, height = height }, map, rw, rh)
		local x, y = a.offsetX / k - K.Scale.Origin(), a.offsetY / k
		assert(a.point == "TOPRIGHT" and x <= l - 16 and y <= t - 64 and y - 75 >= b, "issue 9: the doll sits beside the map, below the buff row and above the story cards")
		assert(F.Setting(doll, 0) == 5, "keep the player's durability size")
		doll.anchorInfo.offsetX = doll.anchorInfo.offsetX - 40
		local moved = doll.anchorInfo.offsetX
		state.saved[1] = F.Copy(layout)
		K.Setup.EditMode.Restyle("DPS", K.Setup.Story("DPS", false))
		assert(F.Find(F.Named(state, "KstyleUI DPS"), 16).anchorInfo.offsetX == moved, "preserve a durability position the player moved")
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
end
print("video durability ok: 12 screen/style cases")
