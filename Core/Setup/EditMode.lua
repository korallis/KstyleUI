-- EditMode.lua: Apply's Edit Mode writer: it copies the active Edit Mode layout into a "KstyleUI <layout>" account layout, puts the objective tracker where the quest card stands (the story slot, or the column beside the RestedXP guide's card), Blizzard's damage meter on the damage card, Blizzard's own essential and utility rows on KstyleUI's rows when the Cooldowns module falls back to them (centred, else growing away from the other row, in one or two lines that fit clear, leaving a row the player placed or that fits nowhere where it was, and again in the active KstyleUI layout when the fallback comes later), its tracked buff icon and bar viewers where every tracked item fits whole (the slots beside the hands, else a column beside the cluster or the rail and the bars under the target of target, over the focus frame or beside the right rail, keeping bar 2's column free when anything else fits) or leaves a viewer that fits nowhere where it was, the raid warnings in the highest free band between the rails from 15% under the top, saves the layouts and activates that one, out of combat, and keeps the result for the setup summary.
local _, ns = ...

local Setup = ns.Setup
local Layouts = Setup.Layouts
local L = ns.L

local EditMode = {}
Setup.EditMode = EditMode

local OWNER = "Setup"
local PREFIX = "KstyleUI "
local TRACKER_HEIGHT_MIN, TRACKER_HEIGHT_STEP, TRACKER_HEIGHT_STEPS = 400, 10, 60
local METER_WIDTH_MIN, METER_WIDTH_MAX = 200, 600
local METER_HEIGHT_MIN, METER_HEIGHT_MAX = 120, 400
local VIEWER_SIZE_MIN, VIEWER_SIZE_STEP, VIEWER_SIZE_MAX = 50, 10, 200
local BAR_WIDTH_MIN, BAR_WIDTH_MAX = 50, 200
local VIEWER_CLEAR, VIEWER_MIN_ITEMS, FOCUS_CLEAR, SLIDES = 2, 2, 16, 6
local WARNING_WIDTH, WARNING_HEIGHT, WARNING_TOP = 800, 100, 0.15
local DENSE_GAPS = { 4, 2 }
local VIEWERS = {
	buffs = { key = "cooldowns.buffs", index = "BuffIcon", width = 40, height = 40, offset = 4, fallback = 6, cap = 27.6, floor = 24 },
	bars = { key = "cooldowns.bars", index = "BuffBar", width = 220, height = 30, offset = 2, fallback = 2, cap = 24, floor = 18 },
}
local TRACKED = { ["cooldowns.buffs"] = true, ["cooldowns.bars"] = true }
local ROWS = {
	essential = { key = "cooldowns.essential", index = "Essential", size = 50, fallback = 6, spots = { "BOTTOM", "BOTTOMRIGHT" }, label = "Blizzard's essential cooldowns" },
	utility = { key = "cooldowns.utility", index = "Utility", size = 30, fallback = 4, spots = { "BOTTOMLEFT" }, label = "Blizzard's utility cooldowns" },
}
local ROW_ORDER = { "essential", "utility" }
local ROW_LINES, ICON_LIMIT_MAX, PADDING_OFFSET, PADDING_MAX = 2, 20, 4, 14
local STAMPS = "editModeRows"
local SPARE = { "actionbars.bar2", "actionbars.bar3", "actionbars.bar4", "actionbars.bar5" }

EditMode.TRACKER_LEFT = 16
EditMode.TRACKER_TOP = 34
EditMode.WARNING_LANE = 580

local abs, ceil, floor, max, min = math.abs, math.ceil, math.floor, math.max, math.min
local counter, native, queued

local function log(message)
	ns.DevTest.Log(OWNER, message)
end

local function IsTable(value)
	return type(value) == "table"
end

local function Fn(holder, name)
	return IsTable(holder) and type(holder[name]) == "function"
end

local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = Copy(v)
	end
	return out
end

local function Plain(value)
	return type(value) == "number" and not (issecretvalue and issecretvalue(value)) and value == value and value > 0
end

function EditMode.Available()
	local api, enum = C_EditMode, Enum
	if not (Fn(api, "GetLayouts") and Fn(api, "SaveLayouts") and Fn(api, "SetActiveLayout")) then
		return false
	end
	if not (IsTable(enum) and IsTable(enum.EditModeSystem) and IsTable(enum.EditModeLayoutType)) then
		return false
	end
	return enum.EditModeSystem.ObjectiveTracker ~= nil and Fn(EditModePresetLayoutManager, "GetCopyOfPresetLayouts")
end

local function Factor()
	local root, parent = ns.Scale.Root():GetEffectiveScale(), UIParent:GetEffectiveScale()
	if Plain(root) and Plain(parent) then
		return root / parent
	end
	return 1
end

