-- test-hud-placement-review.lua: declared cooldown bounds contain the mirror, swing bars clear the slab rim, and Meters never owns class resources.
local C = dofile("Tools/regression/cooldowns_env.lua")
local M = dofile("Tools/regression/meters_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local pick = arg and arg[1]

if not pick or pick == "grid" then
	local env, K, ns = C.New({cooldowns=C.Sample()})
	C.Enable(env, K)
	env.RunTimers()
	for _, group in ipairs({"essential", "utility"}) do
		local key = "cooldowns." .. group
		local width, height = ns.Grid.Size(ns.Settings.current[group])
		local w, h = K.Setup.Layouts.Footprint("DPS", key)
		assert(math.abs(w-width)<0.01 and math.abs(h-height)<0.01, group .. ": footprint must equal the real mirror grid, not the old six-icon box")
		local fit = K.Setup.Layouts.PrepareFits("DPS",1920,1080,K.Setup.Layouts.Enabled("DPS"),nil)
		for i, element in ipairs(K.Setup.Layouts.ELEMENTS) do
			if element.key == key then assert(math.abs(fit.sizes[i][1]-width)<0.01 and math.abs(fit.sizes[i][2]-height)<0.01, "Fits must measure the full mirror grid") end
		end
	end
	for _, attached in ipairs({true, false}) do
		K.Store.Module("Cooldowns").attached = attached
		for _, group in ipairs({"essential", "utility"}) do
			K.Store.Module("Cooldowns")[group] = {size=41.3, spacing=6.2, columns=5, rows=3}
		end
		ns.Settings.Read()
		for _, group in ipairs({"essential", "utility"}) do
			local width,height=ns.Grid.Size(ns.Settings.current[group])
			local w,h=K.Setup.Layouts.Footprint("DPS","cooldowns."..group)
			assert(math.abs(w-width)<0.01 and math.abs(h-height)<0.01,"explicit grid settings must have the same footprint with either placement option")
		end
	end
	print("review grid: declared and fitted bounds equal both live grids")
end

if not pick or pick == "rim" then
	local env, K, ns = M.New()
	M.Enable(env,K)
	env.FireEvent("PLAYER_SWING",2.6,M.SWING.MainHand)
	env.FireEvent("PLAYER_SWING",2.4,M.SWING.OffHand)
	local L = K.Setup.Layouts
	local bar = L.Place("DPS","medallions",K.Scale.Aspect(),"actionbars.bar1")
	local _,_,_,height = L.MedallionsGroup(K.Scale.Aspect())
	local rimTop = bar.y + height + L.MEDALLIONS_SLAB.pad
	for _, slot in ipairs({M.SWING.MainHand,M.SWING.OffHand}) do
		local r = assert(G.ScaledRect(ns.Swing.bars[slot],env.UIParent,K.Scale.Root()))
		assert(r.bottom >= rimTop + K.Scale.Pixel(2) - 0.01, "Medallions swing bars must clear the slab's top rim by at least two physical pixels")
	end
	print("review rim: both hands clear the slab rim")
end

if not pick or pick == "resource" then
	local env,K = M.New()
	M.Enable(env,K)
	local L = K.Setup.Layouts
	local old=L.Previous("medallions","DPS","unitframes.resource",K.Scale.Aspect())
	for _,on in ipairs({true,false}) do
		M.Write(env,K,"swing.attached",on)
		local p=L.Place("DPS","medallions",K.Scale.Aspect(),"unitframes.resource")
		assert(p.anchor==old.anchor and p.x==old.x and p.y==old.y, "Meters must never move the Unit Frames class-resource bar")
	end
	old=L.Default("unitframes.resource")
	local data={profiles={Default={}},layouts={Default={["unitframes.resource"]={anchor=old.anchor,x=old.x,y=old.y}}}}
	K.Store.migrations[36](data)
	assert(data.layouts.Default["unitframes.resource"] and data.layouts.Default["unitframes.resource"].y==old.y,"migration 36 must leave class-resource positions intact")
	assert(data.layouts.Default["medallions:unitframes.resource"]==nil,"migration 36 must not take ownership of resource positions")
	print("review resource: position and migration independent of Meters")
end
