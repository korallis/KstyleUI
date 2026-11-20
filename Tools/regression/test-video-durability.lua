-- test-video-durability.lua: Apply gives native durability its own space beside the minimap and respects subsequent Edit Mode moves.
local W = dofile("Tools/regression/widget_env.lua")
local F = dofile("Tools/regression/editmode_fake.lua")
for _, explicit in ipairs({ false, true }) do
	local layout = F.Modern()
	layout.layoutName, layout.layoutType = "KstyleUI DPS", F.ACCOUNT
	local doll = F.Find(layout, 16)
	doll.isInDefaultPosition = not explicit
	doll.anchorInfo.offsetX = -137
	local state = { saved = { F.Copy(layout) }, active = 3 }
	local env, K = W.New({ setup = function(e) F.Install(e, state) end })
	env.RunTimers(); W.Settle(env); env.RunTimers()
	local after = F.Find(F.Named(state, "KstyleUI DPS"), 16)
	assert(explicit and after.anchorInfo.offsetX == -137 or not explicit and after.anchorInfo.offsetX ~= -137, "login updates untouched durability defaults and keeps an explicitly saved position")
	assert(K.Setup.EditMode.Write("DPS", K.Setup.Story("DPS", false)))
	if explicit then assert(F.Find(F.Named(state, "KstyleUI DPS"), 16).anchorInfo.offsetX == -137, "Apply also preserves explicit durability positions") end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
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
		assert(a.point == "TOPRIGHT" and x <= l - 16 + 0.01 and y <= t - 64 and y - 75 / k >= b, "issue 9: the doll sits beside the map, below the buff row and above the story cards: " .. style .. " " .. x .. "," .. y .. " map " .. l .. "," .. b .. "," .. t)
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
