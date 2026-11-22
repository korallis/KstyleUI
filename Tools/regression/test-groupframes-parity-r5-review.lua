-- test-groupframes-parity-r5-review.lua: the PR #654 review of EllesmereUI parity round 5: friendly bosses that follow their faction in combat, pet, tank and friendly boss frames in the raid's card (their default places are in test-groupframes-parity-r5-places.lua), every raid pet, the boss debuff zoom, the time left inside its clip, switched-off groups at rest, a refused boss group and the extra groups' preview.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local A = dofile("Tools/regression/auras_env.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, noErrors, boot, offset, near = H.write, H.frame, H.noErrors, H.boot, H.offset, H.near
local Scene = dofile("Tools/render/scene.lua")

local function moved(region, write1, dx, dy, label)
	local x0, y0 = offset(region)
	write1()
	local x1, y1 = offset(region)
	assert(near(x1 - x0, dx) and near(y1 - y0, dy), label .. " moves " .. dx .. ", " .. dy .. ": got " .. (x1 - x0) .. ", " .. (y1 - y0))
end

local function bootSecure()
	return boot({ setup = function(env)
		H.setup(env)
		G.Secure(env)
		env._units = env._units or {}
		env.UnitCanAssist = function(_, unit) local m = env._member(unit) return m ~= nil and m.friend == true end
	end })
end

