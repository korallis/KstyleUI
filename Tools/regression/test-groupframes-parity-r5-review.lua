-- test-groupframes-parity-r5-review.lua: the PR #654 review of EllesmereUI parity round 5: friendly bosses that follow their faction in combat, pet, tank and friendly boss frames clear of the raid at their default places and in its card, every raid pet, the boss debuff zoom, the time left inside its clip, switched-off groups at rest, a refused boss group and the extra groups' preview.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local A = dofile("Tools/regression/auras_env.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, noErrors = H.write, H.frame, H.noErrors
local Scene = dofile("Tools/render/scene.lua")

local function near(a, b)
	return math.abs(a - b) < 1e-3
end

local function offset(region)
	local _, _, _, x, y = region:GetPoint(1)
	return x, y
end

local function moved(region, write1, dx, dy, label)
	local x0, y0 = offset(region)
	write1()
	local x1, y1 = offset(region)
	assert(near(x1 - x0, dx) and near(y1 - y0, dy), label .. " moves " .. dx .. ", " .. dy .. ": got " .. (x1 - x0) .. ", " .. (y1 - y0))
end

local SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }

local function boot(setup, screen)
	local env, K, ns = G.New({ setup = setup or H.setup, width = screen and screen[1], height = screen and screen[2], uiScale = screen and 768 / 1080, size = screen and "auto" })
	if screen then
		local w, h = env.GetPhysicalScreenSize()
		assert(w == screen[1] and h == screen[2], "booted " .. w .. "x" .. h .. " for " .. screen[1] .. "x" .. screen[2])
	end
	H.party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	return env, K, ns
end

local function overlap(env, a, b)
	local r, s = { Scene.Rect(env, a) }, { Scene.Rect(env, b) }
	return math.min(r[1] + r[3], s[1] + s[3]) - math.max(r[1], s[1]), math.min(r[2] + r[4], s[2] + s[4]) - math.max(r[2], s[2])
end

local function bootSecure()
	return boot(function(env)
		H.setup(env)
		G.Secure(env)
		env._units = env._units or {}
		env.UnitCanAssist = function(_, unit) local m = env._member(unit) return m ~= nil and m.friend == true end
	end)
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
	noErrors(env, K)
end
collectgarbage()

