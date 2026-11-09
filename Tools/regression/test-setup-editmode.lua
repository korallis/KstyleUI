-- test-setup-editmode.lua: Apply writes the objective tracker, Blizzard's damage meter and its tracked buff icon and bar viewers into a "KstyleUI <layout>" Edit Mode layout copied from the active one, out of combat, and falls back to the story hint (or a precise step) when Edit Mode cannot place them.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv

local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local TRACKER, METER, CHAT, VIEWER = EditModeFake.TRACKER, EditModeFake.METER, EditModeFake.CHAT, EditModeFake.VIEWER
local BUFF_ICON, BUFF_BAR = EditModeFake.BUFF_ICON, EditModeFake.BUFF_BAR
local ICON_SIZE, ORIENTATION, ICON_DIRECTION = EditModeFake.ICON_SIZE, EditModeFake.ORIENTATION, EditModeFake.ICON_DIRECTION
local HEIGHT, FRAME_WIDTH, FRAME_HEIGHT = EditModeFake.HEIGHT, EditModeFake.FRAME_WIDTH, EditModeFake.FRAME_HEIGHT
local PRESET, ACCOUNT = EditModeFake.PRESET, EditModeFake.ACCOUNT
local Install, Modern = EditModeFake.Install, EditModeFake.Modern

local function Boot(state, screen)
	local opts = {
		boot = false,
		setup = function(env)
			Install(env, state)
		end,
	}
	for key, value in pairs(screen or {}) do
		opts[key] = value
	end
	local env, K = W.New(opts)
	CoreEnv.Boot(env)
	return env, K
end

local OWNER = { width = 2383, height = 1540, uiScale = 768 / 1080 }

local Find, Setting, Named = EditModeFake.Find, EditModeFake.Setting, EditModeFake.Named

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.6
end

-- A new KstyleUI layout, copied from the active preset, with the tracker in the story slot and the meter on its card

