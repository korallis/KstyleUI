-- Core.lua: the spike addon's run log, /kspike command, root canvas and shared helpers.
local _, ns = ...

ns.MAX_ENTRIES = 400
ns.spikes = {}
ns.order = {}
ns.active = {}
ns.panels = {}
ns.userScale = 1
ns.generation = 0

local REFERENCE_HEIGHT = 1080
local REFERENCE_SCALE = 768 / REFERENCE_HEIGHT
local CHAT_PREFIX = "KstyleUI Spike: "
local GROUPS = {
	basic = { what = "the spikes to run anywhere, on each screen", gap = 4 },
	pull = { what = "the spikes to start just before a boss pull", gap = 0 },
}

function ns.Print(text)
	print(CHAT_PREFIX .. text)
end

function ns.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function ns.Describe(value)
	if ns.IsSecret(value) then
		return "<secret>"
	end
	local kind = type(value)
	if kind == "table" or kind == "function" or kind == "userdata" or kind == "thread" then
		return "<" .. kind .. ">"
	end
	return value
end

local function joinPath(path, key)
	return path and (path .. "." .. tostring(key)) or tostring(key)
end

function ns.DeepEqual(a, b, path)
	if type(a) ~= "table" or type(b) ~= "table" then
		if a == b then
			return true
		end
		return false, path or "<root>"
	end
	for key, value in pairs(a) do
		local same, where = ns.DeepEqual(value, b[key], joinPath(path, key))
		if not same then
			return false, where
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false, joinPath(path, key)
		end
	end
	return true
end

function ns.InCombat()
	return InCombatLockdown ~= nil and InCombatLockdown() == true
end

local afterCombat = {}
local afterCombatListener

