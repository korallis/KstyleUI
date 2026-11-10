-- DevTestEditMode.lua: opt-in, read-only Edit Mode geometry and configuration snapshots in the existing devlog, sampled from an addon-owned frame.
local _, ns = ...

local DevTest = ns.DevTest
local OWNER, INTERVAL = "EditModeRecorder", 0.25
local enabled, active, wasDragging = false, false, false
local frame, elapsed, sample, context = nil, 0, 0, nil
local previous = {}

local function Secret(value)
	return type(issecretvalue) ~= "function" or issecretvalue(value)
end

local function Table(value)
	return not Secret(value) and type(value) == "table"
end

local function Text(value)
	if Secret(value) then
		return "<secret>"
	end
	local kind = type(value)
	if kind ~= "string" and kind ~= "number" and kind ~= "boolean" and kind ~= "nil" then
		return "<" .. kind .. ">"
	end
	local text = tostring(value)
	return #text > 160 and text:sub(1, 144) .. "<truncated>" or text
end

local function Field(object, key)
	if not Table(object) then
		return nil
	end
	local ok, value = pcall(function() return object[key] end)
	if ok then
		return value
	end
	return nil
end

local function Read(object, method, ...)
	local fn = Field(object, method)
	if Secret(fn) or type(fn) ~= "function" then
		return false
	end
	return pcall(fn, object, ...)
end

local function Name(object)
	if not Table(object) then
		return Text(object)
	end
	local ok, name = Read(object, "GetDebugName")
	if not ok or (not Secret(name) and name == nil) then
		ok, name = Read(object, "GetName")
	end
	return ok and Text(name) or "<unavailable>"
end

local function Value(object, method)
	local ok, value = Read(object, method)
	return ok and Text(value) or "<unavailable>"
end

