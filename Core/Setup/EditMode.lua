-- EditMode.lua: Apply's Edit Mode writer: it copies the active Edit Mode layout into a "KstyleUI <layout>" account layout, puts the objective tracker in the story slot, Blizzard's damage meter on the damage card and its tracked buff icon and bar viewers in their slots (sized to fit, with a setup step when they cannot), saves the layouts and activates that one, out of combat.
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
local VIEWER_CLEAR, VIEWER_MIN_ITEMS = 2, 2
local VIEWERS = {
	buffs = { key = "cooldowns.buffs", index = "BuffIcon", width = 40, height = 40, offset = 4, gap = 8, fallback = 6 },
	bars = { key = "cooldowns.bars", index = "BuffBar", width = 220, height = 30, offset = 2, gap = 2, fallback = 2, tallest = 24 },
}

EditMode.TRACKER_LEFT = 16
EditMode.TRACKER_TOP = 34

local floor, max, min = math.floor, math.max, math.min
local counter

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
	return VIEWERS[group].fallback
end

local function Box(name, key, rw, rh)
	local position = Layouts.Get(name)[key]
	local w, h = Layouts.Footprint(name, key)
	if not (position and w) then
		return nil
	end
	local l, b, r, t = Layouts.Rect({ width = w, height = h }, position, rw, rh)
	return { l = l, b = b, r = r, t = t }
end