function EditMode.TrackerPlace(band)
	return { x = band.left + EditMode.TRACKER_LEFT, y = band.top + EditMode.TRACKER_TOP }
end

local function Clamp(value, low, high)
	return max(low, min(high, value))
end

function EditMode.CountTracked(fn)
	counter = type(fn) == "function" and fn or nil
end

function EditMode.Tracked(group)
	if counter then
		local ok, n = pcall(counter, group)
		if ok and Plain(n) then
			return floor(n)
		end
	end
	return (VIEWERS[group] or ROWS[group]).fallback
end

function EditMode.NativeRows(fn)
	native = type(fn) == "function" and fn or nil
end

local function Native(group)
	if not native then
		return false
	end
	local ok, shown = pcall(native, group)
	return ok and shown == true
end

local function Positions(name)
	return Layouts.Positions(name, ns.HudStyle and ns.HudStyle.Current())
end

local function Box(name, key, rw, rh)
	local position = Positions(name)[key]
	local w, h, offsetX = Layouts.Footprint(name, key)
	if not (position and w) then
		return nil
	end
	local l, b, r, t = Layouts.Rect({ width = w, height = h, offsetX = offsetX }, position, rw, rh)
	return { l = l, b = b, r = r, t = t }
end

local function StoryBox(name, rw, rh, part)
	local story = Layouts.Story(name, rh, true)
	local card = story and story[part or "guide"]
	if not card then
		return nil
	end
	local l, b, r, t = Layouts.Rect(card, card, rw, rh)
	return { l = l, b = b, r = r, t = t }
end

