-- Layout.lua: the Layout registry: each element's per-profile position, size, scale, strata, shown rule and opacity, applied in whole pixels, and Layout Mode sessions with undo.
local addonName, ns = ...

local Layout = ns.Layout
local G, Rules, History = Layout.Geometry, Layout.Rules, Layout.History
local Scale, Store, Combat, Motion, Tokens, L = ns.Scale, ns.Store, ns.Combat, ns.Motion, ns.Tokens, ns.L

local abs, max, min, format = math.abs, math.max, math.min, string.format

local SECTION = "Layout"
local MAX_KEY = 64
local MAX_OFFSET = 8192
local MAX_SIZE = 8192
local DEFAULT_MIN_SIZE = 8
local DEFAULT_MAX_SIZE = 4096
local DEFAULT_SIZE = 100
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 2, 0.05
local HISTORY_LIMIT = 100
local HOOK_DEPTH = 4
local HOVER_POLL = 0.1
local GRID_MIN, GRID_MAX, GRID_STEP = 4, 64, 4
local SNAP_MIN, SNAP_MAX, SNAP_STEP = 2, 24, 1
local DEFAULT_STRATA = "MEDIUM"
local FALLBACK_ROOT_W, FALLBACK_ROOT_H = 1920, 1080

Layout.SCALE_MIN, Layout.SCALE_MAX, Layout.SCALE_STEP = SCALE_MIN, SCALE_MAX, SCALE_STEP

local FIELDS = { "anchor", "x", "y", "width", "height", "scale", "shown", "alphaCombat", "alphaIdle", "strata" }
local IS_FIELD = {}
for _, field in ipairs(FIELDS) do
	IS_FIELD[field] = true
end
Layout.FIELDS = FIELDS

local STRATA = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true }

Layout.SHOWN_OPTIONS = {
	{ value = "always", label = L["Always"] },
	{ value = "combat", label = L["In combat only"] },
	{ value = "noCombat", label = L["Out of combat only"] },
	{ value = "target", label = L["With a target"] },
	{ value = "mouseover", label = L["On mouseover"] },
	{ value = "never", label = L["Never"] },
}
Layout.STRATA_OPTIONS = {
	{ value = "BACKGROUND", label = L["Background"] },
	{ value = "LOW", label = L["Low"] },
	{ value = "MEDIUM", label = L["Medium"] },
	{ value = "HIGH", label = L["High"] },
}
Layout.ANCHOR_OPTIONS = {
	{ value = "TOPLEFT", label = L["Top left"] },
	{ value = "TOP", label = L["Top"] },
	{ value = "TOPRIGHT", label = L["Top right"] },
	{ value = "LEFT", label = L["Left"] },
	{ value = "CENTER", label = L["Centre"] },
	{ value = "RIGHT", label = L["Right"] },
	{ value = "BOTTOMLEFT", label = L["Bottom left"] },
	{ value = "BOTTOM", label = L["Bottom"] },
	{ value = "BOTTOMRIGHT", label = L["Bottom right"] },
}


Layout.defaults = {
	grid = false,
	gridSize = 16,
	snap = true,
	snapDistance = 8,
	calm = true,
	preset = "DPS",
}

Layout.schema = {
	{ type = "header", label = L["Layout Mode"] },
	{
		type = "toggle", key = "grid", label = L["Show the grid"],
		help = L["Draws a grid in Layout Mode, and elements snap to its lines."],
	},
	{
		type = "slider", key = "gridSize", label = L["Grid spacing"],
		help = L["The distance between grid lines, in interface units."],
		min = GRID_MIN, max = GRID_MAX, step = GRID_STEP,
	},
	{
		type = "toggle", key = "snap", label = L["Snap while dragging"],
		help = L["Snaps to other elements, the screen edges and the centre as you drag."],
	},
	{
		type = "slider", key = "snapDistance", label = L["Snap distance"],
		help = L["How close an edge comes, in interface units, before it snaps."],
		min = SNAP_MIN, max = SNAP_MAX, step = SNAP_STEP,
	},
	{ type = "header", label = L["Combat"] },
	{
		type = "toggle", key = "calm", label = L["Calm the rails in combat"],
		help = L["In combat, chat, the map, the menus and the XP line fade until you point at them."],
	},
}

Store.RegisterDefaults(SECTION, Layout.defaults)
ns.Options.Register(SECTION, Layout.schema)

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function IsFinite(v)
	return not IsSecret(v) and type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local SETTING_VALID = {
	grid = function(v) return type(v) == "boolean" end,
	snap = function(v) return type(v) == "boolean" end,
	gridSize = function(v) return IsFinite(v) and v >= GRID_MIN and v <= GRID_MAX end,
	snapDistance = function(v) return IsFinite(v) and v >= SNAP_MIN and v <= SNAP_MAX end,
	calm = function(v) return type(v) == "boolean" end,
	preset = function(v)
		local setup = ns.Setup
		return type(v) == "string" and setup ~= nil and setup.Layouts ~= nil and setup.Layouts.Get(v) ~= nil
	end,
}

