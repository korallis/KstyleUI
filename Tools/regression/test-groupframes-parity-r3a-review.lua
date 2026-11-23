-- test-groupframes-parity-r3a-review.lua: the round 3a review's probes: missing buffs show only when absence is known, follow status and roles, and repeat no work; status text keeps its own size; switched-on icons and numbers never overlap; healer mana stands down for the gamepad; the preview shows each readout setting.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G, MODULE = H.G, H.MODULE
local write, frame, shown, icon, noErrors, reveal = H.write, H.frame, H.shown, H.icon, H.noErrors, H.reveal

local function setup(env)
	H.setup(env)
	env.InputUtil = { IsGamepadUIEnabled = function() return env._gamepad == true end }
end

local function font(region)
	return (select(2, region:GetFont()))
end

local function overlap(env, a, b)
	local ax, ay, aw, ah = env.Look(a:GetRect())
	local bx, by, bw, bh = env.Look(b:GetRect())
	return math.min(ax + aw, bx + bw) - math.max(ax, bx), math.min(ay + ah, by + bh) - math.max(ay, by)
end

local function counter(region, names)
	local calls = { n = 0 }
	for _, name in ipairs(names) do
		local fn = region[name]
		region[name] = function(...)
			calls.n = calls.n + 1
			return fn(...)
		end
	end
	return calls
end

-- Missing buffs: unknown is never missing, state is right on enable, on death and revival, and for every family.
do
	local env, K, ns = G.New({ setup = setup })
	H.party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local tank, healer, player = frame(ns, "party1"), frame(ns, "party2"), frame(ns, "player")
	write(env, K, "reminders.thornsTank", true)
	write(env, K, "reminders.place", "TOPLEFT")
	env._buffs.player = { [H.FORTITUDE] = true, [H.INTELLECT] = true }
	env.FireEvent("UNIT_AURA", "player")
	assert(not shown(player), "Thorns only on tanks, switched on in a party with a tank, never shows on you")

	assert(shown(tank) and icon(tank) == 101243, "the tank lacks Fortitude")
	local calls = counter(tank.reminder, { "Hide", "Show", "SetShown" })
	local paints = counter(tank.reminder.tile.icon, { "SetTexture" })
	for _ = 1, 25 do env.FireEvent("UNIT_AURA", "party1", { isFullUpdate = false, addedAuras = { { name = "unrelated" } } }) end
	assert(calls.n == 0 and paints.n == 0, "an unchanged missing buff repeats no work, got " .. calls.n .. " and " .. paints.n)

	env._roster.units.party1.dead = true
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(not shown(tank), "a dead member's reminder hides")
	env.FireEvent("UNIT_AURA", "party1")
	env._roster.units.party1.dead = false
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(shown(tank), "and returns on revival")

	env.C_Secrets.ShouldSpellAuraBeSecret = function(id) return id == 1243 end
	env.FireEvent("UNIT_AURA", "party1")
	assert(not shown(tank), "a buff whose aura is secret is unknown, not missing")
	env.C_Secrets.ShouldSpellAuraBeSecret = nil
	env.FireEvent("UNIT_AURA", "party1")
	assert(not shown(tank), "without the per-spell check nothing is known")
	env.C_Secrets.ShouldSpellAuraBeSecret = function() return false end
	local names = env.C_Spell.GetSpellName
	env.C_Spell.GetSpellName = function() return nil end
	env.FireEvent("SPELLS_CHANGED")
	assert(not shown(tank), "with no spell names to look up, nothing shows")
	env.C_Spell.GetSpellName = names
	env._known = { [21562] = true }
	env.FireEvent("SPELLS_CHANGED")
	assert(shown(tank) and icon(tank) == 121562, "knowing only Prayer of Fortitude reminds with it")

	env._known = { [1126] = true, [14752] = true, [1038] = true }
	write(env, K, "reminders.fortitude", false)
	write(env, K, "reminders.intellect", false)
	write(env, K, "reminders.thorns", false)
	env.FireEvent("SPELLS_CHANGED")
	assert(icon(tank) == 101126 and icon(healer) == 101126, "Mark of the Wild first")
	env._buffs.party1 = { ["Gift of the Wild"] = true }
	env._buffs.party2 = { ["Mark of the Wild"] = true }
	env.FireEvent("UNIT_AURA", "party1")
	env.FireEvent("UNIT_AURA", "party2")
	assert(not shown(tank), "a rage tank needs neither Divine Spirit nor Salvation")
	assert(icon(healer) == 114752, "a mana user lacks Divine Spirit")
	env._buffs.party2["Prayer of Spirit"] = true
	env.FireEvent("UNIT_AURA", "party2")
	assert(icon(healer) == 101038, "and then Salvation")
	write(env, K, "reminders.salvation", false)
	assert(not shown(healer), "Salvation switched off stops showing")

	write(env, K, "reminders.salvation", true)
	env._known = { [1459] = true, [467] = true }
	write(env, K, "reminders.intellect", true)
	write(env, K, "reminders.thorns", true)
	env.UnitPowerType, env.UnitIsUnit = nil, nil
	assert(pcall(ns.Unit.OnEvent, healer, "UNIT_AURA", "party2"), "a missing UnitPowerType or UnitIsUnit raises nothing")
	noErrors(env, K)