-- Switched on at their default places, pet, tank and friendly boss frames clear the raid, the party and each other on every test screen,
-- with a ten-player raid and you healing (its frames are the largest), in the module's own layout and the first-run setup's.
for pass, screen in ipairs({ SCREENS[1], SCREENS[2], SCREENS[3], SCREENS[4], SCREENS[1] }) do
	do
		local env, K, ns = boot(function(e)
			H.setup(e)
			G.Secure(e)
			e._units = {}
			e.UnitCanAssist = function(_, unit) return unit == "boss1" end
		end, screen)
		if pass == 5 then assert(K.Setup.Apply(K.Setup.NewChoice())) end
		G.SetRoster(env, "raid", G.Members(10, function(i, m) if i <= 2 then m.role = "TANK" end end), { name = "Tester", class = "PRIEST", role = "HEALER" })
		for i = 1, 3 do env._units["raidpet" .. i] = { name = "Fang", class = "HUNTER", health = 50, maxHealth = 50 } end
		env._units.boss1 = { name = "Valithria", class = "DRUID", health = 41, maxHealth = 100 }
		env.RunTimers()
		for key, value in pairs({ ["tanks.enabled"] = true, ["pets.enabled"] = true, ["boss.display"] = "ALWAYS" }) do write(env, K, key, value) end
		env.RunStateDrivers()
		local keys = { "groupframes.raid", "groupframes.party", "groupframes.tanks", "groupframes.pets", "groupframes.boss" }
		for i = 3, #keys do
			local l, b, w, h = K.Layout.Rect(keys[i])
			for j = 1, i - 1 do
				local l2, b2, w2, h2 = K.Layout.Rect(keys[j])
				local ow, oh = math.min(l + w, l2 + w2) - math.max(l, l2), math.min(b + h, b2 + h2) - math.max(b, b2)
				assert(ow <= 0 or oh <= 0, screen[1] .. "x" .. screen[2] .. ": " .. keys[i] .. " covers " .. keys[j] .. " by " .. ow .. " x " .. oh)
			end
		end
		local shown = {}
		ns.Unit.ForEach(function(f) if f.unit and f:IsVisible() then shown[#shown + 1] = f end end)
		for i, a in ipairs(shown) do
			for j = i + 1, #shown do
				local b = shown[j]
				if (a.extra or a.kind) ~= (b.extra or b.kind) then
					local w, h = overlap(env, a, b)
					assert(w <= 0 or h <= 0, screen[1] .. "x" .. screen[2] .. ": " .. (a.extra or a.kind) .. " " .. a.unit .. " covers " .. (b.extra or b.kind) .. " " .. b.unit)
				end
			end
		end
		noErrors(env, K)
	end
	collectgarbage()
end

-- Every raid pet gets a frame, past ten.
do
	local env, K, ns = bootSecure()
	G.SetRoster(env, "raid", G.Members(20))
	for i = 1, 12 do env._units["raidpet" .. i] = { name = "Pet" .. i, class = "HUNTER", health = 50, maxHealth = 50 } end
	env.RunTimers()
	write(env, K, "pets.enabled", true)
	env.RunStateDrivers()
	local units = shownUnits(ns.Extras.groups.pets.header)
	assert(select(2, units:gsub("raidpet", "")) == 12, "twelve raid pets, twelve frames: " .. units)
	noErrors(env, K)
end
collectgarbage()

-- Boss debuff zoom reaches the live boss debuff icon, as it does the preview's.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	write(env, K, "auras.zoomEach", true)
	write(env, K, "auras.bossZoom", 0.19)
	local p = ns.Auras.Parts(f.highlights:GetAuraSlotFrame("boss"))
	assert(near((p.icon:GetTexCoord()), 0.19), "the boss debuff crops at its own zoom: " .. p.icon:GetTexCoord())
	write(env, K, "auras.zoomEach", false)
	assert(near((p.icon:GetTexCoord()), 0.07), "off restores the shared zoom")
	noErrors(env, K)
end
collectgarbage()

-- The time left stays inside the heal icons' clip at every offset the sliders allow; at no offset, "12s" is a twentieth of a
-- unit wider than its 11-unit icon, so the sides allow a tenth.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
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
	noErrors(env, K)
end
collectgarbage()

-- Friendly boss frames switched to Never and pet frames switched off stop listening and painting, and are not laid out again.
do
	local env, K, ns = bootSecure()
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
	local set = header.SetAttribute
	header.SetAttribute = function(...) writes = writes + 1 return set(...) end
	ns.Frames.Apply()
	header.SetAttribute = set
	assert(writes == 0, "an apply leaves the switched-off pet header alone: " .. writes .. " writes")
	noErrors(env, K)
end
collectgarbage()

-- Without RegisterStateDriver, friendly boss frames refuse: nothing shows and Layout Mode has no element for them.
do
	local env, K, ns = boot(function(e) H.setup(e) e.RegisterStateDriver = nil end)
	for _, value in ipairs({ "ALWAYS", "NEVER" }) do
		write(env, K, "boss.display", value)
		local g = ns.Extras.groups.boss
		assert(g.failed and not g.holder:IsVisible() and not K.Layout.Live("groupframes.boss"), value .. ": the refused group stays out of sight and out of Layout Mode")
	end
	noErrors(env, K)
end
collectgarbage()

-- The preview follows the group number offsets and shows pet, tank and friendly boss samples with their own size, colour and wrap.
do
	local env, K, ns = G.New({ setup = H.setup })
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
	local fr, fg, fb = K.Tokens.Color("friendly")
	local c = boss.health.colorRGBA
	assert(near(c[1], fr) and near(c[2], fg) and near(c[3], fb), "the boss sample's bar takes the friendly colour")
	write(env, K, "pets.enabled", false)
	preview:Refresh()
	assert(not preview.extras.pets.holder:IsShown(), "off hides the pet samples")
	noErrors(env, K)
end
collectgarbage()

-- The extra groups sit in the raid's card with a titled cap while the raid has one, and bare when it has none.
do
	local env, K, ns = bootSecure()
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
	noErrors(env, K)
end
collectgarbage()
print("groupframes parity round 5 review ok: friendly bosses that follow their faction, extra groups clear of the raid in its card, every raid pet, boss debuff zoom, time left inside its clip, switched-off groups at rest, a refused boss group and the extra groups' preview")