local function Others(name, rw, rh)
	local out = {}
	for key in pairs(Layouts.Get(name)) do
		if not key:find("^cooldowns%.") and Layouts.Shown(name, key) ~= false then
			out[#out + 1] = Box(name, key, rw, rh)
		end
	end
	return out
end

local function RowRoom(slot, others)
	local edge = 0
	for _, o in ipairs(others) do
		if o.r <= slot.r and o.b < slot.t and slot.b < o.t then
			edge = max(edge, o.r)
		end
	end
	return slot.r - edge - VIEWER_CLEAR
end

local function StackRoom(slot, others, rh)
	local edge = rh
	for _, o in ipairs(others) do
		if o.b >= slot.b and o.l < slot.r and slot.l < o.r then
			edge = min(edge, o.b)
		end
	end
	return edge - slot.b - VIEWER_CLEAR
end

local function Length(view, scale, n, bars)
	local item = (bars and view.height or view.width) * scale
	return n * item + (n - 1) * view.gap
end

local function Fit(view, slot, room, n, k, bars)
	local percent = VIEWER_SIZE_MIN
	for step = VIEWER_SIZE_MAX, VIEWER_SIZE_MIN, -VIEWER_SIZE_STEP do
		local scale = step / 100
		local tall = view.height * scale <= (bars and view.tallest or (slot.t - slot.b)) * k
		local narrow = not bars or view.width * BAR_WIDTH_MIN / 100 * scale <= (slot.r - slot.l) * k
		if tall and narrow and Length(view, scale, n, bars) <= room * k then
			return step, true
		end
	end
	local scale = percent / 100
	local item = (bars and view.height or view.width) * scale
	local fits = floor((room * k + view.gap) / (item + view.gap))
	return percent, false, max(0, fits)
end

local function Viewer(name, group, k, rw, rh, others, notes)
	local enum = Enum
	local indices, setting = enum.EditModeCooldownViewerSystemIndices, enum.EditModeCooldownViewerSetting
	local view = VIEWERS[group]
	local slot = Box(name, view.key, rw, rh)
	if not (slot and IsTable(indices) and IsTable(setting) and indices[view.index] ~= nil) then
		return nil
	end
	local bars = group == "bars"
	local n = max(VIEWER_MIN_ITEMS, EditMode.Tracked(group))
	local room = bars and StackRoom(slot, others, rh) or RowRoom(slot, others)
	local percent, fits, most = Fit(view, slot, room, n, k, bars)
	if not fits then
		notes[#notes + 1] = { group = group, count = n, fits = most }
	end
	local settings = {}
	if setting.IconSize ~= nil then
		settings[setting.IconSize] = (percent - VIEWER_SIZE_MIN) / VIEWER_SIZE_STEP
	end
	if setting.IconPadding ~= nil then
		settings[setting.IconPadding] = view.offset + view.gap
	end
	local orientation, direction = enum.CooldownViewerOrientation, enum.CooldownViewerIconDirection
	if not bars and IsTable(orientation) and setting.Orientation ~= nil then
		settings[setting.Orientation] = orientation.Horizontal
	end
	if not bars and IsTable(direction) and setting.IconDirection ~= nil then
		settings[setting.IconDirection] = direction.Left
	end
	if bars and setting.BarWidthScale ~= nil then
		local width = floor(Clamp((slot.r - slot.l) * k / (view.width * percent / 100) * 100, BAR_WIDTH_MIN, BAR_WIDTH_MAX))
		settings[setting.BarWidthScale] = width - BAR_WIDTH_MIN
	end
	local label = bars and "Blizzard's tracked buff bars" or "Blizzard's tracked buff icons"
	local x = bars and slot.l or slot.r
	return { label = label, system = enum.EditModeSystem.CooldownViewer, index = indices[view.index], point = bars and "BOTTOMLEFT" or "BOTTOMRIGHT", x = x * k, y = slot.b * k, settings = settings }
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
	local position = Layouts.Get(name)["meters.damage"]
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
	if enum.EditModeSystem.CooldownViewer ~= nil then
		local rw, rh = Setup.RootSize()
		local others = Others(name, rw, rh)
		for _, group in ipairs({ "buffs", "bars" }) do
			places[#places + 1] = Viewer(name, group, k, rw, rh, others, notes)
		end
	end
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
	entry.anchorInfo = { point = place.point or "TOPLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = place.x, offsetY = place.y }
	entry.anchorInfo2 = nil
	entry.isInDefaultPosition = false
	for setting, value in pairs(place.settings) do
		SetSetting(entry, setting, value)
	end
	return true
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
		return nil, "every one of the " .. limit .. " account layouts is taken"
	end
	if Fn(C_EditMode, "IsValidLayoutName") then
		local ok, valid = pcall(C_EditMode.IsValidLayoutName, layoutName)
		if not ok or valid ~= true then
			return nil, "Edit Mode refused the name " .. layoutName
		end
	end
	local base = all[active]
	if not IsTable(base) or not IsTable(base.systems) then
		return nil, "the active Edit Mode layout could not be read"
	end
	local layout = Copy(base)
	layout.layoutName, layout.layoutType, layout.layoutIndex = layoutName, types.Account, nil
	local index = (lastAccount or presets) + 1
	table.insert(all, index, layout)
	return index
end

local NOTE = {
	buffs = L["%d tracked buffs don't fit beside your action bars; %d do. In the Cooldown Manager, untrack some or show them as bars."],
	bars = L["%d tracked bars don't fit in their slot; %d do. In the Cooldown Manager, untrack some or show them as icons."],
}

local function Tell(notes)
	for _, note in ipairs(notes) do
		local line = NOTE[note.group]:format(note.count, note.fits)
		log("Edit Mode: " .. line)
		ns.Print(line)
	end
end

local function Fail(reason)
	log("Edit Mode: " .. reason .. "; the quest tracker keeps the story hint")
	ns.Print(L["Move the quest tracker into the story rail in Edit Mode."])
	return false
end

function EditMode.Write(name, story)
	if not EditMode.Available() then
		return Fail("C_EditMode is missing on this client")
	end
	local ok, info = pcall(C_EditMode.GetLayouts)
	if not ok or not IsTable(info) or not IsTable(info.layouts) then
		return Fail("C_EditMode.GetLayouts gave nothing usable")
	end
	local copied, presetList = pcall(EditModePresetLayoutManager.GetCopyOfPresetLayouts, EditModePresetLayoutManager)
	if not copied or not IsTable(presetList) then
		return Fail("the preset layouts could not be read")
	end
	local all, presets = {}, #presetList
	for i, layout in ipairs(presetList) do
		all[i] = layout
	end
	for _, layout in ipairs(info.layouts) do
		all[#all + 1] = layout
	end
	local active = type(info.activeLayout) == "number" and info.activeLayout or 1
	local layoutName = PREFIX .. name
	local index, reason = Target(all, presets, layoutName, active)
	if not index then
		return Fail(reason)
	end
	local placed, notes = {}, {}
	for _, place in ipairs(Places(name, story, notes)) do
		if Place(all[index], place) then
			placed[#placed + 1] = place.label
		end
	end
	local saved, err = pcall(C_EditMode.SaveLayouts, { layouts = all, activeLayout = index })
	if not saved then
		return Fail("C_EditMode.SaveLayouts failed (" .. tostring(err) .. ")")
	end
	local activated, why = pcall(C_EditMode.SetActiveLayout, index)
	if not activated then
		log("Edit Mode: SetActiveLayout failed (" .. tostring(why) .. "); pick " .. layoutName .. " in Edit Mode")
	end
	log("Edit Mode: wrote " .. layoutName .. " with " .. (#placed > 0 and table.concat(placed, ", ") or "nothing") .. " placed, and made it active")
	Tell(notes)
	return true
end