local function Log(message)
	local total = math.max(1, math.ceil(#message / 800))
	for part = 1, total do
		DevTest.Log(OWNER, "sample=" .. sample .. " part=" .. part .. "/" .. total .. " "
			.. message:sub((part - 1) * 800 + 1, part * 800))
	end
end

local function Snapshot(object)
	if not Table(object) then
		return "object=" .. Text(object), true
	end
	local ok, left, bottom, width, height = Read(object, "GetRect")
	local missing = not ok
	local rect = {}
	for i = 1, 4 do
		local value = select(i, left, bottom, width, height)
		if not Secret(value) and value == nil then
			missing = true
		end
		rect[i] = Text(value)
	end
	local parentOK, parent = Read(object, "GetParent")
	local lines = {
		"object=" .. Name(object) .. " parent=" .. (parentOK and Name(parent) or "<unavailable>")
			.. " rect=" .. (ok and table.concat(rect, ",") or "<unavailable>")
			.. " shown=" .. Value(object, "IsShown") .. " visible=" .. Value(object, "IsVisible")
			.. " scale=" .. Value(object, "GetScale") .. " effectiveScale=" .. Value(object, "GetEffectiveScale")
			.. " dragging=" .. Text(Field(object, "isDragging")),
	}
	local pointsOK, count = Read(object, "GetNumPoints")
	lines[#lines + 1] = "points=" .. (pointsOK and Text(count) or "<unavailable>")
	if pointsOK and not Secret(count) and type(count) == "number" and count == count and count >= 0 then
		for i = 1, math.min(math.floor(count), 32) do
			local pointOK, point, relative, relativePoint, x, y = Read(object, "GetPoint", i)
			lines[#lines + 1] = "point[" .. i .. "]=" .. (pointOK and (Text(point) .. "," .. Name(relative)
				.. "," .. Text(relativePoint) .. "," .. Text(x) .. "," .. Text(y)) or "<unavailable>")
		end
		if count > 32 then
			lines[#lines + 1] = "points=<truncated after 32>"
		end
	end
	return table.concat(lines, " | "), missing
end

local function Settings(lines, path, value, seen, depth)
	if not Table(value) then
		lines[#lines + 1] = path .. "=" .. Text(value)
		return
	end
	if seen[value] or depth > 8 then
		lines[#lines + 1] = path .. "=<cycle/depth limit>"
		return
	end
	seen[value] = true
	local entries = {}
	for key, item in pairs(value) do
		entries[#entries + 1] = { key = Text(key), value = item }
	end
	table.sort(entries, function(a, b) return a.key < b.key end)
	for _, entry in ipairs(entries) do
		Settings(lines, path .. "." .. entry.key, entry.value, seen, depth + 1)
	end
	seen[value] = nil
end

local function Context(phase)
	local store = ns.Store
	local profile = store.Profile()
	local lines = { "phase=" .. phase .. " profile=" .. Text(store.ProfileName()) }
	local names = {}
	for name in pairs(ns.Features.modules) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		lines[#lines + 1] = "module=" .. name .. " enabled=" .. Text(Field(Field(profile, name), "enabled"))
			.. " running=" .. Text(ns.Modules.IsRunning(name))
	end
	Settings(lines, "settings", profile, {}, 0)
	local manager = EditModeManagerFrame
	local info = Field(manager, "layoutInfo")
	local ok, layout = Read(manager, "GetActiveLayoutInfo")
	lines[#lines + 1] = "mergedActiveIndex=" .. Text(Field(info, "activeLayout"))
	lines[#lines + 1] = "activeName=" .. (ok and Table(layout) and Text(Field(layout, "layoutName")) or "<unavailable>")
	lines[#lines + 1] = "activeType=" .. (ok and Table(layout) and Text(Field(layout, "layoutType")) or "<unavailable>")
	local preset = Field(Field(Enum, "EditModeLayoutType"), "Preset")
	local list = Field(info, "layouts")
	local count, readable = 0, Table(list) and not Secret(preset) and type(preset) == "number"
	if readable then
		for _, entry in pairs(list) do
			local kind = Field(entry, "layoutType")
			if Secret(kind) or type(kind) ~= "number" then
				readable = false
			elseif kind == preset then
				count = count + 1
			end
		end
	end
	lines[#lines + 1] = "presetCount=" .. (readable and Text(count) or "<unavailable>")
	local stamp = table.concat(lines, "\n")
	if stamp == context then
		return
	end
	context = stamp
	local chunk = ""
	for _, line in ipairs(lines) do
		if #chunk + #line > 780 then
			Log(chunk)
			chunk = ""
		end
		chunk = chunk .. (#chunk > 0 and "; " or "") .. line
	end
	if #chunk > 0 then
		Log(chunk)
	end
end

local function Capture(system, phase, force)
	local selection = Field(system, "Selection")
	local body, missing = Snapshot(system)
	local selected, selectionMissing = Snapshot(selection)
	if not force and not missing and not selectionMissing then
		return
	end
	local key = Table(system) and system or "ObjectiveTrackerFrame"
	local stamp = phase .. "\n" .. body .. "\n" .. selected
	if previous[key] == stamp then
		return
	end
	previous[key] = stamp
	Log("phase=" .. phase .. " system " .. body)
	Log("phase=" .. phase .. " selection " .. selected)
end

local function Poll()
	if not enabled or not ns.Store.IsLoaded() then
		return
	end
	local manager = EditModeManagerFrame
	local ok, on = Read(manager, "IsEditModeActive")
	if not ok or Secret(on) or on ~= true then
		if active then
			sample = sample + 1
			Capture(ObjectiveTrackerFrame, "exit", true)
			Log("Edit Mode exited")
		end
		active, wasDragging = false, false
		return
	end
	local systems = Field(manager, "registeredSystemFrames")
	local dragging = false
	if Table(systems) then
		for _, system in pairs(systems) do
			local value = Field(system, "isDragging")
			if not Secret(value) and value == true then
				dragging = true
			end
		end
	end
	if active and not dragging and not wasDragging then
		return
	end
	sample = sample + 1
	local phase = not active and "enter" or (dragging and "drag" or "release")
	if not active or (dragging and not wasDragging) then
		Context(phase)
	end
	Capture(ObjectiveTrackerFrame, phase, true)
	if Table(systems) then
		for _, system in pairs(systems) do
			if not Secret(system) and (Secret(ObjectiveTrackerFrame) or system ~= ObjectiveTrackerFrame) then
				Capture(system, phase, false)
			end
		end
	end
	active, wasDragging = true, dragging
end

function DevTest.EditModeLogging()
	return enabled
end

function DevTest.SetEditModeLogging(on)
	if Secret(on) then
		return false
	end
	if enabled and on ~= true then
		Poll()
	end
	enabled = on == true
	active, wasDragging, elapsed, context, previous = false, false, 0, nil, {}
	if enabled and not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnUpdate", function(_, delta)
			if not enabled or Secret(delta) or type(delta) ~= "number" or delta ~= delta or delta < 0 then
				return
			end
			elapsed = elapsed + delta
			if elapsed >= INTERVAL then
				elapsed = 0
				Poll()
			end
		end)
	end
	if frame then
		frame:SetShown(enabled)
	end
	DevTest.Log(OWNER, enabled and ("recording enabled for this session; version=" .. Text(ns.VERSION)
		.. " build=" .. Text(ns.CODE_BUILD)) or "recording disabled")
	if enabled then
		Poll()
	end
	return enabled
end
