-- test-groupframes-parity-r5.lua: EllesmereUI parity round 5: the Medallions party heal icons clear of the indicator lane and the percent on every test screen; v0.2.8 profiles keep every new default; class order per kind, offsets, texts above icons, backings, zooms, tooltips and indicator offsets apply when on, follow combat and secrecy, reach the preview and switch back.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local A = dofile("Tools/regression/auras_env.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, noErrors = H.write, H.frame, H.noErrors
local Scene = dofile("Tools/render/scene.lua")

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

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

-- Party heal icons clear the percent and every default indicator lane spot at all four screens, and Medallions names clear the indicators.
do
	for _, screen in ipairs(SCREENS) do
		for _, style in ipairs({ "frames", "medallions" }) do
			local env, K, ns = boot(nil, screen)
			K.Options.Write("HudStyle", "style", style)
			env.RunTimers()
			for _, unit in ipairs({ "player", "party1" }) do
				local f = frame(ns, unit)
				local at = style .. " " .. screen[1] .. "x" .. screen[2] .. " " .. unit
				local w0, h0 = overlap(env, f.buffClip, f.healthText)
				assert(w0 <= 0 or h0 <= 0, at .. ": the heal icons cover the percent by " .. w0 .. " x " .. h0)
				for i = 1, 3 do
					local indicator = f.indicators._slots["indicator" .. i]
					indicator.frame:Show()
					local w, h = overlap(env, f.buffClip, indicator.frame)
					assert(indicator.enabled and (w <= 0 or h <= 0), at .. ": the heal icons cover indicator " .. i .. " by " .. w .. " x " .. h)
					if style == "medallions" then
						w, h = overlap(env, f.name, indicator.frame)
						assert(w <= 0 or h <= 0, at .. ": indicator " .. i .. " covers the name by " .. w .. " x " .. h)
						w, h = overlap(env, f.healthText, indicator.frame)
						assert(w <= 0 or h <= 0, at .. ": indicator " .. i .. " covers the percent by " .. w .. " x " .. h)
					end
				end
			end
			noErrors(env, K)
			collectgarbage()
		end
	end
end

-- A v0.2.8-shaped profile keeps every new default and builds nothing new.
do
	local env, K, ns = G.New({ saved = saved({ party = { width = 259 }, sort = { classFirst = true } }), setup = H.setup })
	H.party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local get = ns.Settings.Get
	assert(get("sort.classFirstIn") == "BOTH" and get("sort.partyOwn") == false, "class first serves both kinds from one list")
	for i, class in ipairs(env.CLASS_SORT_ORDER) do assert(get("sort.partyClass" .. i) == class, "the party list starts as the game's order") end
	assert(get("icons.leaderX") == 0 and get("names.y") == 0 and get("numbers.x") == 0 and get("indicator1.x") == 0, "offsets start at 0")
	assert(get("text.aboveName") and get("text.aboveHealth") and get("text.aboveExtra") and get("prediction.backingOwn") == false, "texts and backings keep today's rule")
	assert(get("auras.zoomEach") == false and get("buffs.zoom") == 0.07 and get("auras.tipCursor") == false and get("auras.countX") == 0 and get("auras.timerY") == 0, "icons keep today's look")
	local f = frame(ns, "party1")
	assert(f.textTop == nil, "nothing new is made")
	assert(ns.Headers.party:GetAttribute("groupBy") == "CLASS", "a round 4 class first keeps sorting party frames")
	noErrors(env, K)
end
collectgarbage()

-- Class first per kind and an own party class order, in and out of combat.
do
	local env, K, ns = boot()
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	local party, raid = ns.Headers.party, ns.Headers.raid[1]
	write(env, K, "sort.classFirst", true)
	write(env, K, "sort.classFirstIn", "RAID")
	assert(party:GetAttribute("groupBy") == nil and raid:GetAttribute("groupBy") == "CLASS", "raid frames only")
	write(env, K, "sort.classFirstIn", "PARTY")
	assert(party:GetAttribute("groupBy") == "CLASS" and raid:GetAttribute("groupBy") == nil, "party frames only")
	write(env, K, "sort.partyOwn", true)
	write(env, K, "sort.partyClass1", "DRUID")
	assert(party:GetAttribute("groupingOrder"):match("^DRUID,") and ns.Settings.Get("sort.class1") == env.CLASS_SORT_ORDER[1], "the party list leads with the druid; the raid list is untouched")
	local druidAt
	for i, class in ipairs(env.CLASS_SORT_ORDER) do if class == "DRUID" then druidAt = i end end
	assert(ns.Settings.Get("sort.partyClass" .. druidAt) == env.CLASS_SORT_ORDER[1], "the displaced class takes the druid's old place")
	env.SetCombat(true)
	write(env, K, "sort.partyOwn", false)
	assert(party:GetAttribute("groupingOrder"):match("^DRUID,") and #env._blocked == 0, "combat waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(party:GetAttribute("groupingOrder"):match("^" .. env.CLASS_SORT_ORDER[1] .. ","), "off, party frames follow the main list after combat")
	write(env, K, "sort.classFirstIn", "BOTH")
	assert(party:GetAttribute("groupBy") == "CLASS" and raid:GetAttribute("groupBy") == "CLASS", "both again")
	write(env, K, "sort.classFirst", false)
	assert(party:GetAttribute("groupBy") == nil and raid:GetAttribute("groupBy") == nil, "off restores group order")
	noErrors(env, K)
end
collectgarbage()

-- The preview sorts its party samples by the party's own order only.
do
	local env, K = G.New({ setup = H.setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	local preview = K.Options.Preview(MODULE)(parent)
	local function lead(list)
		local top
		for _, f in ipairs(list) do if not top or select(5, f:GetPoint(1)) > select(5, top:GetPoint(1)) or (select(5, f:GetPoint(1)) == select(5, top:GetPoint(1)) and select(4, f:GetPoint(1)) < select(4, top:GetPoint(1))) then top = f end end
		return top.sample.name
	end
	local partyLead, raidLead = lead(preview.partyFrames), lead(preview.raidFrames)
	write(env, K, "sort.classFirst", true)
	write(env, K, "sort.classFirstIn", "PARTY")
	write(env, K, "sort.partyOwn", true)
	write(env, K, "sort.partyClass1", "DRUID")
	preview:Refresh()
	assert(lead(preview.partyFrames) == "Sylaen" and lead(preview.raidFrames) == raidLead, "the druid sample leads the party samples only")
	write(env, K, "sort.classFirst", false)
	preview:Refresh()
	assert(lead(preview.partyFrames) == partyLead, "off restores the samples")
	noErrors(env, K)
end
collectgarbage()

-- Leader, role (in its lane), name and group number offsets move each from its place, and 0 restores it.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	moved(f.leader, function() write(env, K, "icons.leaderX", 6); write(env, K, "icons.leaderY", -3) end, 6, -3, "the leader icon")
	moved(f.leader, function() write(env, K, "icons.leaderX", 0); write(env, K, "icons.leaderY", 0) end, -6, 3, "the leader icon back")
	moved(f.role, function() write(env, K, "icons.roleX", 4) end, 4, 0, "the role icon in its lane")
	write(env, K, "icons.roleX", 0)
	moved(f.name, function() write(env, K, "names.x", 5); write(env, K, "names.y", 2) end, 5, 2, "the name")
	moved(f.name, function() write(env, K, "names.x", 0); write(env, K, "names.y", 0) end, -5, -2, "the name back")
	write(env, K, "icons.roleText", true)
	moved(f.roleLetter, function() write(env, K, "icons.roleX", -2) end, -2, 0, "the role letter")
	write(env, K, "icons.roleX", 0)
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	write(env, K, "numbers.show", true)
	local label = ns.Headers.raid[1].kstyleNumber
	moved(label, function() write(env, K, "numbers.x", 3); write(env, K, "numbers.y", 4) end, 3, 4, "the group number")
	moved(label, function() write(env, K, "numbers.x", 0); write(env, K, "numbers.y", 0) end, -3, -4, "the group number back")
	noErrors(env, K)
end
collectgarbage()

-- Text above icons for each text, and off restores the text layer.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	write(env, K, "text.above", true)
	assert(f.name:GetParent() == f.textTop and f.healthText:GetParent() == f.textTop, "both rise")
	write(env, K, "text.aboveHealth", false)
	assert(f.name:GetParent() == f.textTop and f.healthText:GetParent() == f.text, "the health text stays under the icons")
	write(env, K, "party.extra1", { font = "", size = 12, outline = "OUTLINE", colorMode = "", color = { r = 1, g = 1, b = 1 }, textFormat = "[name]", position = "CENTER", x = 0, y = 0 })
	write(env, K, "text.aboveExtra", false)
	assert(f.extra1 and f.extra1:GetParent() == f.text, "extra texts stay under")
	write(env, K, "text.aboveExtra", true)
	assert(f.extra1:GetParent() == f.textTop, "and rise again")
	write(env, K, "text.above", false)
	assert(f.name:GetParent() == f.text and f.healthText:GetParent() == f.text and f.extra1:GetParent() == f.text, "off restores the text layer")
	noErrors(env, K)
end
collectgarbage()

-- Own backings for heal absorbs and lost maximum health; the shield keeps the shared backing.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	for key, value in pairs({ ["prediction.absorbStyle"] = "STRIPES", ["prediction.healAbsorbStyle"] = "STRIPES", ["prediction.maxLoss"] = "STRIPES", ["prediction.backing"] = 0.5 }) do write(env, K, key, value) end
	local p = ns.Settings.current.prediction
	local heal, shield, loss = p.healAbsorbColor.a, p.absorbColor.a, p.maxLossColor.a
	assert(near(f.healAbsorbs.colorRGBA[4], heal * 0.5) and near(f.maxLoss.colorRGBA[4], loss * 0.5), "today: one backing")
	write(env, K, "prediction.backingOwn", true)
	write(env, K, "prediction.healAbsorbBacking", 0.2)
	write(env, K, "prediction.maxLossBacking", 0)
	assert(near(f.healAbsorbs.colorRGBA[4], heal * 0.2) and near(f.maxLoss.colorRGBA[4], 0) and near(f.absorbs.colorRGBA[4], shield * 0.5), "each its own, the shield unchanged")
	write(env, K, "prediction.backingOwn", false)
	assert(near(f.healAbsorbs.colorRGBA[4], heal * 0.5) and near(f.maxLoss.colorRGBA[4], loss * 0.5), "off restores the shared backing")
	noErrors(env, K)
end
collectgarbage()

-- Zoom for each kind, tooltips at the cursor and the stack and time left offsets, waiting while auras are secret.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local debuff = f.auras._groups.debuffs.active[1]
	local heal = f.buffs._groups.buffs.frames[1]
	local pd, ph = ns.Auras.Parts(debuff), ns.Auras.Parts(heal)
	assert(debuff._aura.tooltip == nil, "no tooltip anchor call by default")
	write(env, K, "auras.zoomEach", true)
	write(env, K, "buffs.zoom", 0.15)
	assert(near((ph.icon:GetTexCoord()), 0.15) and near((pd.icon:GetTexCoord()), 0.07), "heal icons crop on their own")
	write(env, K, "auras.zoomEach", false)
	assert(near((ph.icon:GetTexCoord()), 0.07), "off restores the shared zoom")
	write(env, K, "auras.tipCursor", true)
	assert(debuff._aura.tooltip == "ANCHOR_CURSOR" and heal._aura.tooltip == "ANCHOR_CURSOR", "tooltips at the cursor")
	write(env, K, "auras.tipCursor", false)
	assert(debuff._aura.tooltip == "ANCHOR_BOTTOMLEFT", "off restores the engine's default anchor")
	write(env, K, "auras.timers", true)
	moved(pd.count, function() write(env, K, "auras.countX", 2); write(env, K, "auras.countY", 1) end, 2, 1, "the stack count")
	moved(pd.timer, function() write(env, K, "auras.timerY", -3) end, 0, -3, "the time left")
	local x0 = offset(pd.count)
	local secret = env.C_Secrets.ShouldAurasBeSecret
	env.C_Secrets.ShouldAurasBeSecret = function() return true end
	K.Options.Write(MODULE, "auras.countX", 0)
	assert(offset(pd.count) == x0, "a change while auras are secret waits")
	env.C_Secrets.ShouldAurasBeSecret = secret
	env.RunTimers()
	assert(offset(pd.count) ~= x0, "and applies once they are readable")
	noErrors(env, K)
end
collectgarbage()

-- Indicator offsets move an indicator from its place, in the frames and the preview.
do
	local env, K, ns = boot()
	local f = frame(ns, "party1")
	local button = f.indicators._slots.indicator3.frame
	moved(button, function() write(env, K, "indicator3.x", -4); write(env, K, "indicator3.y", 2) end, -4, 2, "indicator 3")
	moved(button, function() write(env, K, "indicator3.x", 0); write(env, K, "indicator3.y", 0) end, 4, -2, "indicator 3 back")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	local preview = K.Options.Preview(MODULE)(parent)
	local sample = preview.partyFrames[1].sampleSlots[3]
	moved(sample, function() write(env, K, "indicator3.x", 5); preview:Refresh() end, 5, 0, "the preview's indicator 3")
	noErrors(env, K)
end
collectgarbage()

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

-- Pet, tank and friendly boss frames: nothing is made until switched on; on, each follows its units, in and out of combat; off hides it.
do
	local env, K, ns = bootSecure()
	assert(next(ns.Extras.groups) == nil, "no extra group is made by default")
	env._units.pet = { name = "Wolf", class = "HUNTER", health = 40, maxHealth = 50 }
	env._units.partypet1 = { name = "Imp", class = "WARLOCK", health = 30, maxHealth = 30 }
	env.UpdateHeaders()
	write(env, K, "pets.enabled", true)
	local pets = ns.Extras.groups.pets
	env.RunStateDrivers()
	assert(pets.holder:IsShown() and shownUnits(pets.header) == "pet,partypet1", "your pet and the party's pets: " .. shownUnits(pets.header))
	local imp = ns.Button.Content(pets.header:GetAttribute("child2"))
	assert(imp.extra == "pets" and imp.unit == "partypet1", "a pet frame follows its pet")
	local r, g, b = imp.name:GetTextColor()
	write(env, K, "pets.nameColor", "custom")
	write(env, K, "pets.color", { r = 1, g = 0, b = 0 })
	assert(select(1, imp.name:GetTextColor()) == 1 and select(2, imp.name:GetTextColor()) == 0, "a custom pet name colour")
	write(env, K, "pets.nameColor", "raid")
	local r2, g2, b2 = imp.name:GetTextColor()
	assert(r2 == r and g2 == g and b2 == b, "like the raid frames restores the colour")
	local width = imp:GetWidth()
	write(env, K, "pets.width", 20)
	assert(math.abs(imp:GetWidth() - width - 20) < 1, "extra width widens the pet frames")
	env.SetCombat(true)
	write(env, K, "pets.enabled", false)
	assert(pets.holder:IsShown() and #env._blocked == 0, "combat waits")
	env.SetCombat(false)
	env.RunTimers()
	env.RunStateDrivers()
	assert(not pets.holder:IsShown() and not pets.header:IsShown(), "off hides the pets")
	noErrors(env, K)
end
collectgarbage()

do
	local env, K, ns = bootSecure()
	G.SetRoster(env, "raid", G.Members(10, function(i, m) m.role = (i == 3 or i == 7) and "TANK" or m.role end))
	env.RunTimers()
	write(env, K, "tanks.enabled", true)
	env.RunStateDrivers()
	local tanks = ns.Extras.groups.tanks
	assert(shownUnits(tanks.header) == "raid3,raid7", "the raid's tanks again: " .. shownUnits(tanks.header))
	assert(tanks.header:GetAttribute("roleFilter") == "MAINTANK,TANK", "through the header's role filter")
	write(env, K, "tanks.growth", "RIGHT")
	assert(tanks.header:GetAttribute("point") == "LEFT", "grow right")
	write(env, K, "tanks.wrapAfter", 1)
	write(env, K, "tanks.wrap", "DOWN")
	assert(tanks.header:GetAttribute("unitsPerColumn") == 1 and tanks.header:GetAttribute("columnAnchorPoint") == "TOP", "wrap after one, downward")
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100 } })
	env.RunTimers()
	env.RunStateDrivers()
	assert(shownUnits(tanks.header) == "", "a party shows no tank frames")
	write(env, K, "tanks.enabled", false)
	env.RunStateDrivers()
	assert(not tanks.holder:IsShown(), "off hides them")
	noErrors(env, K)
end
collectgarbage()

do
	local env, K, ns = bootSecure()
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	write(env, K, "boss.display", "ALWAYS")
	local boss = ns.Extras.groups.boss
	local b1, b2 = boss.buttons[1], boss.buttons[2]
	env._units.boss1 = { name = "Valithria", class = "DRUID", health = 50, maxHealth = 100, friend = true }
	env._units.boss2 = { name = "Lich", class = "MAGE", health = 90, maxHealth = 100 }
	env.SetCombat(true)
	env.RunStateDrivers()
	assert(b1:IsShown() and not b2:IsShown() and #env._blocked == 0, "a friendly boss shows in combat, a hostile one does not")
	env._units.boss1 = nil
	env.RunStateDrivers()
	assert(not b1:IsShown(), "and hides when it leaves")
	env.SetCombat(false)
	env._units.boss1 = { name = "Valithria", class = "DRUID", health = 50, maxHealth = 100, friend = true }
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100 } })
	env.RunTimers()
	env.RunStateDrivers()
	assert(not b1:IsShown(), "raids only by default")
	write(env, K, "boss.dungeons", true)
	env.RunStateDrivers()
	assert(b1:IsShown(), "Show in dungeons shows it in a party")
	local f = ns.Button.Content(b1)
	assert(f.extra == "boss" and f.unit == "boss1", "the frame follows boss1")
	write(env, K, "boss.colorSource", "raid")
	assert(select(1, ns.Unit.ColorSources(f)) == ns.Settings.current.health.colorSource, "like the raid frames")
	write(env, K, "boss.colorSource", "reaction")
	assert(select(1, ns.Unit.ColorSources(f)) == "reaction", "the friendly colour by default")
	write(env, K, "boss.display", "HEALERS")
	env.RunStateDrivers()
	assert(not b1:IsShown(), "while you heal: hidden while you do not")
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100 } }, { name = "Tester", class = "PRIEST", role = "HEALER" })
	env.RunTimers()
	env.RunStateDrivers()
	assert(b1:IsShown(), "and shown once you heal")
	ns.Headers.Stop()
	assert(not b1:IsShown() and not boss.holder:IsShown(), "the stand-down hides them")
	ns.Frames.Apply()
	env.RunStateDrivers()
	assert(b1:IsShown(), "and they return")
	write(env, K, "boss.display", "NEVER")
	env.RunStateDrivers()
	assert(not b1:IsShown() and not boss.holder:IsShown(), "never hides them")
	noErrors(env, K)
