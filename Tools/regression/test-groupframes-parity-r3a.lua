-- test-groupframes-parity-r3a.lua: EllesmereUI parity round 3a: a v0.2.8 profile keeps every default and makes nothing new; each new option switched on applies, follows its events, reaches the preview and switches back.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local A = dofile("Tools/regression/auras_env.lua")
local G, MODULE, FORTITUDE, INTELLECT = H.G, H.MODULE, H.FORTITUDE, H.INTELLECT
local setup, write, text, formatted, frame, noErrors, party, width, shown, icon = H.setup, H.write, H.text, H.formatted, H.frame, H.noErrors, H.party, H.width, H.shown, H.icon

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

-- A v0.2.8-shaped profile keeps every default and builds none of the new parts.
do
	local env, K, ns = G.New({ saved = saved({ party = { width = 259 }, auras = { enabled = true } }), setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local get = ns.Settings.Get
	assert(get("reminders.place") == "NONE" and get("status.place") == "AUTO" and get("dispel.icon") == "NONE" and get("dispel.iconBorder") == true
		and get("dispel.custom") == false and get("names.align") == "AUTO" and get("names.divider") == false and get("numbers.show") == false
		and get("mana.mode") == "NONE" and get("label.enabled") == false, "every new option starts at today's look")
	ns.Unit.ForEach(function(f)
		assert(f.reminder == nil and f.nameDivider == nil and f.typeSlot == nil and not f.statusPinned, "no new part is made by default")
	end)
	local tank = frame(ns, "party1")
	assert(tank.name:GetJustifyH() == "LEFT", "names keep their place")
	assert(not K.Layout.Element("groupframes.mana") and not K.Layout.Element("groupframes.label"), "no new mover until switched on")
	assert(not tank:IsEventRegistered("UNIT_AURA"), "no aura event while missing buffs are off")
	noErrors(env, K)
end
collectgarbage()

-- Missing buffs: the first buff you know that a member lacks, refreshed by aura, role, spell and secrecy events.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "reminders.place", "TOP")
	local tank, healer, player = frame(ns, "party1"), frame(ns, "party2"), frame(ns, "player")
	assert(tank:IsEventRegistered("UNIT_AURA"), "switched on, frames follow their auras")
	assert(shown(tank) and icon(tank) == 101243, "Fortitude shows first")
	local point, rel, relPoint = tank.reminder:GetPoint(1)
	assert(point == "TOP" and rel == tank.health and relPoint == "TOP", "on the health bar at the chosen place")
	assert(math.abs(width(env, tank.reminder) - math.min(14, H.reveal(env, tank.health:GetHeight()))) < 1, "at the chosen size, never past the bar")
	env._buffs.party1 = { [FORTITUDE] = true }
	env.FireEvent("UNIT_AURA", "party1")
	assert(shown(tank) and icon(tank) == 100467, "a rage user skips Arcane Intellect and gets Thorns")
	env._buffs.party2 = { ["Prayer of Fortitude"] = true }
	env.FireEvent("UNIT_AURA", "party2")
	assert(icon(healer) == 101459, "the group version counts, and a mana user gets Arcane Intellect")
	write(env, K, "reminders.thornsTank", true)
	env._buffs.party2[INTELLECT] = true
	env.FireEvent("UNIT_AURA", "party2")
	assert(not shown(healer) and shown(tank) and icon(tank) == 100467, "Thorns only on the tank")
	write(env, K, "reminders.thorns", false)
	assert(not shown(tank), "a buff switched off stops showing")
	write(env, K, "reminders.thorns", true)
	env._roster.units.party1.role = "DAMAGER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	env._buffs.player = { [FORTITUDE] = true, [INTELLECT] = true }
	env.FireEvent("UNIT_AURA", "player")
	assert(not shown(tank) and shown(player) and icon(player) == 100467, "with no tank, Thorns shows on you")
	env._aurasSecret = true
	env.SetCombat(true)
	env.FireEvent("PLAYER_REGEN_DISABLED")
	assert(not shown(player), "secret auras hide the reminder rather than guess")
	env.FireEvent("UNIT_AURA", "player")
	assert(not shown(player), "and an aura change while secret reads nothing")
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(shown(player), "readable again when combat ends")
	env._known[467] = nil
	env.FireEvent("SPELLS_CHANGED")
	assert(not shown(player), "a buff you no longer know never shows")
	write(env, K, "reminders.place", "NONE")
	ns.Unit.ForEach(function(f) assert(not shown(f), "off hides every reminder") end)
	assert(not tank:IsEventRegistered("UNIT_AURA"), "and stops following auras")
	noErrors(env, K)
end
collectgarbage()

-- Status text placement: Dead and Offline move onto the bar at their own size and come back.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party3")
	local before = { f.healthText:GetPoint(1) }
	write(env, K, "status.place", "BOTTOM")
	write(env, K, "status.size", 18)
	env._roster.units.party3.dead = true
	env.FireEvent("UNIT_HEALTH", "party3")
	local point, rel = f.healthText:GetPoint(1)
	assert(point == "BOTTOM" and rel == f.health and f.healthText:IsShown(), "Dead sits on the bar's bottom")
	local _, size = f.healthText:GetFont()
	assert(size == 18, "at its own size, got " .. tostring(size))
	env._roster.units.party3.dead = false
	env.FireEvent("UNIT_HEALTH", "party3")
	local again = { f.healthText:GetPoint(1) }
	assert(again[1] == before[1] and again[2] == before[2] and again[3] == before[3], "alive again, the health text returns")
	write(env, K, "status.place", "AUTO")
	env._roster.units.party3.online = false
	env.FireEvent("UNIT_CONNECTION", "party3")
	assert(f.healthText:GetPoint(1) ~= "BOTTOM" and not f.statusPinned, "Automatic keeps Offline beside the name")
	noErrors(env, K)
end
collectgarbage()

-- Dispel type icon, debuff type borders and own dispel colours.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	assert(f.highlights._slots.dispelType == nil, "no type slot until switched on")
	write(env, K, "auras.dispelHighlight", false)
	write(env, K, "dispel.icon", "TOPRIGHT")
	local slot = f.highlights._slots.dispelType
	assert(slot and slot.enabled and f.highlights:IsShown(), "the type icon has its own slot, even with the highlight off")
	local entry = slot.frame._aura.dispel[1]
	assert(entry.texture == f.typeIcon and entry.options.customDispelAssetMap.Magic, "it shows KstyleUI's type letter")
	local point, rel = f.typeIcon:GetPoint(1)
	assert(point == "TOPRIGHT" and rel == f.health and math.abs(width(env, f.typeIcon) - math.min(14, H.reveal(env, f.health:GetHeight()))) < 1, "on the bar at the chosen place and size")
	A.Assign(env, f.auras, "debuffs", 1)
	env.RunTimers()
	local button = f.auras._groups.debuffs.frames[1]
	local function tinted(owner)
		for _, each in ipairs(owner._aura.dispel) do
			if each.options.style == env.Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset then return each.options.customDispelColorMap ~= nil, true end
		end
		return false, false
	end
	local custom, border = tinted(button)
	assert(border and not custom, "debuff icons keep the game's type border")
	write(env, K, "auras.dispelHighlight", true)
	write(env, K, "dispel.custom", true)
	write(env, K, "dispel.magic", { r = 1, g = 0, b = 0 })
	custom = tinted(button)
	assert(custom, "own colours reach the debuff borders")
	assert(tinted(f.dispelFrame), "and the highlight")
	for _, each in ipairs(f.dispelFrame._aura.dispel) do
		assert(each.texture ~= f.dispelRing[1][5] and each.texture ~= f.dispelRing[2][5], "a retint gives the engine only a ring line's eight edge pieces; it shows every dispel texture it holds")
	end
	local map = f.dispelFrame._aura.dispel[1].options.customDispelColorMap
	assert(select(1, map.Magic:GetRGBA()) == 1, "in the colour chosen")
	assert(slot.frame._aura.dispel[1].options.customDispelColorMap, "and the type letter")
	write(env, K, "dispel.iconBorder", false)
	assert(not select(2, tinted(button)), "the type border can be switched off")
	write(env, K, "dispel.iconBorder", true)
	write(env, K, "dispel.custom", false)
	custom, border = tinted(button)
	assert(border and not custom and not tinted(f.dispelFrame), "switched back, the game's colours return")
	write(env, K, "dispel.icon", "NONE")
	assert(not slot.enabled, "off stops the type slot")
	noErrors(env, K)
end
collectgarbage()

-- Names above the bar: alignment and divider.
do
	local env, K, ns = G.New({ setup = setup })
	party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party2")
	write(env, K, "names.align", "CENTER")
	assert(f.name:GetJustifyH() == "CENTER", "names centre above the bar")
	write(env, K, "names.divider", true)
	local line = f.nameDivider
	assert(line and line:IsShown() and math.abs(width(env, line) - width(env, f.health)) < 1, "the divider spans the bar")
	write(env, K, "names.dividerAccent", true)
	local r, g, b = ns.Style.Accent()
	local c = A.W.LastCall(line, "SetColorTexture")
	assert(c and math.abs(c[1] - r) < 1e-6 and math.abs(c[2] - g) < 1e-6 and math.abs(c[3] - b) < 1e-6, "in the highlight colour")
	write(env, K, "party.textLayout", "INSIDE")
	assert(not line:IsShown(), "no divider for names on the bar")
	write(env, K, "party.textLayout", "ABOVE")
	write(env, K, "names.divider", false)
	write(env, K, "names.align", "AUTO")
	assert(not line:IsShown() and f.name:GetJustifyH() == "LEFT", "off restores today's names")
	noErrors(env, K)
end
collectgarbage()

-- Group numbers, healer mana and your group label in a raid.
do
	local env, K, ns = G.New({ setup = function(env)
		setup(env)
		env.GROUP_NUMBER = "Group %d"
	end })
	local members = G.Members(8, function(i, m)
		m.role = (i == 2 or i == 7) and "HEALER" or "DAMAGER"
	end)
	G.SetRoster(env, "raid", members, { name = "Tester", class = "HUNTER" })
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local Headers = ns.Headers
	write(env, K, "numbers.show", true)
	local one, two, three = Headers.raid[1].kstyleNumber, Headers.raid[2].kstyleNumber, Headers.raid[3].kstyleNumber
	assert(one:IsShown() and one:GetText() == 1 and two:IsShown() and not (three and three:IsShown()), "groups with members are numbered")
	env.SetCombat(true)
	members[11] = { name = "Late", class = "MAGE", role = "DAMAGER", health = 90, maxHealth = 100 }
	for i = 9, 10 do members[i] = { name = "Filler" .. i, class = "ROGUE", health = 90, maxHealth = 100 } end
	G.SetRoster(env, "raid", members)
	env.RunTimers()
	local now = Headers.raid[3].kstyleNumber
	assert(#env._blocked == 0 and now and now:IsShown() and now:GetText() == 3, "a group filled in combat gets its number with no protected call")
	env.SetCombat(false)
	write(env, K, "numbers.size", 14)
	assert(select(2, one:GetFont()) == 14, "at the chosen size")
	write(env, K, "raid.sortBy", "ROLE")
	assert(not one:IsShown(), "no numbers without groups")
	write(env, K, "raid.sortBy", "GROUP")
	write(env, K, "numbers.show", false)
	assert(not one:IsShown(), "off hides them")

	write(env, K, "mana.mode", "RAID")
	local el = K.Layout.Element("groupframes.mana")
	assert(el and K.Layout.Live("groupframes.mana"), "the healer list is a live mover once on")
	local rows = el.frame.rows
	assert(rows[1]:IsShown() and rows[2]:IsShown() and not (rows[3] and rows[3]:IsShown()), "one line for each healer")
	assert(text(env, rows[1].text):find("Member2", 1, true) and text(env, rows[1].text):find("50%", 1, true), "with the name in a raid and the mana")
	members[2].power = 20
	env.FireEvent("UNIT_POWER_UPDATE", "raid2")
	assert(text(env, rows[1].text):find("20%", 1, true), "mana follows its events")
	write(env, K, "mana.names", false)
	assert(text(env, rows[1].text) == "20%", "names can be left out")
	write(env, K, "mana.mode", "PARTY")
	assert(not el.frame:IsShown() and not K.Layout.Live("groupframes.mana"), "a party-only list hides in a raid")
	write(env, K, "mana.mode", "NONE")
	assert(not el.frame:IsShown(), "off hides it")

	write(env, K, "label.enabled", true)
	local label = K.Layout.Element("groupframes.label").frame
	assert(label:IsShown() and formatted(env, label.text) == "Group 1", "your group with the word Group")
	write(env, K, "label.format", "NUMBER")
	assert(tostring(text(env, label.text)) == "1", "or the number alone")
	-- A raid sends GROUP_ROSTER_UPDATE in bursts; the readouts refresh once per frame, with the roster.
	local labelled = #label.text._calls
	for _ = 1, 10 do env.FireEvent("GROUP_ROSTER_UPDATE") end
	env.RunTimers()
	local refreshes = 0
	for i = labelled + 1, #label.text._calls do
		if label.text._calls[i].method:find("^Set.*Text$") then refreshes = refreshes + 1 end
	end
	assert(refreshes == 1 and tostring(text(env, label.text)) == "1", "a burst of 10 roster updates refreshed the group label " .. refreshes .. " times; refresh the readouts with the roster flush, once a frame (KstyleUI_GroupFrames/Readouts.lua)")
	G.SetRoster(env, "party", { members[1] })
	env.RunTimers()
	assert(not label:IsShown(), "no label outside a raid")
	write(env, K, "label.enabled", false)
	noErrors(env, K)
end
collectgarbage()

-- The preview follows the new options.
do
	local env, K = G.New({ setup = setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	local preview = K.Options.Preview(MODULE)(parent)
	local healer = preview.partyFrames[2]
	assert(healer.sample.role == "HEALER" and healer.reminder == nil, "nothing new in the preview by default")
	write(env, K, "reminders.place", "TOPLEFT")
	write(env, K, "dispel.icon", "TOPRIGHT")
	write(env, K, "numbers.show", true)
	write(env, K, "mana.mode", "BOTH")
	write(env, K, "status.place", "TOP")
	write(env, K, "dispel.custom", true)
	preview:Refresh()
	local tank = preview.partyFrames[1]
	assert(tank.sampleAuras[1].typeBorder and tank.sampleAuras[1]:IsShown(), "own colours outline the sample debuffs")
	write(env, K, "dispel.iconBorder", false)
	preview:Refresh()
	for _, piece in ipairs(tank.sampleAuras[1].typeBorder) do assert(not piece:IsShown(), "and the border switches off") end
	assert(healer.reminder:IsShown(), "the sample healer misses a buff")
	assert(healer.sampleType and healer.sampleType:IsShown(), "and shows its debuff's type letter")
	assert(preview.numbers[1]:IsShown() and preview.numbers[1]:GetText() == 1, "the sample raid groups are numbered")
	assert(preview.mana:IsShown() and text(env, preview.mana.rows[1].text):find("80%", 1, true), "the healer mana list shows")
	local dead = preview.raidFrames[4]
	assert(dead.sample.dead and dead.healthText:GetPoint(1) == "TOP", "Dead moves onto the sample bar")
	write(env, K, "reminders.place", "NONE")
	write(env, K, "mana.mode", "NONE")
	preview:Refresh()
	assert(not healer.reminder:IsShown() and not preview.mana:IsShown(), "and back")
	noErrors(env, K)
end

print("groupframes parity round 3a ok: defaults, missing buffs, status text, dispel type icon and colours, names, group numbers, healer mana, group label and the preview")