local function shownUnits(header)
	local out, i = {}, 1
	while header:GetAttribute("child" .. i) do
		local child = header:GetAttribute("child" .. i)
		if child:IsShown() and child:GetAttribute("unit") then out[#out + 1] = child:GetAttribute("unit") end
		i = i + 1
	end
	return table.concat(out, ",")
end


-- A friendly boss turning hostile in combat, without leaving its token, hides; turning back shows it. Forever's
-- SecureStateDriver.lua writes a state attribute only when its value changes, so the stub's repeat writes are dropped.
do
	local env, K, ns = bootSecure()
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	write(env, K, "boss.display", "ALWAYS")
	local b = ns.Extras.groups.boss.buttons[1]
	local set = b.SetAttribute
	function b:SetAttribute(key, value)
		if tostring(key):match("^state%-") and self:GetAttribute(key) == value then return end
		return set(self, key, value)
	end
	env._units.boss1 = { name = "Valithria", class = "DRUID", health = 50, maxHealth = 100, friend = true }
	env.SetCombat(true)
	env.RunStateDrivers()
	assert(b:IsShown(), "a friendly boss shows in combat")
	env._units.boss1.friend = false
	env.FireEvent("UNIT_FACTION", "boss1")
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.RunStateDrivers()
	assert(not b:IsShown(), "it hides once it turns hostile without leaving")
	env._units.boss1.friend = true
	env.RunStateDrivers()
	assert(b:IsShown() and #env._blocked == 0, "and shows again once it can be helped, from secure code")
	env.SetCombat(false)
	env.RunTimers()
	-- Friendly boss frames switched to Never and pet frames switched off stop listening and painting, and are not laid out again.
	do
		G.SetRoster(env, "raid", G.Members(10))
		env._units.raidpet2 = { name = "Fang", class = "HUNTER", health = 50, maxHealth = 50 }
		env.RunTimers()
		write(env, K, "boss.display", "ALWAYS")
		write(env, K, "pets.enabled", true)
		env.RunStateDrivers()
		local pet = ns.Button.Content(ns.Extras.groups.pets.header:GetAttribute("child1"))
		assert(pet.unit == "raidpet2", "the pet frame follows its pet while on")
		write(env, K, "boss.display", "NEVER")
		write(env, K, "pets.enabled", false)
		local f = ns.Button.Content(ns.Extras.groups.boss.buttons[1])
		assert(not f:IsEventRegistered("UNIT_HEALTH") and f.unit == nil, "Never leaves no boss unit or listener")
		assert(not pet:IsEventRegistered("UNIT_HEALTH") and pet.unit == nil, "off leaves no pet unit or listener")
		local repaints, refresh = 0, ns.Unit.Refresh
		ns.Unit.Refresh = function(v, ...) if v.extra then repaints = repaints + 1 end return refresh(v, ...) end
		ns.Unit.RefreshAll()
		ns.Unit.Refresh = refresh
		assert(repaints == 0, "a refresh paints no switched-off frame: " .. repaints)
		local header, writes = ns.Extras.groups.pets.header, 0
		local setHeader = header.SetAttribute
		header.SetAttribute = function(...) writes = writes + 1 return setHeader(...) end
		ns.Frames.Apply()
		header.SetAttribute = setHeader
		assert(writes == 0, "an apply leaves the switched-off pet header alone: " .. writes .. " writes")
	end
	noErrors(env, K)
end
collectgarbage()

-- The time left stays inside its clip, and the preview follows the group number offsets and shows pet, tank and friendly boss samples with their own size, colour and wrap.
do
	local env, K, ns = boot()
	-- The Medallions party row has no boss debuff slot; the time left stays inside its clip.
	do
		local f = frame(ns, "party1")
		assert(f.parts.boss == nil, "the Medallions party row lays out no boss debuff slot")
		-- The time left stays inside the heal icons' clip at every offset the sliders allow; at no offset, "12s" is a twentieth
		-- of a unit wider than its 11-unit icon, so the sides allow a tenth.
		write(env, K, "auras.timers", true)
		A.Assign(env, f.buffs, "buffs", 1)
		env.RunTimers()
		local heals = f.buffs._groups.buffs
		dofile("Tools/render/scenes/hud.lua").PlaceAuras(f.buffs, heals, heals.active, 1)
		local timer = ns.Auras.Parts(heals.active[1]).timer
		timer:SetText("12s")
		for _, nudge in ipairs({ { 0, -20 }, { 20, 0 }, { -20, 0 }, { 0, 20 }, { 0, 0 } }) do
			write(env, K, "auras.timerX", nudge[1])
			write(env, K, "auras.timerY", nudge[2])
			local x, y, w, h = Scene.Rect(env, timer)
			local cx, cy, cw, ch = Scene.Rect(env, f.buffClip)
			assert(x >= cx - 0.1 and x + w <= cx + cw + 0.1 and y >= cy - 1e-3 and y + h <= cy + ch + 1e-3,
				("offset %d, %d: the time left %.3f..%.3f x %.3f..%.3f leaves the clip %.3f..%.3f x %.3f..%.3f"):format(nudge[1], nudge[2], x, x + w, y, y + h, cx, cx + cw, cy, cy + ch))
		end
	end
	-- The preview follows the group number offsets and shows pet, tank and friendly boss samples with their own size, colour and wrap.
	do
		local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
		parent:SetSize(300, 520)
		local preview = K.Options.Preview(MODULE)(parent)
		write(env, K, "numbers.show", true)
		preview:Refresh()
		moved(preview.numbers[1], function() write(env, K, "numbers.x", 3); write(env, K, "numbers.y", 4); preview:Refresh() end, 3, 4, "the preview's group number")
		assert(preview.extras and not preview.extras.pets.holder:IsShown(), "no extra samples while their groups are off")
		for key, value in pairs({ ["pets.enabled"] = true, ["tanks.enabled"] = true, ["boss.display"] = "ALWAYS" }) do write(env, K, key, value) end
		preview:Refresh()
		local pet, tank, boss = preview.extras.pets[1], preview.extras.tanks[1], preview.extras.boss[1]
		assert(pet:IsVisible() and tank:IsVisible() and boss:IsVisible(), "a pet, a tank and a friendly boss sample")
		local raid = ns.Settings.current.raid
		write(env, K, "pets.width", 20)
		write(env, K, "tanks.height", 6)
		preview:Refresh()
		assert(near(pet:GetWidth(), raid.width + 20) and near(tank:GetHeight(), raid.height + 6), "each sample takes its group's size")
		write(env, K, "tanks.wrapAfter", 1)
		preview:Refresh()
		local x1, y1 = offset(preview.extras.tanks[1])
		local x2, y2 = offset(preview.extras.tanks[2])
		assert(near(y1, y2) and x2 > x1, "wrap after one puts the second tank beside the first")
		write(env, K, "pets.nameColor", "custom")
		write(env, K, "pets.color", { r = 1, g = 0, b = 0 })
		preview:Refresh()
		assert(select(1, pet.name:GetTextColor()) == 1 and select(2, pet.name:GetTextColor()) == 0, "the pet sample's name takes the custom colour")
		local fr, fg, fb = ns.Unit.ClassColor(boss.sample.class)
		local c = boss.health.colorRGBA
		assert(near(c[1], fr) and near(c[2], fg) and near(c[3], fb), "the boss sample's tile takes its class colour, as Medallions raid tiles do")
		write(env, K, "pets.enabled", false)
		preview:Refresh()
		assert(not preview.extras.pets.holder:IsShown(), "off hides the pet samples")
	end
	noErrors(env, K)
end
collectgarbage()

-- Without RegisterStateDriver, friendly boss frames refuse: nothing shows and Layout Mode has no element for them.
do
	local env, K, ns = boot({ setup = function(e) H.setup(e) e.RegisterStateDriver = nil end })
	for _, value in ipairs({ "ALWAYS", "NEVER" }) do
		write(env, K, "boss.display", value)
		local g = ns.Extras.groups.boss
		assert(g.failed and not g.holder:IsVisible() and not K.Layout.Live("groupframes.boss"), value .. ": the refused group stays out of sight and out of Layout Mode")
	end
	noErrors(env, K)
end
collectgarbage()

-- The extra groups sit in the raid's card with a titled cap while the raid has one, and bare when it has none; then every raid pet gets a frame, past ten.
do
	local env, K, ns = bootSecure()
	-- The extra groups sit in the raid's card with a titled cap while the raid has one, and bare when it has none.
	do
		G.SetRoster(env, "raid", G.Members(10, function(i, m) m.role = (i == 3 or i == 7) and "TANK" or m.role end))
		env._units.boss1 = { name = "Valithria", class = "DRUID", health = 50, maxHealth = 100, friend = true }
		env.RunTimers()
		write(env, K, "tanks.enabled", true)
		write(env, K, "boss.display", "ALWAYS")
		env.RunStateDrivers()
		for _, name in ipairs({ "tanks", "boss" }) do
			local g = ns.Extras.groups[name]
			local card = g.card
			assert(card and card.frame:IsVisible() and card.cap.frame:IsVisible(), name .. ": the raid's card and cap")
			local tile = name == "tanks" and g.header:GetAttribute("child1") or g.buttons[1]
			local x, y, w, h = Scene.Rect(env, card.frame)
			local tx, ty, tw, th = Scene.Rect(env, tile)
			assert(tx >= x and tx + tw <= x + w and ty >= y and ty + th <= y + h, name .. ": the card holds its frames")
			local hx, hy, hw, hh = Scene.Rect(env, g.holder)
			assert(x >= hx - 1e-3 and x + w <= hx + hw + 1e-3 and y >= hy - 1e-3 and y + h <= hy + hh + 1e-3, name .. ": Layout Mode's box holds the card")
		end
		write(env, K, "pets.enabled", true)
		env.RunStateDrivers()
		assert(ns.Extras.groups.pets.header:IsVisible() and not ns.Extras.groups.pets.card.frame:IsVisible(), "a raid without pets shows no empty pet card")
		write(env, K, "raid.card", false)
		env.RunStateDrivers()
		assert(not ns.Extras.groups.tanks.card.frame:IsShown() and not ns.Extras.groups.boss.card.frame:IsShown(), "no raid card, no extra cards")
	end
	-- Every raid pet gets a frame, past ten.
	do
		for i = 1, 12 do env._units["raidpet" .. i] = { name = "Pet" .. i, class = "HUNTER", health = 50, maxHealth = 50 } end
		G.SetRoster(env, "raid", G.Members(20))
		env.RunTimers()
		write(env, K, "pets.enabled", true)
		env.RunStateDrivers()
		local units = shownUnits(ns.Extras.groups.pets.header)
		assert(select(2, units:gsub("raidpet", "")) == 12, "twelve raid pets, twelve frames: " .. units)
	end
	noErrors(env, K)
end
collectgarbage()

print("groupframes parity round 5 review ok: friendly bosses that follow their faction, extra groups in the raid's card, every raid pet, boss debuff zoom, time left inside its clip, switched-off groups at rest, a refused boss group and the extra groups' preview")
