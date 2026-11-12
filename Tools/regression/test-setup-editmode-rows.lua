-- test-setup-editmode-rows.lua: when the Cooldowns module falls back to Blizzard's own essential and utility viewers, Apply places them on KstyleUI's own rows in the "KstyleUI <layout>" Edit Mode layout, clear of everything on every screen, never over a row the player placed, and a later fallback places them in the active KstyleUI layout out of combat; when the mirror works nothing changes.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv

local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local VIEWER, BUFF_ICON, BUFF_BAR = EditModeFake.VIEWER, EditModeFake.BUFF_ICON, EditModeFake.BUFF_BAR
local ESSENTIAL, UTILITY = EditModeFake.ESSENTIAL, EditModeFake.UTILITY
local ICON_SIZE, ORIENTATION, ICON_DIRECTION, ICON_LIMIT = EditModeFake.ICON_SIZE, EditModeFake.ORIENTATION, EditModeFake.ICON_DIRECTION, EditModeFake.ICON_LIMIT
local ACCOUNT = EditModeFake.ACCOUNT
local Find, Setting, Named, Copy = EditModeFake.Find, EditModeFake.Setting, EditModeFake.Named, EditModeFake.Copy

local ROWS = {
	{ group = "essential", key = "cooldowns.essential", index = ESSENTIAL, size = 50, count = 6 },
	{ group = "utility", key = "cooldowns.utility", index = UTILITY, size = 30, count = 4 },
}

-- Every screen in the crew's matrix (CREW.md, 2026-11-12): 1280x720 to 5120x1440, the ultrawides and the owner's two
-- Macs, at UI scale 1, at 0.64 and at the Interface size KstyleUI ships, so the Edit Mode steps meet every canvas.
local SCREENS = {
	{ label = "1280x720", width = 1280, height = 720 },
	{ label = "1366x768", width = 1366, height = 768 },
	{ label = "1920x1080", width = 1920, height = 1080 },
	{ label = "1920x1080 at UI scale 0.64", width = 1920, height = 1080, uiScale = 0.64 },
	{ label = "2560x1440", width = 2560, height = 1440 },
	{ label = "3440x1440", width = 3440, height = 1440 },
	{ label = "5120x1440", width = 5120, height = 1440 },
	{ label = "5120x1440 at the shipped size", width = 5120, height = 1440, uiScale = 768 / 1080, size = "default" },
	{ label = "3840x1080", width = 3840, height = 1080 },
	{ label = "3840x2160", width = 3840, height = 2160 },
	{ label = "the owner's 2383x1540", width = 2383, height = 1540, uiScale = 768 / 1080, size = "default" },
	{ label = "3456x2234", width = 3456, height = 2234 },
}

local function Boot(state, screen)
	local opts = {
		boot = false,
		setup = function(env)
			EditModeFake.Install(env, state)
		end,
	}
	for _, field in ipairs({ "width", "height", "uiScale", "size" }) do
		opts[field] = screen and screen[field]
	end
	local env, K = W.New(opts)
	CoreEnv.Boot(env)
	return env, K
end

local function Counts(K, counts)
	K.Setup.EditMode.CountTracked(function(group)
		return counts[group]
	end)
end

local function Natives(K, groups)
	local register = K.Setup.EditMode.NativeRows
	if register then
		register(function(group)
			return groups[group] == true
		end)
	end
end

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not Same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function Overlaps(a, b)
	return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
end

local function Slot(K, name, key)
	local rw, rh = K.Layout.RootSize()
	local w, h, offsetX = K.Setup.Layouts.Footprint(name, key)
	return { K.Setup.Layouts.Rect({ width = w, height = h, offsetX = offsetX }, K.Setup.Layouts.Get(name, rh)[key], rw, rh) }
end

