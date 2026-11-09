-- group_env.lua: load the core and KstyleUI_GroupFrames into a stub environment with a party or raid
-- roster, secure group headers that place units as Blizzard's SecureGroupHeaders.lua does, and the
-- unit, curve and heal prediction APIs the module reads.
--
--   local G = dofile("Tools/regression/group_env.lua")
--   local env, K, ns = G.New()                -- core and module loaded, saved data loaded, logged in
--   G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR" }, ... })
--   K.Modules.Enable("GroupFrames")
--
-- Every addition here is test-only. stubs/wow.lua stays untouched; this file wraps the environment
-- it builds.

local CoreEnv = dofile("Tools/regression/core_env.lua")
local AurasEnv = dofile("Tools/regression/auras_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local G = {}
G.CoreEnv = CoreEnv

local FOLDER = "KstyleUI_GroupFrames"

local function moduleFiles()
	local out = {}
	for _, path in ipairs(TocFiles("%.lua$")) do
		if path:sub(1, #FOLDER + 1) == FOLDER .. "/" then
			out[#out + 1] = path
		end
	end
	return out
end
G.Files = moduleFiles

local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_COLORS = {
	WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
	ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 },
	WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 },
}
G.CLASS_COLORS = CLASS_COLORS

-- A color object as C_ClassColor and PowerBarColor return them.
local function color(r, g, b)
	return {
		r = r, g = g, b = b,
		GetRGB = function(self)
			return self.r, self.g, self.b
		end,
		GetRGBA = function(self)
			return self.r, self.g, self.b, 1
		end,
	}
end

-- The roster: env._roster.kind is "party", "raid" or nil (solo). env._roster.units maps a unit token
-- to its member: name, class, group, role, online, dead, ghost, health, maxHealth, power, maxPower,
-- powerType, level, leader, assistant, inRange, marker, ready, threat.
local function installRoster(env)
	env._roster = { kind = nil, units = {}, order = {} }
	local function member(unit)
		local r = env._roster
		if unit == "player" then
			return r.units.player or r.player
		end
		return r.units[unit]
	end
	env._member = member

	function env.IsInRaid()
		return env._roster.kind == "raid"
	end
	function env.IsInGroup()
		return env._roster.kind ~= nil
	end
	function env.GetNumGroupMembers()
		local r = env._roster
		if r.kind == "raid" then
			return #r.order
		elseif r.kind == "party" then
			return #r.order + 1
		end
		return 0
	end
	function env.GetNumSubgroupMembers()
		local r = env._roster
		return r.kind == "party" and #r.order or 0
	end
	function env.GetRaidRosterInfo(index)
		local unit = env._roster.order[index]
		local m = unit and env._roster.units[unit]
		if not m then
			return nil
		end
		return m.name, 0, m.group or 1, m.level or 60, m.class, m.class, "", m.online ~= false, m.dead == true, m.raidRole, false, m.role or "NONE"
	end
	function env.GetPartyAssignment()
		return false
	end
	function env.UnitExists(unit)
		if unit == "player" then
			return true
		end
		if unit == "target" then
			return env._target == true
		end
		return member(unit) ~= nil
	end
	function env.UnitName(unit)
		local m = member(unit)
		if m then
			return m.name, nil
		end
		if unit == "player" then
			return "Tester", nil
		end
	end
	function env.UnitClass(unit)
		local m = member(unit)
		local class = m and m.class or "HUNTER"
		return class, class, 1
	end
	function env.UnitGroupRolesAssigned(unit)
		local m = member(unit)
		return m and m.role or "NONE"
	end
	function env.UnitIsConnected(unit)
		local m = member(unit)
		return not m or m.online ~= false
	end
	function env.UnitIsDeadOrGhost(unit)
		local m = member(unit)
		return m ~= nil and (m.dead == true or m.ghost == true)
	end
	function env.UnitIsGhost(unit)
		local m = member(unit)
		return m ~= nil and m.ghost == true
	end
	function env.UnitIsUnit(a, b)
		if a == b then
			return true
		end
		local ma, mb = member(a), member(b)
		return ma ~= nil and ma == mb
	end
	function env.UnitLevel(unit)
		local m = member(unit)
		return m and m.level or 60
	end
	function env.UnitHealth(unit)
		local m = member(unit)
		return env.Secret(m and m.health or 100)
	end
	function env.UnitHealthMax(unit)
		local m = member(unit)
		return env.Secret(m and m.maxHealth or 100)
	end
	function env.UnitHealthMissing(unit)
		local m = member(unit)
		return env.Secret(m and ((m.maxHealth or 100) - (m.health or 100)) or 0)
	end
	function env.UnitHealthPercent(unit, _, curve)
		local m = member(unit)
		local pct = m and (m.health or 100) / (m.maxHealth or 100) or 1
		if curve and curve.Evaluate then
			return env.Secret(curve:Evaluate(pct))
		end
		return env.Secret(pct)
	end
	function env.UnitPower(unit)
		local m = member(unit)
		return env.Secret(m and m.power or 50)
	end
	function env.UnitPowerMax(unit)
		local m = member(unit)
		return env.Secret(m and m.maxPower or 100)
	end
	function env.UnitPowerType(unit)
		local m = member(unit)
		local token = m and m.powerType or "MANA"
		return 0, token, nil, nil, nil
	end
	function env.UnitInRange(unit)
		local m = member(unit)
		local inRange = not m or m.inRange ~= false
		return env.Secret(inRange), env.Secret(true)
	end
	function env.UnitReaction()
		return 5
	end
	function env.SetPortraitTexture(texture, unit)
		texture._portraitUnit = unit
	end
	function env.AbbreviateNumbers(value)
		if env.issecretvalue(value) then
			return env.Secret(tostring(env.Reveal(value)))
		end
		return tostring(value)
	end

	function env.UnitIsGroupLeader(unit)
		local m = member(unit)
		return env.Secret(m ~= nil and m.leader == true)
	end
	function env.UnitIsGroupAssistant(unit)
		local m = member(unit)
		return env.Secret(m ~= nil and m.assistant == true)
	end
	function env.GetRaidTargetIndex(unit)
		local m = member(unit)
		if m and m.marker then
			return env.Secret(m.marker)
		end
		return nil
	end
	function env.GetReadyCheckStatus(unit)
		local m = member(unit)
		return m and m.ready or nil
	end
	function env.UnitThreatSituation(unit)
		local m = member(unit)
		local threat = m and m.threat
		if m and m.secretThreat then
			return env.Secret(threat or 0)
		end
		return threat
	end
	env.THREAT_COLORS = { [0] = { 0.69, 0.69, 0.69 }, { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }
	function env.GetThreatStatusColor(status)
		local c = env.THREAT_COLORS[status]
		return c[1], c[2], c[3]
	end
	-- Blizzard_SharedXMLBase/TextureUtil.lua's MicroLFGRoleIcons, the atlases the game's helper returns.
	local roleIcons = { TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder", HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder", DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder" }
	function env.GetMicroIconForRole(role)
		return roleIcons[role] or roleIcons.DAMAGER
	end
	-- C_Texture.GetAtlasInfo answers for the atlases the client has (the names above, the leader crown and the
	-- ready-check marks) and nothing for any other name, as the game does; SetAtlas itself returns nothing.
	local atlases = { ["UI-HUD-UnitFrame-Player-Group-LeaderIcon"] = { width = 16, height = 16 }, ["UI-LFG-ReadyMark"] = { width = 32, height = 32 }, ["UI-LFG-DeclineMark"] = { width = 32, height = 32 }, ["UI-LFG-PendingMark"] = { width = 32, height = 32 } }
	for _, name in pairs(roleIcons) do
		atlases[name] = { width = 21, height = 21 }
	end
	env.C_Texture = env.C_Texture or {}
	function env.C_Texture.GetAtlasInfo(name)
		return atlases[name]
	end
	function env.UnitGetIncomingHeals(unit)
		local m = member(unit)
		return env.Secret(m and m.incoming or 0)
	end
	function env.UnitGetTotalAbsorbs(unit)
		local m = member(unit)
		return env.Secret(m and m.absorb or 0)
	end
	env.READY_CHECK_READY_TEXTURE = "UI-LFG-ReadyMark"
	env.READY_CHECK_NOT_READY_TEXTURE = "UI-LFG-DeclineMark"
	env.READY_CHECK_WAITING_TEXTURE = "UI-LFG-PendingMark"

	env.CLASS_SORT_ORDER = CLASS_ORDER
	env.RAID_CLASS_COLORS = {}
	for class, c in pairs(CLASS_COLORS) do
		env.RAID_CLASS_COLORS[class] = color(c[1], c[2], c[3])
	end
	env.C_ClassColor = {
		GetClassColor = function(class)
			if env.issecretvalue(class) then
				local c = CLASS_COLORS[env.Reveal(class)] or { 1, 1, 1 }
				return color(env.Secret(c[1]), env.Secret(c[2]), env.Secret(c[3]))
			end
			local c = CLASS_COLORS[class]
			return c and color(c[1], c[2], c[3]) or nil
		end,
	}
	env.PowerBarColor = {
		MANA = color(0, 0.55, 1),
		RAGE = color(1, 0, 0),
		ENERGY = color(1, 1, 0),
	}
	env.PLAYER_OFFLINE = "Offline"
	env.DEAD = "Dead"
	env.MAX_RAID_MEMBERS = 40
	env.MEMBERS_PER_RAID_GROUP = 5
end

-- The heal prediction calculator: UnitGetDetailedHealPrediction fills it from the member's incoming
-- heals and absorbs, and its getters return them as secrets. env._calculators counts the calculators.
local function installPrediction(env)
	env._calculators = 0
	env.Enum = env.Enum or {}
	env.Enum.UnitIncomingHealClampMode = { MissingHealth = 0, MaximumHealth = 1 }
	env.Enum.UnitDamageAbsorbClampMode = { MissingHealth = 0, MissingHealthWithoutIncomingHeals = 1, MaximumHealth = 2 }
	function env.CreateUnitHealPredictionCalculator()
		env._calculators = env._calculators + 1
		local calc = { heals = 0, absorbs = 0, modes = {} }
		function calc.SetIncomingHealClampMode(self, mode)
			self.modes.heal = mode
		end
		function calc.SetDamageAbsorbClampMode(self, mode)
			self.modes.absorb = mode
		end
		function calc.GetIncomingHeals(self)
			return env.Secret(self.heals), env.Secret(0), env.Secret(self.heals), env.Secret(false)
		end
		function calc.GetDamageAbsorbs(self)
			return env.Secret(self.absorbs), env.Secret(false)
		end
		return calc
	end
	function env.UnitGetDetailedHealPrediction(unit, _, calc)
		local m = env._member(unit)
		calc.unit = unit
		calc.heals = m and m.incoming or 0
		calc.absorbs = m and m.absorb or 0
	end
end

-- The AuraContainer engine: auras_env.lua's fake, plus the aura slots and the aura processing policy
-- the group frames use. A slot's frame is made as the engine makes it: initializeFrame runs before
-- the access restrictions apply.
local function installAuras(env, opts)
	AurasEnv.Engine(env, opts)
	env.CustomAuraContainerAuraProcessingPolicy = { None = 0, ProcessAura = 1 }
	env.AuraUtil = env.AuraUtil or {}
	env.AuraUtil.AuraUpdateChangedType = { None = 1, Debuff = 2, Buff = 3, Dispel = 4 }
	local create = env.CreateFrame
	env.CreateFrame = function(frameType, name, parent, template)
		local frame = create(frameType, name, parent, template)
		if frameType == "AuraContainer" and template == "CustomAuraContainerTemplate" then
			frame._slots = {}
			function frame.AddAuraSlot(self, key, filter, options)
				assert(type(key) == "string" and key ~= "", "slotKey must be a non-empty string.")
				assert(not self._slots[key], "aura slot '" .. key .. "' already exists with this key.")
				assert(type(filter) == "string" and filter:find("HARMFUL", 1, true), "invalid filter string " .. tostring(filter))
				options = options or {}
				-- The engine shows a slot's frame only while an aura fills it (CustomAuraButton's SetShown).
				local button = AurasEnv.MakeButton(env, self, options.initializeFrame)
				button:Hide()
				self._slots[key] = { key = key, filter = filter, frame = button, enabled = true, options = options }
				return button
			end
			function frame.SetAuraSlotFilterString(self, key, filter)
				assert(self._slots[key], "aura slot '" .. tostring(key) .. "' was not found with this key.")
				self._slots[key].filter = filter
			end
			function frame.SetAuraSlotEnabled(self, key, enabled)
				assert(type(enabled) == "boolean", "enabled must be a boolean.")
				assert(self._slots[key], "aura slot '" .. tostring(key) .. "' was not found with this key.")
				self._slots[key].enabled = enabled
			end
			local addGroup = frame.AddAuraGroup
			function frame.AddAuraGroup(self, key, filter, options)
				addGroup(self, key, filter, options)
				local group = self._groups[key]
				options = options or {}
				group.candidateFilters = options.candidateFilters
				group.layoutIndex = options.layout and options.layout.layoutIndex
			end
			function frame.SetAuraGroupCandidateFilters(self, key, filters)
				assert(self._groups[key], "aura group '" .. tostring(key) .. "' was not found with this key.")
				self._groups[key].candidateFilters = filters
			end
			function frame.SetAuraProcessingPolicy(self, policy, options)
				assert(policy == 0 or policy == 1, "policy must be a valid CustomAuraContainerAuraProcessingPolicy.")
				assert(policy == 1 or options == nil, "options must be nil for this aura processing policy.")
				self._policy, self._policyOptions = policy, options
			end
			function frame.GetAuraSlotFrame(self, key)
				local slot = self._slots[key]
				return slot and slot.frame
			end
		end
		return frame
	end
end

-- C_CurveUtil curves that evaluate in Lua, so a test can read what a secret holds with Reveal.
local function installCurves(env)
	local function newCurve()
		local curve = { points = {}, kind = "Linear" }
		function curve.SetType(self, kind)
			self.kind = kind
		end
		function curve.AddPoint(self, x, y)
			self.points[#self.points + 1] = { x, y }
			table.sort(self.points, function(a, b)
				return a[1] < b[1]
			end)
		end
		function curve.Evaluate(self, x)
			local pts = self.points
			if #pts == 0 then
				return 0
			end
			if x <= pts[1][1] then
				return pts[1][2]
			end
			for i = 2, #pts do
				local a, b = pts[i - 1], pts[i]
				if x < b[1] then
					if self.kind == env.Enum.LuaCurveType.Step then
						return a[2]
					end
					return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
				end
			end
			return pts[#pts][2]
		end
		return curve
	end
	env.C_CurveUtil = env.C_CurveUtil or {}
	env.C_CurveUtil.CreateCurve = newCurve
	env.Enum = env.Enum or {}
	env.Enum.LuaCurveType = env.Enum.LuaCurveType or { Linear = "Linear", Step = "Step" }
	env.Enum.StatusBarInterpolation = env.Enum.StatusBarInterpolation or { Immediate = 0, ExponentialEaseOut = 1 }
end

-- The secure group header: a frame whose Show, SetAttribute and GROUP_ROSTER_UPDATE place the
-- roster's units on child buttons, as SecureGroupHeader_Update and configureChildren do in Blizzard's
-- Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua. This port keeps what the module relies
-- on: showRaid, showParty, showPlayer and showSolo, groupFilter with numbers or classes, groupBy with
-- groupingOrder, sortMethod INDEX or NAME, unitsPerColumn, maxColumns, startingIndex, child creation
-- from the template with initialConfigFunction's size read from the header's attributes, and the
-- unit, child<n> and statehidden attributes.
local HEADER_TEMPLATES = {
	SecureGroupHeaderTemplate = true, SecurePartyHeaderTemplate = true, SecureRaidGroupHeaderTemplate = true,
}

local function split(text)
	local out = {}
	for part in tostring(text or ""):gmatch("[^,]+") do
		part = part:match("^%s*(.-)%s*$")
		out[#out + 1] = tonumber(part) or part
	end
	return out
end

local function headerUnits(env, header)
	local a = header._attributes
	local r = env._roster
	local list = {}
	local kind
	if r.kind == "raid" and a.showRaid then
		kind = "raid"
	elseif r.kind ~= nil and a.showParty then
		kind = "party"
	elseif a.showSolo then
		kind = "solo"
	end
	if not kind then
		return list
	end
	local entries = {}
	if kind == "raid" then
		for i, unit in ipairs(r.order) do
			local m = r.units[unit]
			entries[#entries + 1] = { unit = unit, index = i, m = m }
		end
	else
		if kind == "solo" or a.showPlayer then
			entries[#entries + 1] = { unit = "player", index = 0, m = r.units.player or r.player or { name = "Tester", class = "HUNTER" } }
		end
		if kind == "party" then
			for i, unit in ipairs(r.order) do
				entries[#entries + 1] = { unit = unit, index = i, m = r.units[unit] }
			end
		end
	end
	local filter = {}
	for i, token in ipairs(split(a.groupFilter or "1,2,3,4,5,6,7,8")) do
		filter[token] = i
	end
	local kept = {}
	for _, e in ipairs(entries) do
		local m = e.m or {}
		local group = kind == "raid" and (m.group or 1) or 1
		if filter[group] or filter[m.class or ""] then
			kept[#kept + 1] = e
		end
	end
	local order = {}
	if a.groupBy then
		for i, token in ipairs(split(a.groupingOrder)) do
			order[token] = i
		end
	end
	local function groupKey(e)
		local m = e.m or {}
		if a.groupBy == "GROUP" then
			return order[kind == "raid" and (m.group or 1) or 1]
		elseif a.groupBy == "CLASS" then
			return order[m.class or ""]
		elseif a.groupBy == "ASSIGNEDROLE" then
			return order[m.role or "NONE"]
		end
	end
	table.sort(kept, function(x, y)
		if a.groupBy then
			local gx, gy = groupKey(x) or 99, groupKey(y) or 99
			if gx ~= gy then
				return gx < gy
			end
		end
		if a.sortMethod == "NAME" then
			return tostring((x.m or {}).name) < tostring((y.m or {}).name)
		end
		return x.index < y.index
	end)
	for _, e in ipairs(kept) do
		list[#list + 1] = e.unit
	end
	return list
end

-- relativeAnchor(point) -> the relative point and offset signs getRelativePointAnchor gives in SecureGroupHeaders.lua.
local RELATIVE = {
	TOP = { "BOTTOM", 0, -1 }, BOTTOM = { "TOP", 0, 1 }, LEFT = { "RIGHT", 1, 0 }, RIGHT = { "LEFT", -1, 0 },
	TOPLEFT = { "BOTTOMRIGHT", 1, -1 }, TOPRIGHT = { "BOTTOMLEFT", -1, -1 }, BOTTOMLEFT = { "TOPRIGHT", 1, 1 }, BOTTOMRIGHT = { "TOPLEFT", -1, 1 },
}
local function relativeAnchor(point)
	local r = RELATIVE[point] or { "CENTER", 0, 0 }
	return r[1], r[2], r[3]
end

-- Anchors the shown children as configureChildren does in SecureGroupHeaders.lua: the first at the header's
-- point, each next one against the previous at the header's xOffset and yOffset, each new column against the
-- first of the previous column at columnAnchorPoint and columnSpacing; then sizes the header around them.
local function anchorChildren(env, header, numDisplayed, perColumn, columns)
	local a = header._attributes
	local point = a.point or "TOP"
	local relativePoint, xSign, ySign = relativeAnchor(point)
	local xMult, yMult = math.abs(xSign), math.abs(ySign)
	local xOffset, yOffset = a.xOffset or 0, a.yOffset or 0
	local columnPoint = a.columnAnchorPoint
	local columnSpacing = a.columnSpacing or 0
	local colRel, colX, colY = relativeAnchor(columnPoint)
	for i = 1, numDisplayed do
		local button = a["child" .. i]
		local buttonNum = (i - 1) % perColumn + 1
		local columnNum = math.floor((i - 1) / perColumn) + 1
		if buttonNum == 1 and columnNum == 1 then
			button:SetPoint(point, header, point, 0, 0)
		elseif buttonNum == 1 and columnPoint then
			button:SetPoint(columnPoint, a["child" .. (i - perColumn)], colRel, colX * columnSpacing, colY * columnSpacing)
		else
			button:SetPoint(point, a["child" .. (i - 1)], relativePoint, xMult * xOffset, yMult * yOffset)
		end
	end
	if numDisplayed > 0 then
		local first = a.child1
		local w, h = first:GetWidth(), first:GetHeight()
		local count = math.min(numDisplayed, perColumn)
		local width = w + (count - 1) * xMult * (w + xSign * xOffset) + (columns - 1) * math.abs(colX) * (w + columnSpacing)
		local height = h + (count - 1) * yMult * (h + ySign * yOffset) + (columns - 1) * math.abs(colY) * (h + columnSpacing)
		header:SetSize(math.max(0.1, width), math.max(0.1, height))
	end
end

local function configureChildren(env, header, units)
	local a = header._attributes
	local startingIndex = a.startingIndex or 1
	local count = #units
	local numDisplayed = count - (startingIndex - 1)
	local perColumn = a.unitsPerColumn
	local columns = 1
	if perColumn and numDisplayed > perColumn then
		columns = math.min(math.ceil(numDisplayed / perColumn), a.maxColumns or 1)
	else
		perColumn = numDisplayed
	end
	local first = startingIndex
	local last = math.min((startingIndex - 1) + perColumn * columns, count)
	numDisplayed = last - (first - 1)
	local need = math.max(1, numDisplayed)
	for i = 1, need do
		if not a["child" .. i] then
			local button = env.CreateFrame(a.templateType or "Button", nil, header, a.template)
			local config = a.initialConfigFunction
			if type(config) == "string" then
				button:SetWidth(a["kstyle-width"] or 0)
				button:SetHeight(a["kstyle-height"] or 0)
				button._configured = config
			end
			header._ignoreUpdate = true
			header:SetAttribute("child" .. i, button)
			header._ignoreUpdate = false
		end
	end
	local n = 0
	for i = first, last do
		n = n + 1
		local button = a["child" .. n]
		button:ClearAllPoints()
		button:SetAttribute("unit", units[i])
		if not button._attributes.statehidden then
			button:Show()
		end
	end
	n = n + 1
	while a["child" .. n] do
		local button = a["child" .. n]
		button:Hide()
		button:ClearAllPoints()
		button:SetAttribute("unit", nil)
		n = n + 1
	end
	header._displayed = math.max(0, numDisplayed)
	anchorChildren(env, header, header._displayed, perColumn, columns)
end

local function runScript(env, frame, script, ...)
	local handler = frame._scripts[script]
	if handler then
		local was = env._secure
		env._secure = false
		handler(frame, ...)
		env._secure = was
	end
end

local function updateHeader(env, header)
	if header._shown and not header._ignoreUpdate then
		local was = env._secure
		env._secure = true
		configureChildren(env, header, headerUnits(env, header))
		env._secure = was
	end
end

-- Methods the game refuses on a protected frame while in combat, unless secure code calls them.
local PROTECTED_METHODS = {
	"SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale", "Show", "Hide",
	"SetShown", "SetAttribute", "RegisterForClicks", "SetParent", "EnableMouse", "SetFrameStrata", "SetFrameLevel",
}

local function protect(env, frame, explicit)
	if explicit then
		frame._protected = true
	end
	if frame._guarded then
		return
	end
	frame._guarded = true
	local base = getmetatable(frame).__index
	for _, name in ipairs(PROTECTED_METHODS) do
		local original = rawget(frame, name) or base(frame, name)
		rawset(frame, name, function(self, ...)
			if env._combat and not env._secure then
				env._blocked[#env._blocked + 1] = name
				error("ADDON_ACTION_BLOCKED: " .. name .. " on a protected frame in combat", 2)
			end
			return original(self, ...)
		end)
	end
	rawset(frame, "IsProtected", function(self)
		return true, self._protected == true
	end)
end

-- A protected frame makes its parents protected too, up to UIParent.
local function protectAncestors(env, frame)
	local parent = frame._parent
	while parent and parent ~= env.UIParent do
		protect(env, parent, false)
		parent = parent._parent
	end
end

local function makeHeader(env, header)
	header._isHeader = true
	local base = getmetatable(header).__index
	local setAttribute, show = base(header, "SetAttribute"), base(header, "Show")
	rawset(header, "SetAttribute", function(self, key, value)
		setAttribute(self, key, value)
		runScript(env, self, "OnAttributeChanged", key, value)
		if key ~= "_ignore" and not tostring(key):match("^child%d+$") and not tostring(key):match("^frameref") then
			updateHeader(env, self)
		end
	end)
	rawset(header, "Show", function(self)
		local was = self._shown
		show(self)
		if not was then
			updateHeader(env, self)
			runScript(env, self, "OnShow")
		end
	end)
	header._shown = false
	env._headers[#env._headers + 1] = header
end

-- Children fire OnAttributeChanged on every SetAttribute and OnShow or OnHide when that changes, as
-- frames do in the game.
local function makeAttributeScripts(env, button)
	local base = getmetatable(button).__index
	local setAttribute, show, hide = base(button, "SetAttribute"), base(button, "Show"), base(button, "Hide")
	rawset(button, "SetAttribute", function(self, key, value)
		setAttribute(self, key, value)
		runScript(env, self, "OnAttributeChanged", key, value)
	end)
	rawset(button, "Show", function(self)
		local was = self._shown
		show(self)
		if not was then
			runScript(env, self, "OnShow")
		end
	end)
	rawset(button, "Hide", function(self)
		local was = self._shown
		hide(self)
		if was then
			runScript(env, self, "OnHide")
		end
	end)
end

local function installHeaders(env)
	env._headers = {}
	env._blocked = {}
	local create = env.CreateFrame
	env.CreateFrame = function(frameType, name, parent, template)
		local frame = create(frameType, name, parent, template)
		if template and HEADER_TEMPLATES[template] then
			makeHeader(env, frame)
			protect(env, frame, true)
			protectAncestors(env, frame)
		elseif template and tostring(template):find("SecureUnitButtonTemplate", 1, true) then
			makeAttributeScripts(env, frame)
			protect(env, frame, true)
			protectAncestors(env, frame)
		end
		return frame
	end
	env.UpdateHeaders = function()
		for _, header in ipairs(env._headers) do
			updateHeader(env, header)
		end
	end
end

-- Macro options for state drivers, with the group conditions the stub's parser lacks: [group:raid],
-- [group:party], [group] and [nogroup], next to combat, nocombat, exists and noexists with @unit.
local function installDrivers(env)
	local function holds(group)
		local unit, ok = "target", true
		for part in group:gmatch("[^,]+") do
			part = part:match("^%s*(.-)%s*$")
			local kind = env._roster.kind
			local named = part:match("^@(.+)$") or part:match("^target=(.+)$")
			if named then
				unit = named
			elseif part == "combat" then
				ok = ok and env._combat == true
			elseif part == "nocombat" then
				ok = ok and env._combat ~= true
			elseif part == "exists" then
				ok = ok and env.UnitExists(unit) == true
			elseif part == "noexists" then
				ok = ok and env.UnitExists(unit) ~= true
			elseif part == "group:raid" then
				ok = ok and kind == "raid"
			elseif part == "group:party" or part == "group" then
				ok = ok and kind ~= nil
			elseif part == "nogroup" then
				ok = ok and kind == nil
			else
				error("SecureCmdOptionParse stub: unknown condition " .. part)
			end
		end
		return ok
	end
	env.SecureCmdOptionParse = function(options)
		for clause in (options .. ";"):gmatch("([^;]*);") do
			local rest = clause:match("^%s*(.-)%s*$")
			local groups = {}
			while rest:sub(1, 1) == "[" do
				local group, after = rest:match("^%[([^%]]*)%]%s*(.*)$")
				assert(group, "SecureCmdOptionParse stub: unclosed [ in " .. options)
				groups[#groups + 1] = group
				rest = after
			end
			if #groups == 0 then
				return rest
			end
			for _, group in ipairs(groups) do
				if holds(group) then
					return rest
				end
			end
		end
		return nil
	end
end

-- Blizzard's group frames and the tooltip, as plain frames, so hiding and restoring them can be seen.
local function installBlizzard(env)
	env.PartyFrame = env.CreateFrame("Frame", "PartyFrame", env.UIParent)
	env.CompactRaidFrameContainer = env.CreateFrame("Frame", "CompactRaidFrameContainer", env.UIParent)
	env.CompactRaidFrameManager = env.CreateFrame("Frame", "CompactRaidFrameManager", env.UIParent)
	env.GameTooltip = env.CreateFrame("GameTooltip", "GameTooltip", env.UIParent)
	env.GameTooltip_SetDefaultAnchor = function(tooltip, owner)
		tooltip._owner = owner
	end
end

-- New(opts) -> env, KstyleUI, the module's private table. opts: the CoreEnv.New options, plus
--   boot   false to skip ADDON_LOADED and PLAYER_LOGIN.
function G.New(opts)
	opts = opts or {}
	local setup = opts.setup
	opts.setup = function(env)
		installRoster(env)
		installAuras(env, opts.engine)
		installCurves(env)
		installPrediction(env)
		installHeaders(env)
		installDrivers(env)
		installBlizzard(env)
		env.InCombatLockdown = function()
			return env._combat == true
		end
		if setup then
			setup(env)
		end
	end
	local env, K = CoreEnv.New(opts)
	Load(moduleFiles(), env)
	if opts.boot ~= false then
		CoreEnv.Boot(env)
	end
	return env, K, env._addons[FOLDER]
end

-- SetRoster(env, kind, members) sets a party ("party"), raid ("raid") or solo (nil) roster and fires
-- GROUP_ROSTER_UPDATE. Party members become party1.., raid members raid1... A raid member's group
-- defaults to its place in fives.
function G.SetRoster(env, kind, members, player)
	local r = env._roster
	r.kind, r.units, r.order = kind, {}, {}
	r.player = player or { name = "Tester", class = "HUNTER" }
	for i, m in ipairs(members or {}) do
		local unit = (kind == "raid" and "raid" or "party") .. i
		if kind == "raid" then
			m.group = m.group or math.floor((i - 1) / 5) + 1
		end
		r.units[unit] = m
		r.order[#r.order + 1] = unit
	end
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunStateDrivers()
	env.UpdateHeaders()
end

-- Members(n, fn) -> n members named Member1.. with classes in turn; fn(i, member) may change each.
function G.Members(n, fn)
	local out = {}
	for i = 1, n do
		local m = { name = "Member" .. i, class = CLASS_ORDER[(i - 1) % #CLASS_ORDER + 1], health = 80, maxHealth = 100 }
		if fn then
			fn(i, m)
		end
		out[i] = m
	end
	return out
end

-- Shown(header) -> the units of the header's shown children, in child order.
function G.Shown(header)
	local out = {}
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._shown and button._attributes.unit then
			out[#out + 1] = button._attributes.unit
		end
		i = i + 1
	end
	return out
end

G.Raises = CoreEnv.Raises

return G