end
collectgarbage()

-- Party: status text size with the health text, icons that fit the bar side by side, own colours worked out once, and the gamepad.
do
	local env, K, ns = G.New({ setup = setup })
	H.party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local alive = font(f.healthText)
	write(env, K, "status.size", 24)
	assert(font(f.healthText) == alive, "the size waits for a status")
	env._roster.units.party1.dead = true
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(font(f.healthText) == 24, "Dead with the health text at its own size, got " .. tostring(font(f.healthText)))
	assert(H.width(env, f.healthText) == 0 or H.width(env, f.healthText) >= ns.Style.StatusWidth(f, 24), "with room for the whole word")
	env._roster.units.party1.dead = false
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(font(f.healthText) == alive, "alive again, the health text keeps its size")
	write(env, K, "party.textLayout", "INSIDE")
	alive = font(f.healthText)
	env._roster.units.party1.dead = true
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(font(f.healthText) == 24, "names on the bar too")
	env._roster.units.party1.dead = false
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(font(f.healthText) == alive, "and back")
	write(env, K, "party.textLayout", "ABOVE")

	write(env, K, "reminders.place", "TOPRIGHT")
	write(env, K, "dispel.icon", "TOPRIGHT")
	write(env, K, "reminders.size", 40)
	write(env, K, "dispel.iconSize", 40)
	local bar = reveal(env, f.health:GetHeight())
	assert(reveal(env, f.reminder:GetHeight()) <= bar and reveal(env, f.typeIcon:GetHeight()) <= bar, "both icons fit the bar")
	env._resolveRects = true
	for _, place in ipairs({ "TOPRIGHT", "TOP", "LEFT" }) do
		write(env, K, "reminders.place", place)
		write(env, K, "dispel.icon", place)
		local w, h = overlap(env, f.reminder, f.typeIcon)
		assert(w <= 0 or h <= 0, place .. ": the missing buff sits beside the dispel type icon")
	end
	env._resolveRects = nil

	write(env, K, "dispel.custom", true)
	local sorts, sort = 0, env.table.sort
	env.table.sort = function(...)
		sorts = sorts + 1
		return sort(...)
	end
	for _ = 1, 10 do ns.Auras.Restyle(f) end
	env.table.sort = sort
	assert(sorts == 0, "unchanged own colours are not worked out again, got " .. sorts .. " sorts")

	write(env, K, "mana.mode", "PARTY")
	local mana = K.Layout.Element("groupframes.mana").frame
	assert(mana:IsShown() and mana.rows[1]:IsEventRegistered("UNIT_POWER_UPDATE"), "the healer list shows in a party")
	env._gamepad = true
	env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
	env.RunTimers()
	assert(not ns.Frames.Active() and not mana:IsShown(), "the gamepad interface hides the healer list")
	assert(not mana.rows[1]:IsEventRegistered("UNIT_POWER_UPDATE"), "and stops its events")
	env._gamepad = false
	env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", 0, 1)
	env.RunTimers()
	assert(mana:IsShown() and mana.rows[1]:IsEventRegistered("UNIT_POWER_UPDATE"), "keyboard and mouse bring it back")
	noErrors(env, K)
end
collectgarbage()