-- Hits(K, name, box, own, extra) -> what the box touches: every shown Layout element but its own row, the story slot,
-- the screen's edges and the named extra boxes (the other row, Blizzard's tracked buff viewers).
local function Hits(K, name, box, own, extra)
	local rw, rh = K.Layout.RootSize()
	local hits = {}
	for key in pairs(K.Setup.Layouts.Get(name, rh)) do
		if key ~= own and K.Setup.Layouts.Shown(name, key) ~= false and K.Setup.Layouts.Footprint(name, key) and Overlaps(box, Slot(K, name, key)) then
			hits[#hits + 1] = key
		end
	end
	local story = K.Setup.Layouts.Slot(name, rh)
	if story and Overlaps(box, { K.Setup.Layouts.Rect(story, story, rw, rh) }) then
		hits[#hits + 1] = "the story slot"
	end
	if box[1] < -0.5 or box[2] < -0.5 or box[3] > rw + 0.5 or box[4] > rh + 0.5 then
		hits[#hits + 1] = "the screen edge"
	end
	for label, other in pairs(extra) do
		if other and Overlaps(box, other) then
			hits[#hits + 1] = label
		end
	end
	table.sort(hits)
	return hits
end

local function Factor(K, env)
	return K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
end

-- 1. The fallback, at the counts KSTY-21 measured (six essential, four utility, five tracked buffs, two bars), on every
-- preset and screen: Blizzard's viewers leave the managed bottom stack for KstyleUI's own rows, essential centred on
-- its row and utility from its row's left edge, both on the rows' baseline, their icons no larger than KstyleUI's, and
-- each whole viewer clear of every element, the story slot, the other row and Blizzard's tracked buff viewers.

local counted = 0
for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, screen in ipairs(SCREENS) do
		local state = { saved = {}, active = 1 }
		local env, K = Boot(state, screen)
		Counts(K, { essential = 6, utility = 4, buffs = 5, bars = 2 })
		Natives(K, { essential = true, utility = true })
		assert(K.Setup.Apply({ layout = name, modules = {} }))
		local where = name .. " at " .. screen.label
		local k = Factor(K, env)
		local layout = Named(state, "KstyleUI " .. name)
		local boxes = {}
		for _, row in ipairs(ROWS) do
			local entry = Find(layout, VIEWER, row.index)
			assert(entry.isInDefaultPosition == false, where .. ": Blizzard's " .. row.group .. " viewer leaves the managed bottom stack for KstyleUI's row")
			assert(Setting(entry, ORIENTATION) == EditModeFake.HORIZONTAL and Setting(entry, ICON_DIRECTION) == EditModeFake.RIGHT, where .. ": the " .. row.group .. " row runs left to right")
			local box = { EditModeFake.RowRect(entry, row.count, k, row.size) }
			boxes[row.group] = box
			local slot = Slot(K, name, row.key)
			assert(math.abs(box[2] - slot[2]) < 0.6, where .. ": the " .. row.group .. " row stands on KstyleUI's baseline")
			if row.group == "essential" then
				assert(math.abs((box[1] + box[3]) / 2 - (slot[1] + slot[3]) / 2) < 0.6, where .. ": the essential row is centred where KstyleUI's is")
			else
				assert(math.abs(box[1] - slot[1]) < 0.6, where .. ": the utility row starts at KstyleUI's left edge")
			end
			local item = row.size * (Setting(entry, ICON_SIZE) * 10 + 50) / 100 / k
			assert(item <= slot[4] - slot[2] + 0.01 or Setting(entry, ICON_SIZE) == 0, string.format("%s: a native %s icon (%.2f) is no larger than KstyleUI's (%.2f) above Edit Mode's 50%%", where, row.group, item, slot[4] - slot[2]))
			assert(Setting(entry, ICON_SIZE) == 0 or row.size * (Setting(entry, ICON_SIZE) * 10 + 60) / 100 / k > slot[4] - slot[2], where .. ": the " .. row.group .. " icons take the largest step that keeps them no larger than KstyleUI's")
		end
		local icons = { EditModeFake.ViewerRect(Find(layout, VIEWER, BUFF_ICON), 5, k) }
		local bars = { EditModeFake.ViewerRect(Find(layout, VIEWER, BUFF_BAR), 2, k, true) }
		for _, row in ipairs(ROWS) do
			local other = row.group == "essential" and "utility" or "essential"
			local box = boxes[row.group]
			local hits = Hits(K, name, box, row.key, { [other .. " row"] = boxes[other], ["tracked buff icons"] = icons, ["tracked buff bars"] = bars })
			assert(#hits == 0, string.format("%s: Blizzard's %s row (%.1f,%.1f-%.1f,%.1f) touches %s", where, row.group, box[1], box[2], box[3], box[4], table.concat(hits, ", ")))
		end
		assert(#K.Setup.EditMode.Last().notes == 0 and not CoreEnv.Printed(env, "cooldowns don't fit"), where .. ": nothing is left for the player to fix")
		assert(#env._errors == 0, tostring(env._errors[1]))
		counted = counted + 1
	end
end
assert(counted == 3 * #SCREENS, "every preset meets every screen")

-- 2. All or nothing: from two essential cooldowns up past the row's room, a row Apply moves holds every item clear,
-- centred on KstyleUI's row or, when that is too narrow, growing left from its right end, in one line or two; one that cannot keeps the copied layout's place and settings, byte for byte, and the summary
-- names the count, how many would fit, and the way out.

local placed, refused = 0, 0
for _, name in ipairs({ "DPS", "Healer" }) do
	for _, screen in ipairs({ SCREENS[1], SCREENS[3], SCREENS[7] }) do
		for _, count in ipairs({ 2, 8, 12, 16, 24, 40 }) do
			local state = { saved = {}, active = 1 }
			local env, K = Boot(state, screen)
			Counts(K, { essential = count, utility = 4, buffs = 5, bars = 2 })
			Natives(K, { essential = true, utility = true })
			assert(K.Setup.Apply({ layout = name, modules = {} }))
			local where = string.format("%s at %s with %d essential cooldowns", name, screen.label, count)
			local k = Factor(K, env)
			local layout = Named(state, "KstyleUI " .. name)
			local entry = Find(layout, VIEWER, ESSENTIAL)
			local note
			for _, told in ipairs(K.Setup.EditMode.Last().notes) do
				if told.group == "essential" then
					note = told
				end
			end
			if note then
				assert(note.count == count and note.fits < count, where .. ": the note names the count and how many fit")
				assert(Same(entry, Find(EditModeFake.Modern(), VIEWER, ESSENTIAL)), where .. ": a row that cannot hold them all keeps its place and settings")
				assert(CoreEnv.Printed(env, "essential cooldowns don't fit"), where .. ": and the player is told")
				refused = refused + 1
			else
				local box = { EditModeFake.RowRect(entry, count, k, 50) }
				local utility = { EditModeFake.RowRect(Find(layout, VIEWER, UTILITY), 4, k, 30) }
				local hits = Hits(K, name, box, "cooldowns.essential", { ["utility row"] = utility })
				assert(#hits == 0, string.format("%s: the essential row (%.1f,%.1f-%.1f,%.1f) touches %s", where, box[1], box[2], box[3], box[4], table.concat(hits, ", ")))
				assert(math.ceil(count / Setting(entry, ICON_LIMIT)) <= 2, where .. ": in one line or two")
				placed = placed + 1
			end
			assert(#env._errors == 0, tostring(env._errors[1]))
		end
	end
end
assert(placed > 0 and refused > 0, "the sweep reaches past the row's room")

-- 3. When the mirror works nothing changes: the written layout is the same, byte for byte, as when no module says
-- which rows fall back, and the essential and utility viewers keep the copied layout's default places.

for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, screen in ipairs({ SCREENS[3], SCREENS[7] }) do
		local layouts = {}
		for run = 1, 2 do
			local state = { saved = {}, active = 1 }
			local _, K = Boot(state, screen)
			Counts(K, { essential = 6, utility = 4, buffs = 5, bars = 2 })
			if run == 2 then
				Natives(K, {})
			end
			assert(K.Setup.Apply({ layout = name, modules = {} }))
			layouts[run] = Named(state, "KstyleUI " .. name)
		end
		local where = name .. " at " .. screen.label
		assert(Same(layouts[1], layouts[2]), where .. ": a working mirror leaves Apply's layout unchanged")
		for _, row in ipairs(ROWS) do
			assert(Same(Find(layouts[2], VIEWER, row.index), Find(EditModeFake.Modern(), VIEWER, row.index)), where .. ": the " .. row.group .. " viewer keeps the copied layout's default place")
		end
	end
end

-- 4. Never over the player's own placement: a row they moved in the layout Apply copies stays where they put it, the
-- other row still moves, and their own layout is untouched.

do
	local mine = EditModeFake.Modern().systems
	local moved = Find({ systems = mine }, VIEWER, ESSENTIAL)
	moved.isInDefaultPosition = false
	moved.anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 120, offsetY = -40 }
	local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Copy(mine) } }, active = 3 }
	local env, K = Boot(state, SCREENS[3])
	Counts(K, { essential = 6, utility = 4, buffs = 5, bars = 2 })
	Natives(K, { essential = true, utility = true })
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local layout = Named(state, "KstyleUI DPS")
	assert(Same(Find(layout, VIEWER, ESSENTIAL), moved), "the essential row the player moved stays where they put it")
	assert(Find(layout, VIEWER, UTILITY).isInDefaultPosition == false, "the utility row they never moved goes to KstyleUI's row")
	assert(Same(Named(state, "Mine").systems, mine), "the player's own layout is untouched")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- 5. A row KstyleUI placed is KstyleUI's to place again: Apply with more cooldowns moves it to fit them; once the
-- player drags it in Edit Mode, Apply leaves it there.

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state, SCREENS[3])
	local counts = { essential = 6, utility = 4, buffs = 5, bars = 2 }
	Counts(K, counts)
	Natives(K, { essential = true, utility = true })
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local first = Copy(Find(Named(state, "KstyleUI DPS"), VIEWER, ESSENTIAL))
	counts.essential = 8
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local second = Find(Named(state, "KstyleUI DPS"), VIEWER, ESSENTIAL)
	assert(second.isInDefaultPosition == false and not Same(first, second), "Apply moves its own row again to hold eight")
	local box = { EditModeFake.RowRect(second, 8, Factor(K, env), 50) }
	local utility = { EditModeFake.RowRect(Find(Named(state, "KstyleUI DPS"), VIEWER, UTILITY), 4, Factor(K, env), 30) }
	assert(#Hits(K, "DPS", box, "cooldowns.essential", { ["utility row"] = utility }) == 0, "and the eight fit clear")
	second.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 300, offsetY = 500 }
	local dragged = Copy(second)
	counts.essential = 6
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(Same(Find(Named(state, "KstyleUI DPS"), VIEWER, ESSENTIAL), dragged), "a row the player dragged since stays where they put it")
	local useful = Find(Named(state, "KstyleUI DPS"), VIEWER, UTILITY)
	for _, info in ipairs(useful.settings) do
		if info.setting == ICON_LIMIT then
			info.value = 2
		end
	end
	local resized = Copy(useful)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(Same(Find(Named(state, "KstyleUI DPS"), VIEWER, UTILITY), resized), "a row whose settings the player changed in Edit Mode, without a drag, stays as they set it")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- 6. A fallback after Apply (the mirror failing mid-session): Setup places the rows in the active KstyleUI layout, never
-- in combat, touching no other system, once; in a layout KstyleUI did not write it saves nothing.

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state, SCREENS[3])
	local groups = {}
	Counts(K, { essential = 6, utility = 4, buffs = 5, bars = 2 })
	Natives(K, groups)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local before, saves, active = Copy(Named(state, "KstyleUI DPS")), state.saves, state.active
	assert(type(K.Setup.EditMode.PlaceRows) == "function", "Setup places the rows when a fallback comes later")
	groups.essential, groups.utility = true, true
	env.SetCombat(true)
	K.Setup.EditMode.PlaceRows()
	K.Setup.EditMode.PlaceRows()
	env.RunTimers()
	assert(state.saves == saves, "nothing is saved in combat")
	env.SetCombat(false)
	assert(state.saves == saves + 1 and state.activated == active, "the rows are saved once combat ends, in the active layout")
	local after = Named(state, "KstyleUI DPS")
	for i, entry in ipairs(after.systems) do
		if entry.system == VIEWER and (entry.systemIndex == ESSENTIAL or entry.systemIndex == UTILITY) then
			assert(entry.isInDefaultPosition == false, "Blizzard's cooldown rows leave the managed stack")
		else
			assert(Same(entry, before.systems[i]), "every other system keeps its place")
		end
	end
	K.Setup.EditMode.PlaceRows()
	env.RunTimers()
	assert(state.saves == saves + 1, "placing them again with nothing to change saves nothing")

	local own = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = EditModeFake.Modern().systems } }, active = 3 }
	local env2, K2 = Boot(own, SCREENS[3])
	Natives(K2, { essential = true, utility = true })
	K2.Setup.EditMode.PlaceRows()
	env2.RunTimers()
	assert(not own.saves, "in the player's own layout the fallback saves nothing")
	assert(#env._errors == 0 and #env2._errors == 0, tostring(env._errors[1] or env2._errors[1]))
end

-- 7. The Cooldowns module says which rows fall back: Apply on the automatic path, where the rows mirror, leaves
-- Blizzard's viewers in their default places; with the restyle chosen it places them; and when the mirror fails
-- after Apply, the module has Setup place them in the active KstyleUI layout.

local C = dofile("Tools/regression/cooldowns_env.lua")

local function Cooldowns(state, path)
	local env, K, ns = C.New({ setup = function(env)
		C.Viewers(env)
		EditModeFake.Install(env, state)
	end })
	if path then
		K.Options.Write("Cooldowns", "path", path)
	end
	assert(K.Setup.Apply({ layout = "DPS", modules = { Cooldowns = true } }))
	assert(K.Modules.IsRunning("Cooldowns"), "Apply runs the Cooldowns module")
	return env, K, ns
end

for _, case in ipairs({ { path = nil, native = false }, { path = "reskin", native = true } }) do
	local state = { saved = {}, active = 1 }
	local env, _, ns = Cooldowns(state, case.path)
	local layout = Named(state, "KstyleUI DPS")
	for _, row in ipairs(ROWS) do
		assert(ns.Path.Get(row.group) == (case.native and "reskin" or "mirror"), "the " .. row.group .. " row takes the expected path")
		assert((Find(layout, VIEWER, row.index).isInDefaultPosition == false) == case.native, "on the " .. (case.path or "automatic") .. " path Blizzard's " .. row.group .. " viewer " .. (case.native and "is placed" or "keeps its default place"))
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local state = { saved = {}, active = 1 }
	local env, _, ns = Cooldowns(state)
	local saves = state.saves
	env._cdm.durationError = "secret arguments are not allowed"
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	env.RunTimers()
	assert(ns.Path.Get("essential") == "reskin" and ns.Path.Get("utility") == "reskin", "the mirror failed and both rows fell back")
	local layout = Named(state, "KstyleUI DPS")
	assert(state.saves == saves + 1, "the two fallbacks of one moment save the layout once")
	for _, row in ipairs(ROWS) do
		assert(Find(layout, VIEWER, row.index).isInDefaultPosition == false, "the fallback placed Blizzard's " .. row.group .. " viewer in the active KstyleUI layout")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("test-setup-editmode-rows: ok")