end
collectgarbage()

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

-- Switched on at their default places, pet, tank and friendly boss frames clear the raid, the party and each other on every test screen.
for _, screen in ipairs(SCREENS) do
	local env, K, ns = boot(function(e)
		H.setup(e)
		G.Secure(e)
		e._units = {}
		e.UnitCanAssist = function(_, unit) return unit == "boss1" end
	end, screen)
	G.SetRoster(env, "raid", G.Members(40, function(i, m) if i <= 2 then m.role = "TANK" end end))
	for i = 1, 12 do env._units["raidpet" .. i] = { name = "Fang", class = "HUNTER", health = 50, maxHealth = 50 } end
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

-- Friendly boss frames switched to Never stop listening and painting; pet frames switched off are not laid out again.
do
	local env, K, ns = bootSecure()
	G.SetRoster(env, "raid", G.Members(10))
	env.RunTimers()
	write(env, K, "boss.display", "ALWAYS")
	write(env, K, "pets.enabled", true)
	write(env, K, "boss.display", "NEVER")
	write(env, K, "pets.enabled", false)
	local f = ns.Button.Content(ns.Extras.groups.boss.buttons[1])
	assert(not f:IsEventRegistered("UNIT_HEALTH") and f.unit == nil, "Never leaves no boss unit or listener")
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

print("groupframes parity round 5 ok: the heal lane and Medallions names on four real screens, class order per kind, offsets, texts above icons, backings, zooms, tooltips, indicator offsets, friendly bosses that follow their faction, extra groups clear of the raid in its card, every raid pet, boss debuff zoom, time left inside its clip, switched-off groups at rest, a refused boss group and the extra groups' preview")