do
	local state = { saved = { { layoutName = "Mine", layoutType = ACCOUNT, systems = Modern().systems } }, active = 1 }
	local env, K = Boot(state)
	assert(K.Setup.EditMode and K.Setup.EditMode.Available(), "the writer finds Forever's Edit Mode API")
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(state.saves == 1, "Apply saves the Edit Mode layouts once")
	local layout, index = Named(state, "KstyleUI DPS")
	assert(layout and layout.layoutType == ACCOUNT, "a KstyleUI DPS account layout is added")
	assert(state.activated == 2 + index, "and made the active layout, counting the two presets first")
	assert(Named(state, "Mine"), "the player's own layout is kept")
	assert(state.sent.layouts[1].layoutType == PRESET and #state.sent.layouts == 2 + #state.saved, "SaveLayouts takes the presets and the saved layouts, as Edit Mode sends them")
	local story = K.Setup.Story("DPS", false)
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local tracker = Find(layout, TRACKER)
	local a = tracker.anchorInfo
	assert(a.point == "TOPLEFT" and a.relativeTo == "UIParent" and a.relativePoint == "BOTTOMLEFT", "the tracker hangs from its top left, measured from the screen's bottom left")
	local place = K.Setup.EditMode.TrackerPlace(story.tracker)
	assert(near(a.offsetX, place.x * k) and near(a.offsetY, place.y * k), "at the story slot, in UIParent's units")
	assert(near(place.x - K.Setup.EditMode.TRACKER_LEFT, story.tracker.left) and near(place.y - K.Setup.EditMode.TRACKER_TOP, story.tracker.top), "so the tracker's glass starts at the slot's top left")
	assert(tracker.isInDefaultPosition == false, "and is no longer in its default position")
	assert(Setting(tracker, HEIGHT) == 0, "the tracker takes Edit Mode's lowest height, so a long list stays off chat")
	assert(Setting(tracker, 1) == 0, "its other settings are the copied layout's")
	local meter = Find(layout, METER)
	local rw, rh = K.Layout.RootSize()
	local spec = K.Setup.Layouts.Element("meters.damage")
	local w, h = K.Setup.Layouts.Footprint("DPS", "meters.damage")
	local l, _, _, t = K.Setup.Layouts.Rect({ width = w, height = h }, K.Setup.Layouts.Get("DPS")["meters.damage"], rw, rh)
	assert(spec and near(meter.anchorInfo.offsetX, l * k) and near(meter.anchorInfo.offsetY, t * k), "Blizzard's damage meter sits on the layout's damage card")
	assert(near(Setting(meter, FRAME_WIDTH), math.max(200, math.min(600, w * k)) - 200), "its width is the card's, as Edit Mode stores it (less the 200 minimum)")
	assert(near(Setting(meter, FRAME_HEIGHT), math.max(120, math.min(400, h * k)) - 120), "and its height (less the 120 minimum)")
	assert(Find(layout, CHAT).anchorInfo.offsetX == 35, "every other system keeps the copied layout's place")
	assert(Find(state.saved[1], TRACKER).anchorInfo.offsetX == -110, "the layout it copied is untouched")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The tracked buff viewers: on Forever the Cooldowns module's automatic path restyles Blizzard's own BuffIconCooldownViewer
-- and BuffBarCooldownViewer, so Apply places those viewers in the layout's tracked buff slots. The icons hang from the
-- slot's bottom right and grow left, away from the combat cluster; the bars stand on the slot's bottom left and grow
-- up. Their size comes from Edit Mode's IconSize, chosen so the whole row (every tracked item keeps a slot) fits
-- between the slot and the next element, never under 50% and never over KstyleUI's own buff size.

local function Overlaps(a, b)
	return a[1] < b[3] - 0.5 and b[1] < a[3] - 0.5 and a[2] < b[4] - 0.5 and b[2] < a[4] - 0.5
end

local function Collisions(K, name, box)
	local rw, rh = K.Layout.RootSize()
	local hits = {}
	for key, position in pairs(K.Setup.Layouts.Get(name)) do
		if not key:find("^cooldowns%.") and K.Setup.Layouts.Shown(name, key) ~= false then
			local w, h = K.Setup.Layouts.Footprint(name, key)
			if w then
				local l, b, r, t = K.Setup.Layouts.Rect({ width = w, height = h }, position, rw, rh)
				if Overlaps(box, { l, b, r, t }) then
					hits[#hits + 1] = key
				end
			end
		end
	end
	return hits
end

local function Slot(K, name, key)
	local rw, rh = K.Layout.RootSize()
	local w, h = K.Setup.Layouts.Footprint(name, key)
	return K.Setup.Layouts.Rect({ width = w, height = h }, K.Setup.Layouts.Get(name)[key], rw, rh)
end

local function Viewers(K, env, state, name, icons, bars)
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local layout = Named(state, "KstyleUI " .. name)
	local icon, bar = Find(layout, VIEWER, BUFF_ICON), Find(layout, VIEWER, BUFF_BAR)
	assert(icon and bar, "the KstyleUI layout carries both tracked buff viewers")
	return icon, bar, { EditModeFake.ViewerRect(icon, icons, k) }, { EditModeFake.ViewerRect(bar, bars, k, true) }, k
end

for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, screen in ipairs({ OWNER, {} }) do
		local state = { saved = {}, active = 1 }
		local env, K = Boot(state, screen)
		K.Setup.EditMode.CountTracked(function(group)
			return ({ buffs = 5, bars = 2 })[group]
		end)
		assert(K.Setup.Apply({ layout = name, modules = {} }))
		local icon, bar, iconBox, barBox, k = Viewers(K, env, state, name, 5, 2)
		local where = name .. " at " .. tostring(screen.width or 1920)
		local l, b, r = Slot(K, name, "cooldowns.buffs")
		assert(icon.anchorInfo.point == "BOTTOMRIGHT" and near(icon.anchorInfo.offsetX, r * k) and near(icon.anchorInfo.offsetY, b * k), where .. ": the buff icons hang from the slot's bottom right")
		assert(Setting(icon, ORIENTATION) == EditModeFake.HORIZONTAL and Setting(icon, ICON_DIRECTION) == EditModeFake.LEFT, where .. ": in one row, the first buff beside the cluster")
		assert(icon.isInDefaultPosition == false and bar.isInDefaultPosition == false, where .. ": both leave their default places")
		local size = (iconBox[4] - iconBox[2])
		assert(size <= 30 + 0.5 and Setting(icon, ICON_SIZE) >= 0, where .. ": a buff icon is no larger than KstyleUI's 30-unit buff, got " .. size)
		assert(near(iconBox[3], r) and iconBox[1] >= l - 0.5, where .. ": five buffs fit inside the slot")
		local _, bb, br = Slot(K, name, "cooldowns.bars")
		assert(bar.anchorInfo.point == "BOTTOMRIGHT" and near(bar.anchorInfo.offsetX, br * k) and near(bar.anchorInfo.offsetY, bb * k), where .. ": the bars stand on the bar slot's bottom right, over the icons")
		-- One block (round 4, Fable #5: the bars once started 22 units left of the icon row under them): a bar is as
		-- wide as the icon row, whatever bar width the copied layout had, so both share one left and one right edge.
		assert(math.abs(barBox[1] - iconBox[1]) <= 1.5 and math.abs(barBox[3] - iconBox[3]) <= 0.5, string.format("%s: the bars (%.1f-%.1f) and the icons (%.1f-%.1f) share their edges", where, barBox[1], barBox[3], iconBox[1], iconBox[3]))
		assert(#Collisions(K, name, iconBox) == 0, where .. ": the icons touch nothing: " .. table.concat(Collisions(K, name, iconBox), ", "))
		assert(#Collisions(K, name, barBox) == 0, where .. ": the bars touch nothing: " .. table.concat(Collisions(K, name, barBox), ", "))
		assert(not CoreEnv.Printed(env, "tracked"), where .. ": nothing to tell the player")
		assert(Find(Named(state, "KstyleUI " .. name), VIEWER, 1).anchorInfo.offsetY == 230, where .. ": the essential viewer keeps the copied layout's place")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- Sixteen tracked buffs and six tracked bars (round 4, Astra #1: the icons once crossed chat and the bars the focus
-- and target frames, with a printed step in place of a layout). The left wing holds about eleven icons and two
-- bars, so Apply picks a denser arrangement from the counts before it saves: the icons stand in one column beside
-- the cluster, the bars stack under the target of target where Tank keeps its threat meter, or over the focus
-- frame in Tank. The whole assembled layout must touch nothing, every tracked item keeps its slot, nothing leaves
-- the screen, and nothing is printed, on every preset, at every supported aspect and the owner's screen.

local SCREENS = {
	{ label = "the owner's 2383 x 1540", width = 2383, height = 1540, uiScale = 768 / 1080 },
	{ label = "2383 x 1540 at UI scale 1", width = 2383, height = 1540, uiScale = 1 },
	{ label = "16:9", width = 1920, height = 1080 },
	{ label = "16:9 at UI scale 0.64", width = 1920, height = 1080, uiScale = 0.64 },
	{ label = "16:10", width = 1920, height = 1200 },
	{ label = "21:9", width = 2560, height = 1080 },
}

local function Screen(screen)
	return { width = screen.width, height = screen.height, uiScale = screen.uiScale }
end

local function Everything(K, name, box)
	local hits = Collisions(K, name, box)
	local rw, rh = K.Layout.RootSize()
	for _, key in ipairs({ "cooldowns.essential", "cooldowns.utility" }) do
		local w, h = K.Setup.Layouts.Footprint(name, key)
		if Overlaps(box, { K.Setup.Layouts.Rect({ width = w, height = h }, K.Setup.Layouts.Get(name)[key], rw, rh) }) then
			hits[#hits + 1] = key
		end
	end
	if box[1] < -0.5 or box[2] < -0.5 or box[3] > rw + 0.5 or box[4] > rh + 0.5 then
		hits[#hits + 1] = "the screen edge"
	end
	return hits
end

for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, screen in ipairs(SCREENS) do
		local state = { saved = {}, active = 1 }
		local env, K = Boot(state, Screen(screen))
		K.Setup.EditMode.CountTracked(function(group)
			return ({ buffs = 16, bars = 6 })[group]
		end)
		assert(K.Setup.Apply({ layout = name, modules = {} }))
		local icon, bar, iconBox, barBox = Viewers(K, env, state, name, 16, 6)
		local where = name .. " at " .. screen.label .. " with 16 icons and 6 bars"
		local hits = Everything(K, name, iconBox)
		assert(#hits == 0, string.format("%s: the icons (%.1f,%.1f-%.1f,%.1f) touch %s", where, iconBox[1], iconBox[2], iconBox[3], iconBox[4], table.concat(hits, ", ")))
		hits = Everything(K, name, barBox)
		assert(#hits == 0, string.format("%s: the bars (%.1f,%.1f-%.1f,%.1f) touch %s", where, barBox[1], barBox[2], barBox[3], barBox[4], table.concat(hits, ", ")))
		assert(not Overlaps(iconBox, barBox), where .. ": the icons and the bars stay apart")
		assert(not CoreEnv.Printed(env, "tracked"), where .. ": nothing is left for the player to fix: " .. tostring((CoreEnv.Printed(env, "tracked"))))
		assert(not K.Setup.EditMode.Last().notes[1], where .. ": the setup summary has no step either")
		local thick = math.min(iconBox[3] - iconBox[1], iconBox[4] - iconBox[2])
		assert(thick >= 20 - 0.5 and thick <= 30 + 0.5, where .. ": a buff icon is between Edit Mode's 50% and KstyleUI's 30-unit buff, got " .. thick)
		assert((barBox[4] - barBox[2] - 5 * 2) / 6 >= 15 - 0.5, where .. ": a bar is at least Edit Mode's 50%")
		assert(icon.isInDefaultPosition == false and bar.isInDefaultPosition == false, where .. ": both viewers are placed")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

-- Placement is all or nothing (round 5, Astra #1: at Healer with 16 icons and 12 bars Apply reserved room for nine bars
-- and saved a viewer holding all twelve over the target of target). From 2 tracked items up past the screen's capacity,
-- on every preset and screen, each viewer Apply moves holds every tracked item clear of every element, the story rail
-- and the other viewer, at no less than Edit Mode's 50%. A viewer that cannot hold them all keeps the place it had,
-- byte for byte, and the summary names the counts with the Cooldown Manager and Edit Mode as the way out.

local function Story(K, name)
	local slot = K.Setup.Layouts.Slot(name)
	return { slot.x, slot.y, slot.x + slot.width, slot.y + slot.height }
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

local SWEEPS = {
	{ group = "bars", other = 16, counts = { 2, 4, 6, 8, 9, 10, 11, 12, 13, 14, 16, 20, 24, 32, 40, 60 } },
	{ group = "buffs", other = 6, counts = { 2, 6, 10, 12, 16, 20, 24, 30, 40, 60, 80 } },
}

local placedAt, refusedAt = {}, {}
for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, screen in ipairs(SCREENS) do
		for _, sweep in ipairs(SWEEPS) do
			local state = { saved = {}, active = 1 }
			local env, K = Boot(state, Screen(screen))
			local counts = {}
			K.Setup.EditMode.CountTracked(function(group)
				return counts[group]
			end)
			for _, n in ipairs(sweep.counts) do
				counts[sweep.group] = n
				counts[sweep.group == "bars" and "buffs" or "bars"] = sweep.other
				local before = Named(state, "KstyleUI " .. name)
				before = before and EditModeFake.Copy(before)
				assert(K.Setup.Apply({ layout = name, modules = {} }))
				local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
				local written = Named(state, "KstyleUI " .. name)
				local icon, bar = Find(written, VIEWER, BUFF_ICON), Find(written, VIEWER, BUFF_BAR)
				local where = string.format("%s at %s with %d icons and %d bars", name, screen.label, counts.buffs, counts.bars)
				local refused = {}
				for _, note in ipairs(K.Setup.EditMode.Last().notes) do
					refused[note.group] = note
				end
				local iconBox = not refused.buffs and { EditModeFake.ViewerRect(icon, counts.buffs, k) }
				local barBox = not refused.bars and { EditModeFake.ViewerRect(bar, counts.bars, k, true) }
				local boxes = { buffs = iconBox, bars = barBox }
				for _, group in ipairs({ "buffs", "bars" }) do
					local entry = group == "buffs" and icon or bar
					local index = group == "buffs" and BUFF_ICON or BUFF_BAR
					if refused[group] then
						local note = refused[group]
						assert(note.count == counts[group] and note.fits < note.count, where .. ": the note names the " .. group .. " count and how many fit")
						local old = before and Find(before, VIEWER, index) or Find(Modern(), VIEWER, index)
						assert(Same(entry.anchorInfo, old.anchorInfo) and Same(entry.settings, old.settings), where .. ": a viewer that cannot hold every tracked " .. group .. " keeps its place and settings")
						refusedAt[group] = math.min(refusedAt[group] or math.huge, counts[group])
					else
						local box = boxes[group]
						local hits = Everything(K, name, box)
						if Overlaps(box, Story(K, name)) then
							hits[#hits + 1] = "the story rail"
						end
						assert(#hits == 0, string.format("%s: the whole %s viewer (%.1f,%.1f-%.1f,%.1f) touches %s", where, group, box[1], box[2], box[3], box[4], table.concat(hits, ", ")))
						assert(entry.isInDefaultPosition == false, where .. ": the " .. group .. " viewer is placed")
						local items = math.max(2, counts[group])
						local item = group == "bars" and (box[4] - box[2] - (items - 1) * 2) / items or math.min(box[3] - box[1], box[4] - box[2])
						assert(item >= (group == "bars" and 15 or 20) / k - 0.5, where .. ": a " .. group .. " item is at least Edit Mode's 50%")
						placedAt[group] = math.max(placedAt[group] or 0, counts[group])
					end
				end
				if not refused.buffs and not refused.bars then
					assert(not Overlaps(iconBox, barBox), where .. ": the icons and the bars stay apart")
					assert(not CoreEnv.Printed(env, "tracked"), where .. ": nothing to tell the player")
				end
				assert(#env._errors == 0, tostring(env._errors[1]))
			end
		end
	end
end
assert(refusedAt.buffs and refusedAt.bars, "the sweep reaches past the screen's capacity for both viewers")
assert(placedAt.bars >= 24 and placedAt.buffs >= 40, "and there is room for 24 bars and 40 icons somewhere")

-- The reported case: Healer, 16 icons and 12 bars on the owner's screen. Both viewers fit whole, nothing is printed.
do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state, OWNER)
	K.Setup.EditMode.CountTracked(function(group)
		return ({ buffs = 16, bars = 12 })[group]
	end)
	assert(K.Setup.Apply({ layout = "Healer", modules = {} }))
	local _, _, iconBox, barBox = Viewers(K, env, state, "Healer", 16, 12)
	assert(#Everything(K, "Healer", barBox) == 0, "the twelve bars touch nothing: " .. table.concat(Everything(K, "Healer", barBox), ", "))
	assert(#Everything(K, "Healer", iconBox) == 0, "the sixteen icons touch nothing")
	assert(not K.Setup.EditMode.Last().notes[1], "and the summary has no step")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Bar 2 is on by default and Apply switches it off; a player may turn it back on. Where the viewers have other room
-- (DPS and Tank at 16 icons and 6 bars, on every screen), they keep bar 2's column free; at 12 bars on the owner's
-- screen nothing else holds them, and the all-or-nothing sweep above holds them clear of every frame that is on.
for _, name in ipairs({ "DPS", "Tank" }) do
	for _, screen in ipairs(SCREENS) do
		for _, bars in ipairs({ 6 }) do
			local state = { saved = {}, active = 1 }
			local env, K = Boot(state, Screen(screen))
			K.Setup.EditMode.CountTracked(function(group)
				return ({ buffs = 16, bars = bars })[group]
			end)
			assert(K.Setup.Apply({ layout = name, modules = {} }))
			local _, _, iconBox, barBox = Viewers(K, env, state, name, 16, bars)
			local column = { Slot(K, name, "actionbars.bar2") }
			local where = string.format("%s at %s with 16 icons and %d bars", name, screen.label, bars)
			assert(not Overlaps(iconBox, column) and not Overlaps(barBox, column), where .. ": the viewers keep bar 2's column free")
			assert(not K.Setup.EditMode.Last().notes[1], where .. ": and still hold every item")
			assert(#env._errors == 0, tostring(env._errors[1]))
		end
	end
end

-- Past what the screen holds, Apply moves neither viewer, the setup summary names the counts and offers the Cooldown
-- Manager, and the printed line says the same and names Edit Mode.

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state, OWNER)
	K.Setup.EditMode.CountTracked(function(group)
		return ({ buffs = 200, bars = 120 })[group]
	end)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local written = Named(state, "KstyleUI DPS")
	local icon, bar = Find(written, VIEWER, BUFF_ICON), Find(written, VIEWER, BUFF_BAR)
	local notes = K.Setup.EditMode.Last().notes
	assert(#notes == 2 and notes[1].group == "buffs" and notes[1].count == 200 and notes[1].fits < 200, "the summary gets the buff count and how many fit")
	assert(notes[2].group == "bars" and notes[2].count == 120 and notes[2].fits < 120, "and the bar count")
	assert(icon.isInDefaultPosition == true and bar.isInDefaultPosition == true, "neither viewer leaves the place it had")
	assert(Same(icon.anchorInfo, Find(Modern(), VIEWER, BUFF_ICON).anchorInfo), "the icons keep the copied layout's anchor")
	local line = CoreEnv.Printed(env, "200 tracked buffs")
	assert(line and line:find("Cooldown Manager", 1, true) and line:find("Edit Mode", 1, true), "the printed line says where to change it: " .. tostring(line))
	assert(K.Setup.EditMode.Last().state == "written", "the rest of the layout is still written")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client without the CooldownViewer system keeps the rest of the write

do
	local state = { saved = {}, active = 1, noViewers = true }
	local env, K = Boot(state)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local layout = Named(state, "KstyleUI DPS")
	assert(layout and Find(layout, TRACKER).isInDefaultPosition == false, "the tracker is still placed")
	assert(Find(layout, VIEWER, BUFF_ICON).isInDefaultPosition == true, "the viewers are left alone")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Applying again updates the KstyleUI layout in place; another layout gets its own

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local count = 0
	for _, layout in ipairs(state.saved) do
		if layout.layoutName == "KstyleUI DPS" then
			count = count + 1
		end
	end
	assert(count == 1, "a second Apply reuses the KstyleUI DPS layout")
	assert(K.Setup.Apply({ layout = "Healer", modules = {} }))
	local healer, index = Named(state, "KstyleUI Healer")
	assert(healer and state.activated == 2 + index, "Healer writes and activates its own layout")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- With RestedXP loaded, the tracker sits under the guide's half of the slot

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	env.C_AddOns = env.C_AddOns or {}
	env.C_AddOns.IsAddOnLoaded = function(name)
		return name == "RXPGuides"
	end
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	local story = K.Setup.Story("DPS", true)
	local slot = K.Setup.Story("DPS", false)
	assert(story.guide and near(story.guide.top, slot.story.top) and story.guide.left == slot.story.left, "the guide takes the top of the slot")
	assert(story.tracker.top < story.guide.bottom and near(story.guide.bottom - story.tracker.top, 16), "the tracker starts one rail gap under it")
	assert(near(story.tracker.bottom, slot.story.bottom), "and runs to the slot's bottom")
	local k = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local a = Find(Named(state, "KstyleUI DPS"), TRACKER).anchorInfo
	assert(near(a.offsetY, K.Setup.EditMode.TrackerPlace(story.tracker).y * k), "Apply places the tracker under the guide when RestedXP is loaded")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- In combat the write waits for combat to end

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	env.SetCombat(true)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(state.saves == nil, "nothing is saved in combat")
	env.SetCombat(false)
	assert(state.saves == 1 and Named(state, "KstyleUI DPS"), "the layout is written when combat ends")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Without Edit Mode, or with every account slot taken, Apply keeps the hint

local function Logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Setup" and entry.message:find(text, 1, true) then
			return true
		end
	end
end

do
	local state = { saved = {}, active = 1, noEditMode = true }
	local env, K = Boot(state)
	assert(not K.Setup.EditMode.Available())
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }), "Apply still applies")
	assert(Logged(env, "Edit Mode"), "and logs that the tracker keeps the hint")
	assert(CoreEnv.Printed(env, "Edit Mode"), "the player is told to move the tracker in Edit Mode")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local full = {}
	for i = 1, 5 do
		full[i] = { layoutName = "Mine " .. i, layoutType = ACCOUNT, systems = Modern().systems }
	end
	local state = { saved = full, active = 3, max = 5 }
	local env, K = Boot(state)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(state.saves == nil and state.activated == nil, "a full set of account layouts is never overwritten")
	assert(Logged(env, "account layouts"), "the log says why")
	assert(CoreEnv.Printed(env, "Edit Mode"), "and the player gets the hint")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A broken API call is caught and logged; Apply still returns true

do
	local state = { saved = {}, active = 1 }
	local env, K = Boot(state)
	env.C_EditMode.SaveLayouts = function()
		error("blocked")
	end
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	assert(Logged(env, "SaveLayouts"), "a failed save is logged")
	assert(state.activated == nil, "and nothing is activated")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("setup editmode ok")