local function Others(name, rw, rh, skip)
	local out = {}
	skip = skip or TRACKED
	for key in pairs(Positions(name)) do
		if not skip[key] and Layouts.Shown(name, key) ~= false then
			out[#out + 1] = Box(name, key, rw, rh)
		end
	end
	out[#out + 1] = StoryBox(name, rw, rh)
	local quests = StoryBox(name, rw, rh, "quests")
	if quests then
		quests.quests = true
		out[#out + 1] = quests
	end
	return out
end

local function Clear(rect, others, rw, rh)
	if rect.l < 0 or rect.b < 0 or rect.r > rw or rect.t > rh then
		return false
	end
	for _, o in ipairs(others) do
		if rect.l < o.r + VIEWER_CLEAR and o.l - VIEWER_CLEAR < rect.r and rect.b < o.t + VIEWER_CLEAR and o.b - VIEWER_CLEAR < rect.t then
			return false, o
		end
	end
	return true
end

local function Shape(spot, length, thick)
	local l = spot.right and spot.x - (spot.across and length or thick) or spot.x
	local w, h = thick, length
	if spot.across then
		w, h = length, thick
	end
	return { l = l, b = spot.y, r = l + w, t = spot.y + h }
end

local function Spots(group, boxes, icons)
	local slot, focus = boxes[VIEWERS[group].key], boxes["unitframes.focus"]
	if group == "buffs" then
		local list = { { x = slot.r, y = slot.b + 14, right = true, across = true, gaps = { 3 } } }
		local low = boxes["chat.main"] and boxes["chat.main"].b or slot.b
		local edges, rail = {}, boxes["meters.damage"]
		edges[#edges + 1] = focus and focus.l
		edges[#edges + 1] = rail and rail.l
		for _, edge in ipairs(edges) do
			list[#list + 1] = { x = edge - VIEWER_CLEAR, y = slot.b, right = true, slide = true, gaps = DENSE_GAPS }
			list[#list + 1] = { x = edge - VIEWER_CLEAR, y = low, right = true, slide = true, gaps = DENSE_GAPS }
		end
		local target = boxes["unitframes.target"]
		if focus and target then
			list[#list + 1] = { x = focus.r + VIEWER_CLEAR, y = target.t + VIEWER_CLEAR, gaps = DENSE_GAPS }
		end
		return list
	end
	local width = slot.r - slot.l
	local list = { { x = slot.l, y = slot.b, width = width, gaps = { 2 } } }
	local tot, utility = boxes["unitframes.targettarget"], boxes["cooldowns.utility"]
	if tot and utility then
		list[#list + 1] = { x = tot.l, y = utility.t + VIEWER_CLEAR, width = width, gaps = { 2 } }
	end
	if focus then
		list[#list + 1] = { x = focus.l, y = focus.t + FOCUS_CLEAR, width = width, trim = true, gaps = { 2 } }
		if icons then
			list[#list + 1] = { x = icons.rect.r + VIEWER_CLEAR, y = focus.t + FOCUS_CLEAR, width = width, trim = true, gaps = { 2 } }
		end
	end
	local rail = boxes["meters.damage"]
	if rail then
		list[#list + 1] = { x = rail.l - VIEWER_CLEAR, y = slot.b, right = true, width = width, trim = true, gaps = { 2 } }
	end
	return list
end

local function Try(view, spot, n, scale, gap, k, others, rw, rh)
	local item = (spot.width and view.height or view.width) * scale / k
	gap = floor(gap / scale + 0.5) * scale
	local length = n * item + (n - 1) * gap / k
	local thick, least = item, item
	if spot.width then
		local base = view.width * scale / k
		least = base * BAR_WIDTH_MIN / 100
		thick = Clamp(spot.width, least, base * BAR_WIDTH_MAX / 100)
	end
	local rect = Shape(spot, length, thick)
	for _ = 1, SLIDES do
		local ok, hit = Clear(rect, others, rw, rh)
		if ok then
			return rect
		end
		if spot.trim and hit and hit.r + VIEWER_CLEAR > rect.l and hit.r + VIEWER_CLEAR < rect.r - least then
			rect.l = hit.r + VIEWER_CLEAR
		elseif spot.slide and hit and hit.l < rect.r and hit.l > rect.l - item then
			local shift = rect.r - (hit.l - VIEWER_CLEAR)
			rect.l, rect.r = rect.l - shift, rect.r - shift
		else
			return nil
		end
	end
end

local function Search(view, spots, n, k, others, rw, rh, least)
	for _, spot in ipairs(spots) do
		local base = spot.width and view.height or view.width
		local minimum = base * VIEWER_SIZE_MIN / 100 / k
		local cap = max(view.cap, minimum)
		if not spot.width then
			local step = floor((view.cap * k / base * 100 - VIEWER_SIZE_MIN) / VIEWER_SIZE_STEP + 0.5)
			cap = base * Clamp(VIEWER_SIZE_MIN + step * VIEWER_SIZE_STEP, VIEWER_SIZE_MIN, VIEWER_SIZE_MAX) / 100 / k
		end
		for step = VIEWER_SIZE_MAX, VIEWER_SIZE_MIN, -VIEWER_SIZE_STEP do
			local scale = step / 100
			local thick = (spot.width and view.height or view.width) * scale / k
			if thick <= cap + 0.01 and thick >= least - 0.01 then
				for _, gap in ipairs(spot.gaps) do
					local rect = Try(view, spot, n, scale, gap, k, others, rw, rh)
					if rect then
						return spot, step, gap, rect
					end
				end
			end
		end
	end
end

local function Most(view, spots, n, k, others, rw, rh)
	local best, most, rect = spots[1], 0, nil
	local scale = VIEWER_SIZE_MIN / 100
	for _, spot in ipairs(spots) do
		local gap = spot.gaps[#spot.gaps]
		for m = n - 1, most + 1, -1 do
			local fit = Try(view, spot, m, scale, gap, k, others, rw, rh)
			if fit then
				best, most, rect = spot, m, fit
				break
			end
		end
	end
	return best, most, rect
end

local function Viewer(group, k, rw, rh, boxes, others, notes, chosen)
	local enum = Enum
	local indices, setting = enum.EditModeCooldownViewerSystemIndices, enum.EditModeCooldownViewerSetting
	local view = VIEWERS[group]
	if not (boxes[view.key] and IsTable(indices) and IsTable(setting) and indices[view.index] ~= nil) then
		return nil
	end
	local bars = group == "bars"
	local n = max(VIEWER_MIN_ITEMS, EditMode.Tracked(group))
	local spots = Spots(group, boxes, chosen.buffs)
	local spot, percent, gap, rect = Search(view, spots, n, k, others, rw, rh, view.floor)
	if not spot then
		spot, percent, gap, rect = Search(view, spots, n, k, others, rw, rh, 0)
	end
	if not spot then
		local _, most = Most(view, spots, n, k, others, rw, rh)
		notes[#notes + 1] = { group = group, count = n, fits = most }
		return nil
	end
	others[#others + 1] = rect
	chosen[group] = { spot = spot, rect = rect }
	local settings = {}
	if setting.IconSize ~= nil then
		settings[setting.IconSize] = (percent - VIEWER_SIZE_MIN) / VIEWER_SIZE_STEP
	end
	if setting.IconPadding ~= nil then
		settings[setting.IconPadding] = view.offset + floor(gap / (percent / 100) + 0.5)
	end
	local orientation, direction = enum.CooldownViewerOrientation, enum.CooldownViewerIconDirection
	if not bars and IsTable(orientation) and setting.Orientation ~= nil then
		settings[setting.Orientation] = spot.across and orientation.Horizontal or orientation.Vertical
	end
	if not bars and IsTable(direction) and setting.IconDirection ~= nil then
		settings[setting.IconDirection] = direction.Right
	end
	if bars and setting.BarWidthScale ~= nil then
		local width = floor(Clamp((rect and rect.r - rect.l or spot.width) * k / (view.width * percent / 100) * 100, BAR_WIDTH_MIN, BAR_WIDTH_MAX) + 0.5)
		settings[setting.BarWidthScale] = width - BAR_WIDTH_MIN
	end
	local label = bars and "Blizzard's tracked buff bars" or "Blizzard's tracked buff icons"
	local x = rect and (spot.right and rect.r or rect.l) or spot.x
	return { label = label, system = enum.EditModeSystem.CooldownViewer, index = indices[view.index], point = spot.right and "BOTTOMRIGHT" or "BOTTOMLEFT", x = x * k, y = spot.y * k, settings = settings }
end

local function RowRect(point, slot, n, lines, item, pad)
	local across = ceil(n / lines)
	local w, h = across * item + (across - 1) * pad, lines * item + (lines - 1) * pad
	local l = point == "BOTTOM" and (slot.l + slot.r - w) / 2 or point == "BOTTOMRIGHT" and slot.r - w or slot.l
	return { l = l, b = slot.b, r = l + w, t = slot.b + h }, across
end

local function RowFit(row, slot, n, k, others, rw, rh)
	local height = slot.t - slot.b
	local gap = (slot.r - slot.l - row.fallback * height) / (row.fallback - 1)
	for lines = 1, ROW_LINES do
		for _, point in ipairs(row.spots) do
			for step = VIEWER_SIZE_MAX, VIEWER_SIZE_MIN, -VIEWER_SIZE_STEP do
				local item = row.size * step / 100 / k
				if item <= height + 0.01 or step == VIEWER_SIZE_MIN then
					local wanted = Clamp(floor(gap * k * 100 / step + 0.5) + PADDING_OFFSET, PADDING_OFFSET, PADDING_MAX)
					for _, padding in ipairs({ wanted, PADDING_OFFSET }) do
						local rect, across = RowRect(point, slot, n, lines, item, (padding - PADDING_OFFSET) * step / 100 / k)
						if across <= ICON_LIMIT_MAX and Clear(rect, others, rw, rh) then
							return rect, step, padding, across, point
						end
					end
				end
			end
		end
	end
end

local function Rows(name, k, rw, rh, notes)
	local enum = Enum
	local indices, setting = enum.EditModeCooldownViewerSystemIndices, enum.EditModeCooldownViewerSetting
	local orientation, direction = enum.CooldownViewerOrientation, enum.CooldownViewerIconDirection
	local places, placed = {}, {}
	if enum.EditModeSystem.CooldownViewer == nil or not (IsTable(indices) and IsTable(setting)) then
		return places
	end
	for _, group in ipairs(ROW_ORDER) do
		local row = ROWS[group]
		local slot = Native(group) and indices[row.index] ~= nil and Box(name, row.key, rw, rh)
		if slot then
			local others = Others(name, rw, rh, { [row.key] = true })
			for _, rect in ipairs(placed) do
				others[#others + 1] = rect
			end
			local n = max(VIEWER_MIN_ITEMS, EditMode.Tracked(group))
			local rect, percent, padding, across, point = RowFit(row, slot, n, k, others, rw, rh)
			if rect then
				placed[#placed + 1] = rect
				local settings = {}
				if setting.Orientation ~= nil and IsTable(orientation) then
					settings[setting.Orientation] = orientation.Horizontal
				end
				if setting.IconDirection ~= nil and IsTable(direction) then
					settings[setting.IconDirection] = direction.Right
				end
				if setting.IconLimit ~= nil then
					settings[setting.IconLimit] = across
				end
				if setting.IconSize ~= nil then
					settings[setting.IconSize] = (percent - VIEWER_SIZE_MIN) / VIEWER_SIZE_STEP
				end
				if setting.IconPadding ~= nil then
					settings[setting.IconPadding] = padding
				end
				local x = point == "BOTTOM" and (rect.l + rect.r) / 2 or point == "BOTTOMRIGHT" and rect.r or rect.l
				places[#places + 1] = { label = row.label, system = enum.EditModeSystem.CooldownViewer, index = indices[row.index], row = group, rect = rect, point = point, x = x * k, y = rect.b * k, settings = settings }
			else
				local most = 0
				for m = n - 1, VIEWER_MIN_ITEMS, -1 do
					if RowFit(row, slot, m, k, others, rw, rh) then
						most = m
						break
					end
				end
				log("Edit Mode: " .. n .. " " .. group .. " cooldowns fit nowhere clear; Blizzard's viewer keeps the place it had")
				notes[#notes + 1] = { group = group, count = n, fits = most }
			end
		end
	end
	return places
end

local function Sink(lane, rects, clear, height)
	local moved = true
	while moved do
		moved, lane.b = false, lane.t - height
		for _, o in ipairs(rects) do
			if lane.l < o.r + clear and o.l - clear < lane.r and lane.b < o.t + clear and o.b - clear < lane.t then
				lane.t, moved = o.b - clear, true
			end
		end
	end
	return lane
end

local function Warning(name, k, rw, rh, others, chosen)
	local system, sigil = Enum.EditModeSystem.RaidWarning, Box(name, "unitframes.target", rw, rh)
	local rects, xs = {}, { rw / 2 }
	local story = StoryBox(name, rw, rh)
	rects[1] = story
	local left, right = Box(name, "chat.main", rw, rh), story or Box(name, "minimap.main", rw, rh)
	if system == nil or not (sigil and left and right) then
		return nil
	end
	local frame = RaidWarningFrame
	local width = IsTable(frame) and Fn(frame, "GetWidth") and frame:GetWidth()
	local clear, half, height = Layouts.SIGIL_CLEAR, (Plain(width) and width or WARNING_WIDTH) / k / 2, WARNING_HEIGHT / k
	for _, rect in ipairs(others) do
		if not rect.quests then
			rects[#rects + 1] = rect
		end
	end
	for _, pick in pairs(chosen) do
		rects[#rects + 1] = pick.rect
	end
	for _, o in ipairs(rects) do
		xs[#xs + 1], xs[#xs + 2] = o.r + clear + half, o.l - clear - half
	end
	local best
	local top = rh * (1 - WARNING_TOP)
	for _, x in ipairs(xs) do
		if x - half >= left.r + clear and x + half <= right.l - clear then
			local lane = Sink({ l = x - half, r = x + half, t = top, x = x }, rects, clear, height)
			if lane.b >= sigil.t + clear and (not best or lane.t > best.t or (lane.t == best.t and abs(x - rw / 2) < abs(best.x - rw / 2))) then
				best = lane
			end
		end
	end
	if not best then
		log("Edit Mode: no free band between the rails holds the raid warnings; they stay where Edit Mode puts them")
		return nil
	end
	return { label = "the raid and boss warnings", system = system, point = "TOP", x = best.x * k, y = best.t * k, settings = {} }
end

local function Places(name, story, notes)
	local enum, k = Enum, Factor()
	local places = {}
	local tracker = EditMode.TrackerPlace(story.tracker)
	local trackerSettings = {}
	local trackerSetting = IsTable(enum.EditModeObjectiveTrackerSetting) and enum.EditModeObjectiveTrackerSetting.Height
	if trackerSetting ~= nil and trackerSetting ~= false then
		local height = (story.tracker.top - story.tracker.bottom) * k
		trackerSettings[trackerSetting] = Clamp(floor((height - TRACKER_HEIGHT_MIN) / TRACKER_HEIGHT_STEP), 0, TRACKER_HEIGHT_STEPS)
	end
	places[#places + 1] = { label = "the objective tracker", system = enum.EditModeSystem.ObjectiveTracker, x = tracker.x * k, y = tracker.y * k, settings = trackerSettings }
	local meterSystem = enum.EditModeSystem.DamageMeter
	local position = Positions(name)["meters.damage"]
	local w, h = Layouts.Footprint(name, "meters.damage")
	if meterSystem ~= nil and position and w then
		local rw, rh = Setup.RootSize()
		local l, _, _, t = Layouts.Rect({ width = w, height = h }, position, rw, rh)
		local settings = {}
		local meter = enum.EditModeDamageMeterSetting
		if IsTable(meter) and meter.FrameWidth ~= nil and meter.FrameHeight ~= nil then
			settings[meter.FrameWidth] = floor(Clamp(w * k, METER_WIDTH_MIN, METER_WIDTH_MAX) - METER_WIDTH_MIN + 0.5)
			settings[meter.FrameHeight] = floor(Clamp(h * k, METER_HEIGHT_MIN, METER_HEIGHT_MAX) - METER_HEIGHT_MIN + 0.5)
		end
		places[#places + 1] = { label = "Blizzard's damage meter", system = meterSystem, x = l * k, y = t * k, settings = settings }
	end
	local rw, rh = Setup.RootSize()
	local rows = Rows(name, k, rw, rh, notes)
	for _, place in ipairs(rows) do
		places[#places + 1] = place
	end
	local chosen = {}
	if enum.EditModeSystem.CooldownViewer ~= nil then
		local others, boxes = Others(name, rw, rh), {}
		for _, place in ipairs(rows) do
			others[#others + 1] = place.rect
		end
		for key in pairs(Positions(name)) do
			boxes[key] = Box(name, key, rw, rh)
		end
		local function Arrange(spare, order)
			local list, out, told, picks = {}, {}, {}, {}
			for i, box in ipairs(others) do
				list[i] = box
			end
			for _, key in ipairs(spare and SPARE or {}) do
				list[#list + 1] = boxes[key]
			end
			for _, group in ipairs(order) do
				out[#out + 1] = Viewer(group, k, rw, rh, boxes, list, told, picks)
			end
			return out, told, picks
		end
		local viewers, told
		for _, spare in ipairs({ true, false }) do
			for _, order in ipairs({ { "buffs", "bars" }, { "bars", "buffs" } }) do
				local out, refused, picked = Arrange(spare, order)
				if #refused == 0 then
					viewers, told, chosen = out, refused, picked
					break
				end
			end
			if viewers then
				break
			end
		end
		if not viewers then
			viewers, told, chosen = Arrange(false, { "buffs", "bars" })
		end
		for _, place in ipairs(viewers) do
			places[#places + 1] = place
		end
		for _, note in ipairs(told) do
			log("Edit Mode: " .. note.count .. " tracked " .. note.group .. " fit nowhere clear; Blizzard's viewer keeps the place it had")
			notes[#notes + 1] = note
		end
	end
	for _, place in ipairs(rows) do
		chosen[place.row] = { rect = place.rect }
	end
	places[#places + 1] = Warning(name, k, rw, rh, Others(name, rw, rh), chosen)
	return places
end

local function FindSystem(layout, system, index)
	for _, entry in ipairs(IsTable(layout.systems) and layout.systems or {}) do
		if IsTable(entry) and entry.system == system then
			if index ~= nil and entry.systemIndex == index then
				return entry
			elseif index == nil and (entry.systemIndex == nil or entry.systemIndex == 1) then
				return entry
			end
		end
	end
end

local function SetSetting(entry, setting, value)
	if not IsTable(entry.settings) then
		entry.settings = {}
	end
	for _, info in ipairs(entry.settings) do
		if IsTable(info) and info.setting == setting then
			info.value = value
			return
		end
	end
	entry.settings[#entry.settings + 1] = { setting = setting, value = value }
end

local function Place(layout, place)
	local entry = FindSystem(layout, place.system, place.index)
	if not entry then
		log("Edit Mode: the layout has no " .. place.label .. " system; it stays where Edit Mode puts it")
		return false
	end
	entry.anchorInfo = { point = place.point or "TOPLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = place.x + ns.Scale.Origin() * Factor(), offsetY = place.y }
	entry.anchorInfo2 = nil
	entry.isInDefaultPosition = false
	for setting, value in pairs(place.settings) do
		SetSetting(entry, setting, value)
	end
	return true
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

local function Stamps(create)
	local store = ns.Store
	local account = store and store.IsLoaded() and store.Account()
	if not IsTable(account) then
		return nil
	end
	if create and not IsTable(account[STAMPS]) then
		account[STAMPS] = {}
	end
	return IsTable(account[STAMPS]) and account[STAMPS] or nil
end

local function Owned(layout, place)
	local entry = FindSystem(layout, place.system, place.index)
	if not entry or entry.isInDefaultPosition == true then
		return true
	end
	local stamps = Stamps()
	local stamp = stamps and IsTable(stamps[layout.layoutName]) and stamps[layout.layoutName][place.index]
	local a = entry.anchorInfo
	if not (IsTable(stamp) and IsTable(stamp.settings) and IsTable(a) and type(a.offsetX) == "number" and type(a.offsetY) == "number") then
		return false
	end
	if not (a.point == stamp.point and a.relativeTo == "UIParent" and a.relativePoint == "BOTTOMLEFT" and abs(a.offsetX - stamp.x) < 0.01 and abs(a.offsetY - stamp.y) < 0.01) then
		return false
	end
	local values = {}
	for _, info in ipairs(IsTable(entry.settings) and entry.settings or {}) do
		if IsTable(info) then
			values[info.setting] = info.value
		end
	end
	for setting, value in pairs(stamp.settings) do
		if values[setting] ~= value then
			return false
		end
	end
	return true
end

local function PlaceRow(layout, place)
	if not Owned(layout, place) then
		log("Edit Mode: " .. place.label .. " stay where you put them in " .. tostring(layout.layoutName))
		return false
	end
	return Place(layout, place)
end

local function Remember(layout, places)
	local stamps = Stamps(true)
	if not stamps then
		return
	end
	local mine = IsTable(stamps[layout.layoutName]) and stamps[layout.layoutName] or {}
	stamps[layout.layoutName] = mine
	for _, place in ipairs(places) do
		local a = FindSystem(layout, place.system, place.index).anchorInfo
		local settings = {}
		for setting, value in pairs(place.settings) do
			settings[setting] = value
		end
		mine[place.index] = { point = a.point, x = a.offsetX, y = a.offsetY, settings = settings }
	end
end

local function MaxLayouts()
	local consts = IsTable(Constants) and Constants.EditModeConsts
	local value = IsTable(consts) and consts.EditModeMaxLayoutsPerType
	return type(value) == "number" and value or nil
end

local function Target(all, presets, layoutName, active)
	local types = Enum.EditModeLayoutType
	local lastAccount, accounts = nil, 0
	for i = presets + 1, #all do
		local layout = all[i]
		if IsTable(layout) and layout.layoutName == layoutName and layout.layoutType ~= types.Preset then
			return i
		end
		if IsTable(layout) and layout.layoutType == types.Account then
			lastAccount, accounts = i, accounts + 1
		end
	end
	local limit = MaxLayouts()
	if limit and accounts >= limit then
		return nil, "every one of the " .. limit .. " account layouts is taken", L["All %d account layouts are in use. Delete one in Edit Mode, then try again."]:format(limit)
	end
	if Fn(C_EditMode, "IsValidLayoutName") then
		local ok, valid = pcall(C_EditMode.IsValidLayoutName, layoutName)
		if not ok or valid ~= true then
			return nil, "Edit Mode refused the name " .. layoutName, L["Edit Mode refused the layout's name."]
		end
	end
	local base = all[active]
	if not IsTable(base) or not IsTable(base.systems) then
		return nil, "the active Edit Mode layout could not be read", L["Edit Mode's active layout could not be read."]
	end
	local layout = Copy(base)
	layout.layoutName, layout.layoutType, layout.layoutIndex = layoutName, types.Account, nil
	local index = (lastAccount or presets) + 1
	table.insert(all, index, layout)
	return index
end

local NOTE = {
	buffs = L["%d tracked buffs don't fit beside your frames (%d would), so they stay where they were."],
	bars = L["%d tracked bars don't fit beside your frames (%d would), so they stay where they were."],
	essential = L["%d essential cooldowns don't fit beside your frames (%d would), so they stay where they were."],
	utility = L["%d utility cooldowns don't fit beside your frames (%d would), so they stay where they were."],
}
local STEP = L["Untrack some in the Cooldown Manager and press Try again, or move them in Edit Mode."]

local last = { state = "none", notes = {} }

function EditMode.Note(note)
	return NOTE[note.group]:format(note.count, note.fits)
end

function EditMode.Step()
	return STEP
end

function EditMode.Last()
	return last
end

function EditMode.Waiting(name)
	last = { state = "waiting", name = name, layout = PREFIX .. name, notes = {} }
end

local function Tell(notes)
	for _, note in ipairs(notes) do
		local line = EditMode.Note(note) .. " " .. STEP
		log("Edit Mode: " .. line)
		ns.Print(line)
	end
end

local function Fail(name, reason, why)
	log("Edit Mode: " .. reason .. "; the quest tracker keeps the story hint")
	ns.Print(L["Edit Mode did not take the KstyleUI layout. Open /kstyle setup and press Try again on its summary."])
	last = { state = "failed", name = name, layout = PREFIX .. name, reason = reason, why = why or L["Edit Mode could not save the layout."], notes = {} }
	return false
end

local function Read()
	if not EditMode.Available() then
		return nil, "C_EditMode is missing on this client", L["This client has no Edit Mode layouts."]
	end
	local ok, info = pcall(C_EditMode.GetLayouts)
	if not ok or not IsTable(info) or not IsTable(info.layouts) then
		return nil, "C_EditMode.GetLayouts gave nothing usable", L["Edit Mode's layouts could not be read."]
	end
	local copied, presetList = pcall(EditModePresetLayoutManager.GetCopyOfPresetLayouts, EditModePresetLayoutManager)
	if not copied or not IsTable(presetList) then
		return nil, "the preset layouts could not be read", L["Edit Mode's layouts could not be read."]
	end
	local all = {}
	for i, layout in ipairs(presetList) do
		all[i] = layout
	end
	for _, layout in ipairs(info.layouts) do
		all[#all + 1] = layout
	end
	return all, #presetList, type(info.activeLayout) == "number" and info.activeLayout or 1
end

function EditMode.Write(name, story)
	local all, presets, active = Read()
	if not all then
		return Fail(name, presets, active)
	end
	local layoutName = PREFIX .. name
	local index, reason, why = Target(all, presets, layoutName, active)
	if not index then
		return Fail(name, reason, why)
	end
	local placed, notes, rows = {}, {}, {}
	local viewer = Enum.EditModeSystem.CooldownViewer
	for _, place in ipairs(Places(name, story, notes)) do
		if place.row then
			if PlaceRow(all[index], place) then
				placed[#placed + 1] = place.label
				rows[#rows + 1] = place
			end
		elseif Place(all[index], place) then
			placed[#placed + 1] = place.label
			if place.system == viewer then
				rows[#rows + 1] = place
			end
		end
	end
	local saved, err = pcall(C_EditMode.SaveLayouts, { layouts = all, activeLayout = index })
	if not saved then
		return Fail(name, "C_EditMode.SaveLayouts failed (" .. tostring(err) .. ")")
	end
	Remember(all[index], rows)
	local activated, refusal = pcall(C_EditMode.SetActiveLayout, index)
	if not activated then
		log("Edit Mode: SetActiveLayout failed (" .. tostring(refusal) .. "); pick " .. layoutName .. " in Edit Mode")
	end
	if not activated then
		last = { state = "failed", name = name, layout = layoutName, reason = "SetActiveLayout failed", why = L["Edit Mode saved it but did not switch to it. Try again, or pick it in Edit Mode."], notes = notes }
		Tell(notes)
		return true
	end
	log("Edit Mode: wrote " .. layoutName .. " with " .. (#placed > 0 and table.concat(placed, ", ") or "nothing") .. " placed, and made it active")
	last = { state = "written", name = name, layout = layoutName, notes = notes }
	Tell(notes)
	return true
end

local function Own(all, active)
	local layout = all[active]
	local layoutName = IsTable(layout) and layout.layoutType ~= Enum.EditModeLayoutType.Preset and layout.layoutName
	local name = type(layoutName) == "string" and layoutName:sub(1, #PREFIX) == PREFIX and layoutName:sub(#PREFIX + 1)
	if name and Layouts.Get(name) and IsTable(layout.systems) then
		return name, layout, layoutName
	end
end

function EditMode.ActiveName()
	local all, _, active = Read()
	return all and (Own(all, active)) or nil
end

local function WriteRows()
	queued = false
	local all, reason, active = Read()
	if not all then
		log("Edit Mode: Blizzard's essential and utility cooldowns stay where Edit Mode puts them (" .. tostring(reason) .. ")")
		return false
	end
	local name, layout, layoutName = Own(all, active)
	if not name then
		log("Edit Mode: the active layout is not one KstyleUI wrote, so Blizzard's essential and utility cooldowns stay where it puts them")
		return false
	end
	local rw, rh = Setup.RootSize()
	local rows, changed = {}, false
	for _, place in ipairs(Rows(name, Factor(), rw, rh, {})) do
		local before = Copy(FindSystem(layout, place.system, place.index))
		if PlaceRow(layout, place) then
			rows[#rows + 1] = place
			changed = changed or not Same(before, FindSystem(layout, place.system, place.index))
		end
	end
	if not changed then
		return false
	end
	local saved, err = pcall(C_EditMode.SaveLayouts, { layouts = all, activeLayout = active })
	if not saved then
		log("Edit Mode: C_EditMode.SaveLayouts failed (" .. tostring(err) .. "); Blizzard's essential and utility cooldowns stay where they were")
		return false
	end
	Remember(layout, rows)
	local activated, refusal = pcall(C_EditMode.SetActiveLayout, active)
	if not activated then
		log("Edit Mode: SetActiveLayout failed (" .. tostring(refusal) .. "); the rows move at the next reload")
	end
	local labels = {}
	for i, place in ipairs(rows) do
		labels[i] = place.label
	end
	log("Edit Mode: placed " .. table.concat(labels, ", ") .. " on KstyleUI's own rows in " .. layoutName)
	return true
end

local function Mine(layout, place)
	local stamps = Stamps()
	local stamp = stamps and IsTable(stamps[layout.layoutName]) and stamps[layout.layoutName][place.index]
	return stamp == nil or Owned(layout, place)
end

function EditMode.Restyle(name, story)
	local all, _, active = Read()
	if not all or Own(all, active) ~= name then
		return false
	end
	local layout, viewer, moved = all[active], Enum.EditModeSystem.CooldownViewer, {}
	for _, place in ipairs(Places(name, story, {})) do
		if place.system == viewer and Mine(layout, place) and Place(layout, place) then
			moved[#moved + 1] = place
		end
	end
	if #moved == 0 then
		return false
	end
	local saved, err = pcall(C_EditMode.SaveLayouts, { layouts = all, activeLayout = active })
	if not saved then
		log("Edit Mode: C_EditMode.SaveLayouts failed (" .. tostring(err) .. "); Blizzard's cooldown viewers keep their places")
		return false
	end
	Remember(layout, moved)
	local activated, refusal = pcall(C_EditMode.SetActiveLayout, active)
	if not activated then
		log("Edit Mode: SetActiveLayout failed (" .. tostring(refusal) .. "); the viewers move at the next reload")
	end
	local labels = {}
	for i, place in ipairs(moved) do
		labels[i] = place.label
	end
	log("Edit Mode: placed " .. table.concat(labels, ", ") .. " for the HUD style in " .. layout.layoutName)
	return true
end

function EditMode.PlaceRows()
	if queued then
		return
	end
	queued = true
	local function Write()
		ns.Combat.Queue(WriteRows)
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, Write)
	else
		Write()
	end
end