function Layout.Setting(key)
	local valid = SETTING_VALID[key]
	if not valid then
		error("KstyleUI.Layout.Setting: unknown setting " .. tostring(key), 2)
	end
	if Store.IsLoaded() then
		local value = Store.Module(SECTION)[key]
		if valid(value) then
			return value
		end
	end
	return Layout.defaults[key]
end

local function Log(message)
	local devtest = ns.DevTest
	if devtest and devtest.Log then
		pcall(devtest.Log, SECTION, message)
	end
end

local logged = {}
local function LogOnce(id, message)
	if not logged[id] then
		logged[id] = true
		Log(message)
	end
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

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not Same(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function Clamp(v, low, high)
	return min(max(v, low), high)
end

local function IsProtectedFrame(frame)
	if type(frame.IsProtected) ~= "function" then
		return false
	end
	local protected = frame:IsProtected()
	if IsSecret(protected) then
		return true
	end
	return protected == true
end

local function MayMove(frame)
	return not InCombatLockdown() or not IsProtectedFrame(frame)
end

local function FrameSize(frame)
	local w, h = frame:GetWidth(), frame:GetHeight()
	if not IsFinite(w) or w < 0 then
		w = 0
	end
	if not IsFinite(h) or h < 0 then
		h = 0
	end
	return w, h
end

local function Factor(frame)
	return ns.Widgets.ScaleFactor(frame)
end

local function Positive(a, b, c, d)
	return IsFinite(a) and IsFinite(b) and IsFinite(c) and IsFinite(d) and a > 0 and b > 0 and c > 0 and d > 0
end

function Layout.RootSize()
	local root = Scale.Root()
	local w, h = root:GetWidth(), root:GetHeight()
	if IsFinite(w) and IsFinite(h) and w > 0 and h > 0 then
		return w, h
	end
	local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
	local ps, rs = UIParent:GetEffectiveScale(), root:GetEffectiveScale()
	if Positive(pw, ph, ps, rs) then
		return pw * ps / rs, ph * ps / rs
	end
	return FALLBACK_ROOT_W, FALLBACK_ROOT_H
end

local function TargetExists()
	if type(UnitExists) ~= "function" then
		return false
	end
	local exists = UnitExists("target")
	if IsSecret(exists) then
		return true
	end
	return exists == true
end

local function ModuleRunning(el)
	local module = el.module
	if module == nil or ns.Features.modules[module] == nil then
		return true
	end
	return ns.Modules.IsRunning(module)
end

local elements, order = {}, {}
local byFrame = setmetatable({}, { __mode = "k" })
local showHooked = setmetatable({}, { __mode = "k" })
local hoverOwner = setmetatable({}, { __mode = "k" })
local state = { combat = false, target = false, active = false, combatEvents = false, targetEvents = false }
local history = History.New(HISTORY_LIMIT)
local snapshot
local RESET = {}

local function Mode(name, ...)
	local mode = Layout.Mode
	if mode and type(mode[name]) == "function" then
		ns.Call(mode[name], ...)
	end
end

local function AspectFit(el, width)
	local a, limits = el.aspect, el.limits
	local low = max(limits.minWidth, limits.minHeight * a)
	local high = max(low, min(limits.maxWidth, limits.maxHeight * a))
	local w = Clamp(width, low, high)
	return w, w / a
end

local function CheckOffset(_, v, clamp)
	if not IsFinite(v) then
		return nil, L["a number"]
	end
	if abs(v) > MAX_OFFSET then
		if not clamp then
			return nil, L["a number"]
		end
		v = v > 0 and MAX_OFFSET or -MAX_OFFSET
	end
	return v
end

local function CheckSize(low, high)
	return function(el, v, clamp)
		if not el.opts.resizable then
			return nil, L["a size this element allows; it cannot be resized"]
		end
		if not IsFinite(v) or v <= 0 or (not clamp and v > MAX_SIZE) then
			return nil, L["a size above 0"]
		end
		return Clamp(v, el.limits[low], el.limits[high])
	end
end

local function CheckAlpha(_, v)
	if IsFinite(v) and v >= 0 and v <= 1 then
		return v
	end
	return nil, L["a number from 0 to 1"]
end

local CHECK = {
	anchor = function(_, v)
		if G.IsAnchor(v) then
			return v
		end
		return nil, L["one of the nine anchors"]
	end,
	x = CheckOffset,
	y = CheckOffset,
	width = CheckSize("minWidth", "maxWidth"),
	height = CheckSize("minHeight", "maxHeight"),
	scale = function(el, v, clamp)
		if not el.opts.scalable then
			return nil, L["1; this element cannot be scaled"]
		end
		if not IsFinite(v) then
			return nil, L["a number"]
		end
		if v < SCALE_MIN or v > SCALE_MAX then
			if not clamp then
				return nil, L["a number from 0.5 to 2"]
			end
			v = Clamp(v, SCALE_MIN, SCALE_MAX)
		end
		return v
	end,
	shown = function(_, v)
		if Rules.IsRule(v) then
			return v
		end
		return nil, L["one of the shown rules"]
	end,
	alphaCombat = CheckAlpha,
	alphaIdle = CheckAlpha,
	strata = function(el, v)
		if type(v) == "string" and (STRATA[v] or v == el.default.strata) then
			return v
		end
		return nil, L["background, low, medium or high"]
	end,
}

local function Entry(key)
	if not Store.IsLoaded() then
		return nil
	end
	local entry = Store.Layout()[key]
	if type(entry) == "table" then
		return entry
	end
end

local function SetEntry(key, entry)
	local layout = Store.Layout()
	if entry == nil or next(entry) == nil then
		layout[key] = nil
	else
		layout[key] = entry
	end
end

local function Resolve(el)
	local s, d = el.settings, el.default
	for i = 1, #FIELDS do
		s[FIELDS[i]] = d[FIELDS[i]]
	end
	local entry = Entry(el.key)
	if entry then
		for i = 1, #FIELDS do
			local field = FIELDS[i]
			local v = entry[field]
			if v ~= nil then
				local clean = CHECK[field](el, v, false)
				if clean ~= nil then
					s[field] = clean
				else
					LogOnce(el.key .. "." .. field, format("ignored the saved %s of %s, which is not allowed; using the default", field, el.key))
				end
			end
		end
	end
	if el.opts.resizable then
		if el.aspect then
			s.width, s.height = AspectFit(el, s.width)
		end
	else
		s.width, s.height = FrameSize(el.frame)
	end
	return s
end

local function Place(el, anchor, x, y, w, h, f, pixel)
	local rw, rh = Layout.RootSize()
	local left, bottom = G.Rect(anchor, x, y, w, h, rw, rh)
	left, bottom = G.Align(left, pixel), G.Align(bottom, pixel)
	local _, ax, ay = G.Position(left, bottom, w, h, rw, rh, anchor)
	local frame = el.frame
	frame:ClearAllPoints()
	frame:SetPoint(anchor, Scale.Root(), anchor, ax / f, ay / f)
end

local restylePending = false
local scaledRoots = {}

local function RestyleWidgets()
	restylePending = false
	ns.Widgets.RestyleUnder(scaledRoots)
	for frame in pairs(scaledRoots) do
		scaledRoots[frame] = nil
	end
end

local function ApplyGeometry(el)
	local frame, s = el.frame, el.settings
	if el.opts.scalable then
		frame:SetScale(s.scale)
		if el.appliedScale ~= s.scale then
			scaledRoots[frame] = true
			if not restylePending then
				restylePending = true
				C_Timer.After(0, RestyleWidgets)
			end
		end
		el.appliedScale = s.scale
	end
	local f = Factor(frame)
	local pixel = Scale.Pixel(1)
	local w, h
	if el.opts.resizable then
		w, h = G.SnapSize(s.width, f, pixel), G.SnapSize(s.height, f, pixel)
		frame:SetSize(w, h)
	else
		w, h = FrameSize(frame)
	end
	Place(el, s.anchor, s.x, s.y, w * f, h * f, f, pixel)
	if el.strataSet or s.strata ~= el.default.strata then
		el.strataSet = true
		frame:SetFrameStrata(s.strata)
	end
end

local function LogDriver(el, driver)
	local now = "unknown"
	if type(SecureCmdOptionParse) == "function" then
		local ok, value = pcall(SecureCmdOptionParse, driver)
		now = ok and tostring(value) or "an error"
	end
	LogOnce(el.key .. ":driver:" .. driver, format("%s follows %s with the state driver %s, which reads %s now", el.key, el.settings.shown, driver, now))
end

local function ShowHidden(el)
	if el.hidden then
		el.hidden = false
		if ModuleRunning(el) then
			el.frame:Show()
		end
	end
end

local function ApplySecureVisibility(el)
	local frame = el.frame
	local driver = ModuleRunning(el) and Rules.Driver(el.settings.shown) or nil
	if driver == nil then
		ShowHidden(el)
	end
	el.hidden = false
	if driver == el.driver then
		return
	end
	if driver then
		if type(RegisterStateDriver) ~= "function" then
			LogOnce("noDriver", "RegisterStateDriver is missing; secure elements keep their own visibility")
			return
		end
		RegisterStateDriver(frame, "visibility", driver)
		el.driver = driver
		LogDriver(el, driver)
		return
	end
	if type(UnregisterStateDriver) == "function" then
		UnregisterStateDriver(frame, "visibility")
	end
	el.driver = nil
	local hidden = frame:GetAttribute("statehidden")
	if IsSecret(hidden) or hidden then
		frame:SetAttribute("statehidden", nil)
		if ModuleRunning(el) then
			frame:Show()
		end
	end
end

local function ApplyVisibility(el)
	if IsProtectedFrame(el.frame) then
		ApplySecureVisibility(el)
		return
	end
	if el.driver then
		if type(UnregisterStateDriver) == "function" then
			UnregisterStateDriver(el.frame, "visibility")
		end
		el.driver = nil
	end
	if Rules.Visible(el.settings.shown, state.combat, state.target) then
		ShowHidden(el)
		return
	end
	local shown = el.frame:IsShown()
	if IsSecret(shown) or shown then
		el.hidden = true
		el.frame:Hide()
	end
end

local function ApplyAlpha(el, instant, duration)
	local s = el.settings
	local alpha = Rules.Alpha(s.shown, state.combat, el.hovered, s.alphaCombat, s.alphaIdle)
	local calm = Layout.Calm
	if calm and s.shown ~= "mouseover" and s.alphaCombat == 1 and s.alphaIdle == 1 then
		alpha = alpha * calm.Level(el.key)
	end
	if alpha == 1 and not el.alphaSet then
		return
	end
	if not instant and duration == nil and el.alphaTarget == alpha and Motion.IsPlaying(el.alphaTween) then
		return
	end
	el.alphaSet = true
	local frame = el.frame
	local from = frame:GetAlpha()
	if not IsSecret(from) and type(from) ~= "number" then
		from = alpha
	end
	el.alphaTarget = alpha
	el.alphaTween = Motion.Tween(frame, "SetAlpha", from, alpha, instant and 0 or (duration or Tokens.Duration("fade")), Tokens.Easing("fade"))
end

local function Accessible(frame)
	local check = frame.CanBeAccessedInContext
	if type(check) ~= "function" then
		return true
	end
	local ok, allowed = pcall(check, frame)
	return ok and not IsSecret(allowed) and allowed ~= false
end

local function IsOver(frame)
	if not Accessible(frame) then
		return false
	end
	local ok, over = pcall(frame.IsMouseOver, frame)
	if not ok then
		return false
	end
	if IsSecret(over) then
		LogOnce("secretOver", "IsMouseOver read a secret, so an element on the mouseover rule stays shown while that lasts")
		return true
	end
	return over == true
end

local HookTree

local function SetHovered(el, hovered)
	if el.hovered == hovered then
		return
	end
	el.hovered = hovered
	ApplyAlpha(el)
	if hovered then
		HookTree(el, el.frame, 0)
	end
end

local function HoverEnter(frame)
	local el = hoverOwner[frame]
	if not el or el.settings.shown ~= "mouseover" then
		return
	end
	el.over[frame] = true
	SetHovered(el, true)
end

local function HoverLeave(frame)
	local el = hoverOwner[frame]
	if el and el.settings.shown == "mouseover" then
		el.over[frame] = nil
		C_Timer.After(0, el.checkHover)
	end
end

local function StillOver(el)
	for frame in pairs(el.over) do
		if IsOver(frame) then
			return true
		end
		el.over[frame] = nil
	end
	return IsOver(el.frame)
end

local function PollElement(el)
	if ModuleRunning(el) then
		SetHovered(el, StillOver(el))
	end
end

local function PollHover()
	for i = 1, #order do
		local el = elements[order[i]]
		if el.settings.shown == "mouseover" then
			ns.Call(PollElement, el)
		end
	end
end

local function UpdatePoll(needed)
	if needed and not state.poll then
		if type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
			LogOnce("noTicker", "C_Timer.NewTicker is missing, so the mouseover rule follows only the frames Layout can hook")
			return
		end
		state.poll = C_Timer.NewTicker(HOVER_POLL, PollHover)
		LogOnce("poll", format("polls the pointer every %.1f s while an element uses the mouseover rule, for content that keeps the mouse from Layout's hooks", HOVER_POLL))
	elseif not needed and state.poll then
		state.poll:Cancel()
		state.poll = nil
	end
end

local function HookFrame(frame)
	local ok, done = pcall(frame.HookScript, frame, "OnEnter", HoverEnter)
	if not ok or done == false then
		LogOnce("hookEnter", "a frame refused the mouseover hook (" .. tostring(done) .. "); the poll still finds the pointer over its element's rect")
		return false
	end
	ok, done = pcall(frame.HookScript, frame, "OnLeave", HoverLeave)
	if not ok or done == false then
		LogOnce("hookLeave", "a frame refused the mouseover leave hook (" .. tostring(done) .. "); the poll hides its element once the pointer leaves")
	end
	return true
end

local function Children(frame)
	return { frame:GetChildren() }
end

function HookTree(el, frame, depth)
	if IsSecret(frame) or type(frame) ~= "table" or not Accessible(frame) then
		return
	end
	if hoverOwner[frame] == nil then
		if not HookFrame(frame) then
			return
		end
		if IsOver(frame) then
			el.over[frame] = true
		end
	end
	hoverOwner[frame] = el
	if depth < HOOK_DEPTH then
		local ok, children = pcall(Children, frame)
		if ok then
			for _, child in ipairs(children) do
				HookTree(el, child, depth + 1)
			end
		end
	end
end

local function ApplyHover(el)
	local frame = el.frame
	if el.settings.shown == "mouseover" then
		HookTree(el, frame, 0)
		local mouse, motion = frame:IsMouseEnabled(), frame:IsMouseMotionEnabled()
		if not el.motionSet and not IsSecret(mouse) and not IsSecret(motion) and not mouse and not motion then
			el.motionSet = true
			frame:SetMouseMotionEnabled(true)
		end
		return
	end
	el.hovered = false
	if el.motionSet then
		el.motionSet = false
		frame:SetMouseMotionEnabled(false)
	end
end

local function Queue(el)
	if not el.queued then
		el.queued = true
		Combat.Queue(el.flush)
	end
end

local function LogPath(el)
	local rule = el.settings.shown
	if rule ~= "always" and rule ~= el.loggedRule and not IsProtectedFrame(el.frame) then
		el.loggedRule = rule
		Log(format("%s follows %s in Lua because it is not protected", el.key, rule))
	end
end

local function Apply(el, instant)
	if MayMove(el.frame) then
		ApplyGeometry(el)
		ApplyHover(el)
		ApplyVisibility(el)
		LogPath(el)
	else
		Queue(el)
	end
	ApplyAlpha(el, instant)
end

local function ResolveAll()
	for i = 1, #order do
		Resolve(elements[order[i]])
	end
end

local function ApplyAll(instant)
	for i = 1, #order do
		ns.Call(Apply, elements[order[i]], instant)
	end
end

local function RefreshDynamic()
	for i = 1, #order do
		local el = elements[order[i]]
		if not IsProtectedFrame(el.frame) then
			ApplyVisibility(el)
		end
		ApplyAlpha(el)
	end
end

local function OnTarget()
	state.target = TargetExists()
	RefreshDynamic()
end

local function OnCombatStart()
	state.combat = true
	if state.active then
		Layout.Exit(false)
		ns.Print(L["Layout Mode closed because combat started, and unsaved changes were undone."])
		Log("left Layout Mode for combat and restored the saved positions")
		state.combat = true
	end
	RefreshDynamic()
end

local function OnCombatEnd()
	state.combat = false
	RefreshDynamic()
end

local function UpdateEvents()
	local combat, target, hover = state.active, false, false
	for i = 1, #order do
		local s = elements[order[i]].settings
		combat = combat or Rules.NeedsCombat(s.shown, s.alphaCombat, s.alphaIdle)
		target = target or Rules.NeedsTarget(s.shown)
		hover = hover or s.shown == "mouseover"
	end
	UpdatePoll(hover)
	if combat ~= state.combatEvents then
		state.combatEvents = combat
		if combat then
			state.combat = InCombatLockdown() == true
			ns.Events.Register(SECTION, "PLAYER_REGEN_DISABLED", OnCombatStart)
			ns.Events.Register(SECTION, "PLAYER_REGEN_ENABLED", OnCombatEnd)
		else
			ns.Events.Unregister(SECTION, "PLAYER_REGEN_DISABLED")
			ns.Events.Unregister(SECTION, "PLAYER_REGEN_ENABLED")
		end
	end
	if target ~= state.targetEvents then
		state.targetEvents = target
		if target then
			state.target = TargetExists()
			ns.Events.Register(SECTION, "PLAYER_TARGET_CHANGED", OnTarget)
		else
			ns.Events.Unregister(SECTION, "PLAYER_TARGET_CHANGED")
		end
	end
end

local function Changed(el)
	Resolve(el)
	UpdateEvents()
	Apply(el)
	ns.Callbacks.Fire("LayoutChanged", el.key)
	if state.active then
		Mode("Changed", el.key)
	end
end

local function Record(changes, merge)
	if state.active then
		history:Push({ changes = changes, merge = merge })
		Mode("HistoryChanged")
	end
end

local function Write(el, patch, merge)
	local key = el.key
	local before = Copy(Entry(key))
	local entry = Copy(Entry(key)) or {}
	for field, value in pairs(patch) do
		if value == RESET or Same(value, el.default[field]) then
			entry[field] = nil
		else
			entry[field] = value
		end
	end
	SetEntry(key, entry)
	local after = Copy(Entry(key))
	if not Same(before, after) then
		Record({ [key] = { before = before, after = after } }, merge)
	end
	Changed(el)
end

local function WriteEntries(entries)
	local keys = {}
	for key in pairs(entries) do
		keys[#keys + 1] = key
	end
	for _, key in ipairs(keys) do
		SetEntry(key, Copy(entries[key] or nil))
		local el = elements[key]
		if el then
			Changed(el)
		end
	end
end

local ELEMENT_FIELDS = {
	shown = true, anchor = true, x = true, y = true, width = true, height = true, scale = true,
	alphaCombat = true, alphaIdle = true, strata = true,
}
Layout.ELEMENT_FIELDS = ELEMENT_FIELDS

local OPTION_CHECK = {
	label = function(v) return type(v) == "string" end,
	module = function(v) return type(v) == "string" end,
	resizable = function(v) return type(v) == "boolean" end,
	scalable = function(v) return type(v) == "boolean" end,
	plate = function(v) return type(v) == "boolean" end,
	window = function(v) return type(v) == "boolean" end,
	fields = function(v)
		if type(v) ~= "table" or #v == 0 then
			return false
		end
		for i = 1, #v do
			if not ELEMENT_FIELDS[v[i]] then
				return false
			end
		end
		return true
	end,
	aspect = function(v) return v == true or v == false or (IsFinite(v) and v > 0) end,
	minWidth = function(v) return IsFinite(v) and v > 0 end,
	minHeight = function(v) return IsFinite(v) and v > 0 end,
	maxWidth = function(v) return IsFinite(v) and v > 0 end,
	maxHeight = function(v) return IsFinite(v) and v > 0 end,
}

local function CheckRegister(frame, key, position, opts)
	if type(frame) ~= "table" or type(frame.SetPoint) ~= "function" then
		return "frame must be a frame, got " .. type(frame)
	end
	if type(key) ~= "string" or key == "" or #key > MAX_KEY then
		return "key must be text of 1 to 64 characters, got " .. tostring(key)
	end
	if type(position) ~= "table" or not G.IsAnchor(position.anchor) then
		return "defaultPosition.anchor must be one of the nine anchors"
	end
	for _, axis in ipairs({ "x", "y" }) do
		if position[axis] ~= nil and not IsFinite(position[axis]) then
			return "defaultPosition." .. axis .. " must be a number"
		end
	end
	if opts ~= nil and type(opts) ~= "table" then
		return "opts must be a table"
	end
	for field, value in pairs(opts or {}) do
		local check = OPTION_CHECK[field]
		if not check then
			return "unknown option " .. tostring(field)
		end
		if not check(value) then
			return "option " .. field .. " has a bad value " .. tostring(value)
		end
	end
end

local function OnShow(frame)
	local el = byFrame[frame]
	if not el then
		return
	end
	if el.settings.shown == "mouseover" then
		HookTree(el, frame, 0)
	end
	if IsProtectedFrame(frame) then
		return
	end
	if not Rules.Visible(el.settings.shown, state.combat, state.target) then
		el.hidden = true
		frame:Hide()
	end
end

local function Defaults(el, frame, position, opts)
	local limits = {
		minWidth = opts.minWidth or DEFAULT_MIN_SIZE,
		minHeight = opts.minHeight or DEFAULT_MIN_SIZE,
		maxWidth = opts.maxWidth or DEFAULT_MAX_SIZE,
		maxHeight = opts.maxHeight or DEFAULT_MAX_SIZE,
	}
	limits.maxWidth = max(limits.minWidth, limits.maxWidth)
	limits.maxHeight = max(limits.minHeight, limits.maxHeight)
	el.limits = limits
	local w, h = FrameSize(frame)
	if opts.resizable then
		w = Clamp(w > 0 and w or DEFAULT_SIZE, limits.minWidth, limits.maxWidth)
		h = Clamp(h > 0 and h or DEFAULT_SIZE, limits.minHeight, limits.maxHeight)
	end
	el.aspect = nil
	if opts.resizable and opts.aspect then
		el.aspect = opts.aspect == true and (h > 0 and w / h or 1) or opts.aspect
		w, h = AspectFit(el, w)
	end
	local scale = 1
	if opts.scalable then
		local own = frame:GetScale()
		scale = IsFinite(own) and Clamp(own, SCALE_MIN, SCALE_MAX) or 1
	end
	local strata = frame:GetFrameStrata()
	if IsSecret(strata) or type(strata) ~= "string" or strata == "" then
		strata = DEFAULT_STRATA
	end
	return {
		anchor = position.anchor, x = position.x or 0, y = position.y or 0,
		width = w, height = h, scale = scale,
		shown = "always", alphaCombat = 1, alphaIdle = 1, strata = strata,
	}
end

function Layout.Register(frame, key, defaultPosition, opts)
	local problem = CheckRegister(frame, key, defaultPosition, opts)
	if problem then
		error("KstyleUI.Layout.Register: " .. problem, 2)
	end
	opts = opts or {}
	local el = elements[key]
	if not el then
		el = { key = key, settings = {} }
		el.flush = function()
			el.queued = false
			Apply(el)
		end
		el.over = setmetatable({}, { __mode = "k" })
		el.checkHover = function()
			if el.hovered and not StillOver(el) then
				SetHovered(el, false)
			end
		end
		elements[key] = el
		order[#order + 1] = key
	elseif el.frame ~= frame then
		if el.driver and type(UnregisterStateDriver) == "function" and MayMove(el.frame) then
			UnregisterStateDriver(el.frame, "visibility")
		end
		el.driver, el.hidden, el.alphaSet, el.strataSet, el.motionSet, el.hovered = nil, false, false, false, false, false
		el.appliedScale = nil
		byFrame[el.frame] = nil
		Log(key .. " registered again with another frame")
	end
	el.frame = frame
	byFrame[frame] = el
	if not showHooked[frame] then
		showHooked[frame] = true
		frame:HookScript("OnShow", OnShow)
		local restyle = frame.Restyle
		if type(restyle) == "function" then
			frame.Restyle = function(self, ...)
				restyle(self, ...)
				local owner = byFrame[self]
				if owner and (owner.opts.resizable or owner.opts.scalable) and MayMove(self) then
					ApplyGeometry(owner)
				end
			end
		end
	end
	el.label = opts.label or key
	el.module = opts.module
	el.opts = Copy(opts)
	el.default = Defaults(el, frame, defaultPosition, opts)
	if el.appliedScale == nil then
		local own = frame:GetScale()
		el.appliedScale = IsFinite(own) and own or nil
	end
	Resolve(el)
	UpdateEvents()
	Apply(el, true)
	if Layout.Calm then
		Layout.Calm.Update()
	end
	if state.active then
		Mode("Added", key)
	end
end

function Layout.Elements()
	local out = {}
	for i, key in ipairs(order) do
		local el = elements[key]
		out[i] = { key = key, label = el.label, module = el.module, opts = Copy(el.opts), live = el.live ~= false and ModuleRunning(el) }
	end
	return out
end

function Layout.Get(key)
	local el = elements[key]
	if el then
		return Copy(el.settings)
	end
end

function Layout.Element(key)
	return elements[key]
end

function Layout.RefreshAlpha(key, duration)
	local el = elements[key]
	if not el then
		return false
	end
	ApplyAlpha(el, duration == 0, duration)
	return true
end

function Layout.Live(key)
	local el = elements[key]
	return el ~= nil and el.live ~= false and ModuleRunning(el)
end

function Layout.SetLive(key, live)
	local el = elements[key]
	if not el then
		return false
	end
	live = live ~= false
	if (el.live ~= false) == live then
		return true
	end
	el.live = live
	if state.active then
		Mode("Changed", key)
	end
	ns.Callbacks.Fire("LayoutChanged", key)
	return true
end

local function OnRootSize(el)
	local w, h = FrameSize(el.frame)
	local f = Factor(el.frame)
	return w * f, h * f
end

local function Patch(el, field, value)
	local patch = {}
	if value == nil then
		patch[field] = RESET
		if el.aspect and (field == "width" or field == "height") then
			patch.width, patch.height = RESET, RESET
		end
		return patch
	end
	local clean, why = CHECK[field](el, value, true)
	if clean == nil then
		return nil, format(L["%s must be %s."], field, why)
	end
	local s = el.settings
	if field == "anchor" then
		if clean ~= s.anchor then
			local w, h = OnRootSize(el)
			local rw, rh = Layout.RootSize()
			local left, bottom = G.Rect(s.anchor, s.x, s.y, w, h, rw, rh)
			local _, x, y = G.Position(left, bottom, w, h, rw, rh, clean)
			patch.x, patch.y = x, y
		end
		patch.anchor = clean
	elseif el.aspect and (field == "width" or field == "height") then
		patch.width, patch.height = AspectFit(el, field == "width" and clean or clean * el.aspect)
	else
		patch[field] = clean
	end
	return patch
end

local function Ready(key, field)
	local el = elements[key]
	if not el then
		return nil, format(L["%s is not a Layout element."], tostring(key))
	end
	if field ~= nil and not IS_FIELD[field] then
		return nil, format(L["%s is not a Layout setting."], tostring(field))
	end
	if not Store.IsLoaded() then
		return nil, L["KstyleUI has not loaded its saved settings yet."]
	end
	return el
end

function Layout.Set(key, field, value)
	local el, why = Ready(key, field)
	if not el then
		return false, why
	end
	local patch
	patch, why = Patch(el, field, value)
	if not patch then
		return false, why
	end
	Write(el, patch)
	return true
end

function Layout.Update(key, values, merge)
	local el, why = Ready(key)
	if not el then
		return false, why
	end
	local patch = {}
	for field, value in pairs(values) do
		if not IS_FIELD[field] then
			return false, format(L["%s is not a Layout setting."], tostring(field))
		end
		local clean
		clean, why = CHECK[field](el, value, true)
		if clean == nil then
			return false, format(L["%s must be %s."], field, why)
		end
		patch[field] = clean
	end
	if el.aspect and (patch.width or patch.height) then
		patch.width, patch.height = AspectFit(el, patch.width or patch.height * el.aspect)
	end
	Write(el, patch, merge)
	return true
end

function Layout.Rect(key)
	local el = elements[key]
	if not el then
		return nil
	end
	local w, h = OnRootSize(el)
	local rw, rh = Layout.RootSize()
	local pixel = Scale.Pixel(1)
	local s = el.settings
	local left, bottom = G.Rect(s.anchor, s.x, s.y, w, h, rw, rh)
	return G.Align(left, pixel), G.Align(bottom, pixel), w, h
end

function Layout.Preview(key, left, bottom, w, h, scale)
	local el = elements[key]
	local frame = el.frame
	if not MayMove(frame) then
		return
	end
	if scale and el.opts.scalable then
		frame:SetScale(scale)
	end
	local f = Factor(frame)
	if el.opts.resizable and w and h then
		frame:SetSize(w / f, h / f)
	end
	local rw, rh = Layout.RootSize()
	local anchor, x, y = G.Position(left, bottom, w, h, rw, rh, el.settings.anchor)
	frame:ClearAllPoints()
	frame:SetPoint(anchor, Scale.Root(), anchor, x / f, y / f)
end

function Layout.Restore(key)
	local el = elements[key]
	if el then
		ns.Call(Apply, el, true)
	end
end

function Layout.Reset(key)
	local el = Ready(key)
	if not el then
		return false
	end
	local before = Copy(Entry(key))
	if before == nil then
		return true
	end
	SetEntry(key, nil)
	Record({ [key] = { before = before } })
	Changed(el)
	return true
end

function Layout.ResetAll()
	if not Store.IsLoaded() then
		return false
	end
	local changes, any = {}, false
	for _, key in ipairs(order) do
		local before = Copy(Entry(key))
		if before ~= nil then
			changes[key] = { before = before }
			any = true
		end
	end
	if any then
		local entries = {}
		for key in pairs(changes) do
			entries[key] = false
		end
		WriteEntries(entries)
		Record(changes)
	end
	return true
end

local function Replay(entry, field)
	local entries = {}
	for key, change in pairs(entry.changes) do
		entries[key] = change[field] or false
	end
	WriteEntries(entries)
	Mode("HistoryChanged")
end

function Layout.Undo()
	local entry = history:Undo()
	if not entry then
		return false
	end
	Replay(entry, "before")
	return true
end

function Layout.Redo()
	local entry = history:Redo()
	if not entry then
		return false
	end
	Replay(entry, "after")
	return true
end

function Layout.CanUndo()
	return history:CanUndo()
end

function Layout.CanRedo()
	return history:CanRedo()
end

function Layout.IsActive()
	return state.active
end

function Layout.Enter()
	if state.active then
		return true
	end
	if InCombatLockdown() then
		ns.Print(L["Layout Mode opens after combat."])
		return false
	end
	if not Store.IsLoaded() then
		ns.Print(L["KstyleUI has not loaded its saved settings yet."])
		return false
	end
	state.active = true
	snapshot = Copy(Store.Layout())
	history:Clear()
	UpdateEvents()
	Mode("Show")
	Log(format("entered Layout Mode with %d elements", #order))
	return true
end

local function Close()
	state.active = false
	history:Clear()
	UpdateEvents()
	Mode("Hide")
end

function Layout.Exit(save)
	if not state.active then
		return
	end
	local restore = save == false and snapshot
	snapshot = nil
	Close()
	if restore then
		local entries = {}
		for key, entry in pairs(Store.Layout()) do
			if not Same(entry, restore[key]) then
				entries[key] = restore[key] or false
			end
		end
		for key, entry in pairs(restore) do
			if entries[key] == nil and not Same(entry, Store.Layout()[key]) then
				entries[key] = entry
			end
		end
		WriteEntries(entries)
	end
end

function Layout.Toggle()
	if state.active then
		Layout.Exit(true)
		return false
	end
	return Layout.Enter()
end

ns.Events.Register(SECTION, "ADDON_LOADED", function(_, name)
	if name == addonName and Store.IsLoaded() then
		ns.Events.Unregister(SECTION, "ADDON_LOADED")
		ResolveAll()
		UpdateEvents()
		ApplyAll(true)
	end
end)

ns.Events.Register(SECTION, "PLAYER_LOGIN", function()
	ns.Events.Unregister(SECTION, "PLAYER_LOGIN")
	state.combat = InCombatLockdown() == true
	state.target = TargetExists()
	ResolveAll()
	UpdateEvents()
	ApplyAll(true)
end)


ns.Callbacks.Register("ScaleChanged", SECTION, function()
	ApplyAll(true)
	if state.active then
		Mode("Refresh")
	end
end)

ns.Callbacks.Register("ProfileChanged", SECTION, function()
	if state.active then
		snapshot = nil
		Close()
	end
	ResolveAll()
	UpdateEvents()
	ApplyAll(true)
	for i = 1, #order do
		ns.Callbacks.Fire("LayoutChanged", order[i])
	end
end)

ns.Callbacks.Register("ModuleChanged", SECTION, function(_, name)
	for i = 1, #order do
		local el = elements[order[i]]
		if el.module == name then
			ns.Call(Apply, el)
			if state.active then
				Mode("Changed", el.key)
			end
		end
	end
end)

ns.Callbacks.Register("SettingChanged", SECTION, function(_, module)
	if module == SECTION and state.active then
		Mode("Refresh")
	end
end)

ns.DevTest.AddCheck("Layout", function()
	if type(RegisterStateDriver) ~= "function" or type(UnregisterStateDriver) ~= "function" then
		return false, format("%d elements; RegisterStateDriver is missing, so secure elements keep their own visibility", #order)
	end
	return true, format("%d elements registered; state drivers are available", #order)
end)