-- Raid: group numbers keep their room and rest once off, Medallions status size, live healer mana and label settings.
do
	local env, K, ns = G.New({ setup = function(e)
		setup(e)
		e.GROUP_NUMBER = "Group %d"
	end })
	local members = G.Members(10, function(i, m) m.role = (i == 2 or i == 7) and "HEALER" or "DAMAGER" end)
	G.SetRoster(env, "raid", members)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "raid.groupsPerRow", 1)
	write(env, K, "raid.groupSpacing", 0)
	write(env, K, "numbers.show", true)
	write(env, K, "numbers.size", 30)
	local label = ns.Headers.raid[2].kstyleNumber
	env._resolveRects = true
	local _, header, _, _, oy = label:GetPoint(1)
	local hx, hy, hw, hh = env.Look(header:GetRect())
	local bottom = hy + hh + oy
	local mx, my, mw, mh = env.Look(frame(ns, "raid5"):GetRect())
	local first = ns.Headers.raid[1].kstyleNumber
	local _, top, _, _, ty = first:GetPoint(1)
	local _, fy, _, fh = env.Look(top:GetRect())
	local _, cap = env.Look(ns.Headers.cards.raid.cap.frame:GetRect())
	env._resolveRects = nil
	assert(fy + fh + ty + font(first) <= cap, "group 1's number sits under the card's cap, overlap " .. fy + fh + ty + font(first) - cap)
	local across = math.min(hx + hw / 2 + 0.5, mx + mw) - math.max(hx + hw / 2 - 0.5, mx)
	local up = math.min(bottom + font(label), my + mh) - math.max(bottom, my)
	assert(across <= 0 or up <= 0, "group 2's number sits clear of group 1, overlap " .. up)
	write(env, K, "raid.merge", true)
	assert(not label:IsShown(), "merged groups carry no group numbers")
	write(env, K, "raid.merge", false)
	write(env, K, "numbers.show", false)
	assert(not label:IsShown(), "off hides the numbers")
	local work = counter(label, { "SetShown", "SetText", "SetTextColor", "SetFont" })
	G.SetRoster(env, "raid", members)
	env.RunTimers()
	assert(work.n == 0, "and roster changes leave them alone, got " .. work.n)

	write(env, K, "mana.mode", "RAID")
	write(env, K, "mana.spacing", 6)
	write(env, K, "mana.growth", "UP")
	write(env, K, "mana.align", "RIGHT")
	write(env, K, "mana.colorSource", "custom")
	write(env, K, "mana.color", { r = 1, g = 0, b = 0 })
	local mana = K.Layout.Element("groupframes.mana").frame
	local step = 12 * 1.2 + 6
	local point, _, _, _, y = mana.rows[2]:GetPoint(1)
	assert(point == "BOTTOM" and math.abs(y - step) < 0.01, "lines grow up at the chosen spacing")
	assert(mana.rows[1].text:GetJustifyH() == "RIGHT", "aligned right")
	local r, g, b = mana.rows[1].text:GetTextColor()
	assert(r == 1 and g == 0 and b == 0, "in the custom colour")

	write(env, K, "label.enabled", true)
	write(env, K, "label.size", 20)
	write(env, K, "label.padding", 10)
	write(env, K, "label.color", { r = 0, g = 1, b = 0 })
	local plate = K.Layout.Element("groupframes.label").frame
	assert(font(plate.text) == 20, "the label at its size")
	assert(math.abs(reveal(env, plate:GetHeight()) - (20 * 1.2 + 20)) <= 1, "padded on its plate")
	r, g, b = plate.text:GetTextColor()
	assert(r == 0 and g == 1 and b == 0, "in its colour")

	env.RunTimers()
	write(env, K, "status.size", 24)
	local f = frame(ns, "raid1")
	local alive = font(f.healthText)
	members[1].dead = true
	env.FireEvent("UNIT_HEALTH", "raid1")
	assert(font(f.healthText) == 24, "a Medallions tile's Dead at its own size, got " .. tostring(font(f.healthText)))
	members[1].dead = false
	env.FireEvent("UNIT_HEALTH", "raid1")
	assert(font(f.healthText) == alive, "and back")
	noErrors(env, K)
end
collectgarbage()

-- The preview shows the label plate and the healer list as their settings draw them, and the game's type borders.
do
	local env, K = G.New({ setup = setup })
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	local preview = K.Options.Preview(MODULE)(parent)
	local tank = preview.partyFrames[1]
	local border = tank.sampleAuras[1].typeBorder
	assert(border and border[1]:IsShown(), "debuff type borders show by default, as in the game")
	write(env, K, "dispel.iconBorder", false)
	preview:Refresh()
	assert(not border[1]:IsShown(), "and switch off")

	write(env, K, "label.enabled", true)
	write(env, K, "label.size", 38)
	write(env, K, "label.padding", 18)
	write(env, K, "label.color", { r = 1, g = 0, b = 0 })
	preview:Refresh()
	local label = preview.label
	assert(label:IsShown() and font(label.text) == 38, "the label at its size")
	assert(math.abs(reveal(env, label:GetHeight()) - (38 * 1.2 + 36)) <= 1, "on its padded plate")
	assert((label.text:GetTextColor()) == 1, "in its colour")
	write(env, K, "mana.size", 24)
	write(env, K, "mana.mode", "PARTY")
	write(env, K, "mana.growth", "UP")
	preview:Refresh()
	assert(font(label.text) == 38, "the healer list's size leaves the label alone")
	local rows = preview.mana.rows
	assert(preview.mana:IsShown() and rows[2]:IsShown() and font(rows[1].text) == 24, "two healers at the list's size")
	assert(not H.text(env, rows[1].text):find("Sylaen", 1, true), "a party list shows no names")
	assert(rows[2]:GetPoint(1) == "BOTTOM", "growing up")
	write(env, K, "mana.mode", "RAID")
	preview:Refresh()
	assert(H.text(env, rows[1].text):find("Sylaen", 1, true), "a raid list names its healers")
	write(env, K, "mana.mode", "NONE")
	write(env, K, "label.enabled", false)
	preview:Refresh()
	assert(not preview.mana:IsShown() and not label:IsShown(), "off hides both")
	noErrors(env, K)
end

print("groupframes parity round 3a review ok: missing buff certainty, events and families; status size; icon and number room; gamepad; the preview's readouts and borders")