function ns.OutOfCombat(fn)
	if not ns.InCombat() then
		fn()
		return
	end
	afterCombat[#afterCombat + 1] = fn
	if not afterCombatListener then
		afterCombatListener = ns.Listen({ "PLAYER_REGEN_ENABLED" }, function()
			local queued = afterCombat
			afterCombat = {}
			for _, queuedFn in ipairs(queued) do
				local ok, err = pcall(queuedFn)
				if not ok then
					ns.Print("cleanup after combat failed: " .. tostring(err))
				end
			end
		end)
	end
end

function ns.EnumName(enum, value)
	if type(enum) ~= "table" or ns.IsSecret(value) or value == nil then
		return nil
	end
	for name, candidate in pairs(enum) do
		if candidate == value then
			return name
		end
	end
	return nil
end

function ns.Try(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		return "error: " .. tostring(result)
	end
	return ns.Describe(result)
end

function ns.Now()
	return GetTime and GetTime() or 0
end

function ns.Build()
	if not GetBuildInfo then
		return "unknown"
	end
	local version, build = GetBuildInfo()
	return tostring(version) .. "." .. tostring(build)
end

function ns.After(seconds, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(seconds, fn)
		return true
	end
	return false
end

function ns.Later(seconds, fn)
	local generation = ns.generation
	return ns.After(seconds, function()
		if ns.generation == generation then
			fn()
		end
	end)
end

function ns.Ticker(seconds, fn)
	if C_Timer and C_Timer.NewTicker then
		return C_Timer.NewTicker(seconds, fn)
	end
	return nil
end

function ns.Screenshot(run)
	if type(Screenshot) ~= "function" then
		return false
	end
	local ok, err = pcall(Screenshot)
	if run then
		run:Add("screenshots", { t = run:Since(), time = GetServerTime and GetServerTime() or 0, ok = ok, error = not ok and tostring(err) or nil })
	end
	return ok
end

-- Run log --------------------------------------------------------------------------------------

function ns.DB()
	if type(KstyleUISpikeDB) ~= "table" then
		KstyleUISpikeDB = {}
	end
	KstyleUISpikeDB.runs = KstyleUISpikeDB.runs or {}
	KstyleUISpikeDB.autostart = KstyleUISpikeDB.autostart or {}
	return KstyleUISpikeDB
end

local Run = {}
Run.__index = Run

function Run:Set(key, value)
	if type(value) == "table" and not ns.IsSecret(value) then
		self.data.results[key] = value
	else
		self.data.results[key] = ns.Describe(value)
	end
end

function Run:Count(key, n)
	local results = self.data.results
	results[key] = (results[key] or 0) + (n or 1)
end

function Run:Add(list, entry)
	local results = self.data.results
	local items = results[list]
	if not items then
		items = {}
		results[list] = items
	end
	if #items >= ns.MAX_ENTRIES then
		self:Count(list .. "Dropped")
		return false
	end
	items[#items + 1] = entry
	return true
end

function Run:Since()
	return math.floor((ns.Now() - self.started) * 1000 + 0.5) / 1000
end

function Run:Note(text)
	self:Add("notes", text)
	ns.Print(self.data.spike .. ": " .. text)
end

function ns.NewRun(name, origin)
	local data = {
		spike = name,
		time = GetServerTime and GetServerTime() or 0,
		build = ns.Build(),
		origin = origin or "command",
		results = {},
	}
	local runs = ns.DB().runs
	runs[#runs + 1] = data
	return setmetatable({ data = data, started = ns.Now() }, Run)
end

-- Events ---------------------------------------------------------------------------------------

function ns.Listen(events, handler)
	local frame = CreateFrame("Frame")
	local failed = {}
	for _, event in ipairs(events) do
		if not pcall(frame.RegisterEvent, frame, event) then
			failed[#failed + 1] = event
		end
	end
	frame:SetScript("OnEvent", function(_, event, ...)
		handler(event, ...)
	end)
	return frame, failed
end

function ns.Unlisten(frame)
	if frame then
		frame:UnregisterAllEvents()
		frame:SetScript("OnEvent", nil)
	end
end

-- Root canvas and panels -----------------------------------------------------------------------

function ns.RootScale(uiEffectiveScale, userScale)
	return REFERENCE_SCALE / uiEffectiveScale * (userScale or 1)
end

function ns.PixelUnits(n, physicalHeight, userScale)
	return n * REFERENCE_HEIGHT / physicalHeight / (userScale or 1)
end

function ns.BorderPixels(physicalHeight)
	return math.max(1, math.floor(physicalHeight / REFERENCE_HEIGHT + 0.5))
end

function ns.ApplyRootScale()
	if ns.root then
		ns.root:SetScale(ns.RootScale(UIParent:GetEffectiveScale(), ns.userScale))
	end
end

function ns.Root()
	if not ns.root then
		ns.root = CreateFrame("Frame", "KstyleUISpike_Root", UIParent)
		ns.root:SetAllPoints(UIParent)
		ns.root:SetFrameStrata("DIALOG")
		ns.Listen({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }, ns.ApplyRootScale)
		ns.ApplyRootScale()
	end
	return ns.root
end

function ns.Text(parent, template, layer)
	local text = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
	text:SetJustifyH("LEFT")
	return text
end

function ns.Panel(key, title, width, height)
	local panel = ns.panels[key]
	if not panel then
		panel = CreateFrame("Frame", nil, ns.Root())
		panel:SetFrameStrata("DIALOG")
		panel:SetPoint("CENTER")
		panel:SetClampedToScreen(true)
		panel:EnableMouse(true)
		panel:SetMovable(true)
		panel:RegisterForDrag("LeftButton")
		panel:SetScript("OnDragStart", function() panel:StartMoving() end)
		panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
		local background = panel:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0.063, 0.063, 0.063, 0.94)
		panel.title = ns.Text(panel, "GameFontHighlightLarge")
		panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -12)
		local close = CreateFrame("Button", nil, panel, "UIPanelCloseButtonNoScripts")
		close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
		close:SetScript("OnClick", function() panel:Hide() end)
		ns.panels[key] = panel
	end
	for other, shown in pairs(ns.panels) do
		if other ~= key then
			shown:Hide()
		end
	end
	panel:SetSize(width, height)
	panel.title:SetText(title)
	panel:Show()
	return panel
end

-- Spikes ---------------------------------------------------------------------------------------

function ns.Register(name, def)
	ns.spikes[name] = def
	ns.order[#ns.order + 1] = name
end

function ns.Stop(name, reason, run)
	local entry = ns.active[name]
	if not entry or (run and entry.run ~= run) then
		return
	end
	ns.active[name] = nil
	local ok, err = pcall(entry.stop, reason)
	if not ok then
		entry.run:Set("stopError", tostring(err))
	end
	entry.run:Set("finished", true)
	entry.run:Set("stoppedBy", reason)
	ns.Print(name .. " finished (" .. reason .. "). Type /reload to save the results.")
end

function ns.Start(name, args, origin)
	local def = ns.spikes[name]
	ns.Stop(name, "restarted")
	local run = ns.NewRun(name, origin)
	if args and args ~= "" then
		run.data.args = args
	end
	local ok, result = pcall(def.Run, run, args or "")
	if not ok then
		run:Set("error", tostring(result))
		ns.Print(name .. " failed: " .. tostring(result))
	elseif type(result) == "function" then
		ns.active[name] = { run = run, stop = result }
		if def.autostart then
			ns.DB().autostart[name] = true
		end
		ns.Print(name .. " started.")
	else
		run:Set("finished", true)
		ns.Print(name .. " done.")
	end
	return run
end

local function PrintUsage()
	ns.Print("/kspike <name> runs one spike. /kspike list names them.")
	for group, info in pairs(GROUPS) do
		ns.Print("/kspike " .. group .. " runs " .. info.what .. ".")
	end
	ns.Print("/kspike stop ends running spikes. /kspike hide closes panels. /kspike status shows progress.")
	ns.Print("/kspike shot takes a screenshot into _forever_/Screenshots.")
end

function ns.Command(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "help" then
		PrintUsage()
	elseif cmd == "list" then
		for _, name in ipairs(ns.order) do
			local def = ns.spikes[name]
			ns.Print(name .. " (" .. (def.group or "alone") .. "): " .. def.summary)
		end
	elseif cmd == "stop" then
		ns.generation = ns.generation + 1
		for name in pairs(ns.active) do
			ns.Stop(name, "command")
		end
		local autostart = ns.DB().autostart
		for name in pairs(autostart) do
			autostart[name] = nil
		end
	elseif cmd == "shot" then
		ns.Screenshot()
	elseif cmd == "hide" then
		for _, panel in pairs(ns.panels) do
			panel:Hide()
		end
	elseif cmd == "status" then
		local running = {}
		for name in pairs(ns.active) do
			running[#running + 1] = name
		end
		ns.Print(#ns.DB().runs .. " runs logged. Running: " .. (#running > 0 and table.concat(running, ", ") or "none") .. ".")
	elseif GROUPS[cmd] then
		local delay = 0
		for _, name in ipairs(ns.order) do
			if ns.spikes[name].group == cmd then
				if delay == 0 then
					ns.Start(name, "", cmd)
				else
					ns.Later(delay, function() ns.Start(name, "", cmd) end)
				end
				delay = delay + GROUPS[cmd].gap
			end
		end
	elseif ns.spikes[cmd] then
		ns.Start(cmd, rest, "command")
	else
		ns.Print("unknown spike: " .. cmd .. ". Type /kspike list.")
	end
end

SLASH_KSPIKE1 = "/kspike"
SlashCmdList.KSPIKE = ns.Command

ns.Listen({ "ADDON_LOADED", "PLAYER_LOGIN" }, function(event, addon)
	if event == "ADDON_LOADED" and addon == "KstyleUI_Spike" then
		ns.DB()
	elseif event == "PLAYER_LOGIN" then
		ns.Print("loaded on build " .. ns.Build() .. ". Type /kspike for help.")
		for _, name in ipairs(ns.order) do
			if ns.DB().autostart[name] then
				ns.Start(name, "", "PLAYER_LOGIN")
			end
		end
	end
end)
