-- aura_slots.lua: Blizzard's aura slots at the test boundary, for the class crowns and the crest's storm orbs. A CustomAuraContainerTemplate
-- container's AddAuraSlot button shows the first aura on the container's unit that passes the slot's filter string
-- and includeSpellIDs map (Blizzard_AuraContainerUtil.lua:89-111), and feeds the status bar SetApplicationBar gave it
-- as Blizzard_CustomAuraButton.lua:419-431 does: SetMinMaxValues(min, max(max, 1)), the secret count with the bar's
-- interpolation when the same aura changes and Immediate when one is assigned or cleared, and shown from min. The
-- button must own the bar (Blizzard_AuraContainerUtil.lua:311-333). While auras are secret the button and every
-- region made under it refuse addon calls with the client's forbidden-object error (DenyTaintedAccessWhenAurasAreSecret,
-- Blizzard_AuraContainerShared.lua:108, applied by Blizzard_AuraContainerFrameProviders.lua:84); Slots.Engine still
-- reaches them. A container feeds nothing until SetEnabled(true). A button plays the groups
-- AddAuraShownAnimation gave it when its aura appears and stops them when it goes, and restarts the groups
-- AddAuraAssignedAnimation gave it whenever a different aura is assigned (Blizzard_CustomAuraButton.lua:684-691), and
-- plays the groups AddPandemicActiveAnimation gave it while its aura is in the engine's pandemic window (an aura with
-- pandemic = true; the engine reads GetRefreshCarryOverDuration, Blizzard_AuraContainerUtil.lua:13-28) and stops them
-- when it leaves (Blizzard_CustomAuraButton.lua:744-786).
--
--   local Slots = dofile("Tools/regression/aura_slots.lua")
--   Slots.Install(env)                                   -- in an env's setup, before the addon loads
--   Slots.Set(env, "target", { { id = 7386, count = 3, harmful = true } })   -- feeds every slot; nil clears
--   Slots.Readings(env)                                  -- C_UnitAuras.GetUnitAuraBySpellID answers from the slots' auras
--   Slots.Deliver(env, "party2", { { id = 10060, start = env._now, duration = 30 } })   -- Set, then UNIT_AURA as the client fires it
--
-- SetAuraSlotEnabled(key, false) stops a slot reading auras. SetIcon, SetDurationCooldown, SetApplicationCount and SetDurationBar take regions the button owns and show the aura's icon, its stacks above one and its
-- { start, finish } duration (an aura's start and duration, seconds); AddItemEnchantment's button shows the enchant
-- Slots.Enchant gives its slot, as Blizzard_CustomAuraContainer.lua:488-507 does. A slot or group sorted by
-- AuraInstanceIDOnly, Reverse takes the newest matching aura first (the last in the unit's list); AddAuraGroup makes
-- maxFrameCount buttons up front through initializeFrame, shows one per match in a left-to-right row of its layout's
-- elementWidth and elementSpacing from the container's top left, and sizes the container to the row
-- (Blizzard_CustomAuraContainer.lua:286-328). Groups exist only when env._slotGroups is set before the addon loads,
-- so modules that fall back without them (the unit frames' auras) keep their fallback.
--
-- A bar fed with ExponentialEaseOut on an update keeps bar._ease = { from, to, at = env._now } so the render
-- harness can draw the sweep (Tools/render/scene.lua, BarFraction).
--
-- With env._slotSight set, the fake keeps the client's order around a container going out of view. The client's
-- container listens for aura changes only while it is visible (Blizzard_AuraContainer.lua:71-79, 157-158), so
-- Slots.Set and Slots.Enchant skip a container out of view. Showing again marks it for a full rebuild that runs as it
-- next updates (Blizzard_ManagedAuraContainer.lua:26, 63-65, 98-106): it clears the aura of every slot that has one and
-- then assigns the aura each slot's filter matches now (Blizzard_ManagedAuraContainer.lua:75-78, 224-236, 591-596;
-- Blizzard_AuraContainerSlots.lua:177-222; Blizzard_AuraButton.lua:133-153). Slots.Rebuild(env) runs that update.
local Slots = {}

local function Matches(aura, filter, candidates)
	for part in filter:gmatch("[^|]+") do
		if part == "HARMFUL" and not aura.harmful or part == "HELPFUL" and aura.harmful or part == "PLAYER" and aura.mine == false then
			return false
		end
	end
	local ids = candidates and candidates.includeSpellIDs
	return not ids or ids[aura.id] == true
end

local function Owns(button, bar)
	local node = bar
	while node do
		if node == button then
			return true
		end
		node = node:GetParent()
	end
	return false
end

-- Same(env, a, b): under a clip (env._clip) a story that sets its auras again keeps each one's instance, as the engine
-- keeps an aura's auraInstanceID: the same spell from the same start is the same aura.
local function Same(env, a, b)
	return a == b or env._clip == true and a ~= nil and b ~= nil and a.id == b.id and a.start == b.start
end

local function Feed(env, c)
	for _, slot in pairs(c._slots) do
		local aura
		if c._enabled == true and slot.enchant then
			aura = env._slotEnchants[slot.enchant]
		elseif c._enabled == true and not slot.disabled then
			for _, a in ipairs(env._slotAuras[c._unit] or {}) do
				if Matches(a, slot.filter, slot.candidates) then
					aura = aura and not slot.newest and aura or a
				end
			end
		end
		local update = aura ~= nil and Same(env, aura, slot.aura)
		slot.aura = aura
		local bound = slot.frame._applicationBar
		if bound then
			local bar, o = bound[1], bound[2]
			local count = aura and aura.count or 0
			local ease = update and o.interpolation == 1
			bar._ease = ease and { from = bar._count or 0, to = count, at = env._now } or nil
			bar._count = count
			bar:SetMinMaxValues(o.minApplications, math.max(o.maxApplications, 1))
			bar:SetValue(env.Secret(count), update and o.interpolation or 0)
			bar:SetShown(count >= o.minApplications)
		end
		Slots.Show(env, c, slot, aura)
	end
	for _, group in pairs(c._groups or {}) do
		local matches = {}
		for _, a in ipairs(c._enabled == true and env._slotAuras[c._unit] or {}) do
			if Matches(a, group.filter, group.candidates) then table.insert(matches, 1, a) end
		end
		local o = group.layout or {}
		local w, gap, shown = o.elementWidth or 30, o.elementSpacing or 0, 0
		for i, frame in ipairs(group.frames) do
			Slots.Show(env, c, group.slots[i], matches[i])
			if matches[i] then
				frame:ClearAllPoints()
				frame:SetSize(w, o.elementHeight or w)
				frame:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * (w + gap), 0)
				shown = i
			end
		end
		c:SetSize(math.max(1, shown * w + math.max(0, shown - 1) * gap), o.elementHeight or w)
	end
end

-- Engine(env, fn, ...) runs fn as the engine, past the access restriction, and returns its first value: the engine's
-- own updates, and a test reading what the screen shows.
function Slots.Engine(env, fn, ...)
	local was = env._engine
	env._engine = true
	local ok, value = pcall(fn, ...)
	env._engine = was
	if not ok then
		error(value, 0)
	end
	return value
end

function Slots.Feed(env, c)
	Slots.Engine(env, Feed, env, c)
end

function Slots.Show(env, c, slot, aura)
	do
		local b = slot.frame
		local timed = aura and aura.duration and { start = aura.start or env._now or 0, finish = (aura.start or env._now or 0) + aura.duration }
		if b._icon and aura then
			b._icon:SetTexture(aura.icon)
		end
		if b._countText then
			b._countText:SetText(aura and (aura.count or 0) > 1 and tostring(aura.count) or "")
		end
		if b._cooldown then
			if timed then b._cooldown:SetCooldownFromDurationObject(timed) else b._cooldown:Clear() end
		end
		if b._durationBar then
			b._durationBar[1]:SetTimerDuration(timed or { start = 0, finish = 0 }, 0, b._durationBar[2].direction)
		end
		if not Same(env, aura, slot.assigned) then
			slot.assigned = aura
			for _, group in ipairs(b._assignedAnimations or {}) do
				group:Stop()
				if aura then
					group:Play()
				end
			end
		end
		local was = slot.frame:IsShown()
		slot.frame:SetShown(aura ~= nil)
		for _, group in ipairs(slot.frame._shownAnimations or {}) do
			if aura and not was then
				group:Play()
			elseif not aura then
				group:Stop()
			end
		end
		for _, group in ipairs(b._pandemicAnimations or {}) do
			if not (aura and aura.pandemic) then
				group:Stop()
			elseif not group:IsPlaying() then
				group:Play()
			end
		end
	end
end

local function Restricted(env)
	if env.C_Secrets and env.C_Secrets.ShouldAurasBeSecret and env.C_Secrets.ShouldAurasBeSecret() then
		error("attempt to access a restricted aura button", 3)
	end
end

-- A slot button has the Shown secret aspect before AddAuraSlot returns: the frame provider runs UpdateAuraDisplay at
-- creation (Blizzard_AuraContainerFrameProviders.lua:88-90) and ApplyVisibility calls SetShown(secretwrap(...))
-- (Blizzard_CustomAuraButton.lua:698), which adds that aspect (SimpleScriptRegionAPIDocumentation.lua:725-728). The client
-- then refuses OnShow and OnHide handlers on it, as it did on Forever 1.60.1 (71139), because they would reveal its
-- secret visibility.
local function Aspected(button)
	button._shownAspect = true
	for _, method in ipairs({ "SetScript", "HookScript" }) do
		local assign = button[method]
		button[method] = function(self, script, fn)
			local name = type(script) == "string" and script:lower()
			if name == "onshow" or name == "onhide" then
				error("Button:" .. method .. "(): Cannot assign script handler for '" .. name .. "' (blocked by secret aspects)", 2)
			end
			return assign(self, script, fn)
		end
	end
end

local function Button(env, c, button)
	Aspected(button)
	button._denied = env._auraDenied
	-- AddAuraShownAnimation: the engine plays the group when the slot's aura appears and stops it when it goes
	-- (Blizzard_CustomAuraButton.lua:327-337, 694-705); its animations must target the button or a descendant.
	for kind, field in pairs({ AuraShown = "_shownAnimations", AuraAssigned = "_assignedAnimations", PandemicActive = "_pandemicAnimations" }) do
		local list = {}
		button[field] = list
		button["Add" .. kind .. "Animation"] = function(_, group)
			Restricted(env)
			assert(Owns(button, group:GetParent()), "bad object in function call (must be the owner or a direct or indirect descendant of owner)")
			table.insert(list, group)
		end
		button["Remove" .. kind .. "Animation"] = function(_, group)
			Restricted(env)
			for i, added in ipairs(list) do
				if added == group then
					table.remove(list, i)
					return
				end
			end
		end
	end
	for method, field in pairs({ SetIcon = "_icon", SetDurationCooldown = "_cooldown", SetApplicationCount = "_countText" }) do
		button[method] = function(_, region)
			Restricted(env)
			assert(Owns(button, region), "bad object in function call (must be the owner or a direct or indirect descendant of owner)")
			button[field] = region
			Slots.Feed(env, c)
		end
	end
	function button.SetDurationBar(_, bar, options)
		Restricted(env)
		assert(Owns(button, bar), "bad object in function call (must be the owner or a direct or indirect descendant of owner)")
		button._durationBar = { bar, options or {} }
		Slots.Feed(env, c)
	end
	function button.SetApplicationBar(_, bar, options)
		Restricted(env)
		assert(Owns(button, bar), "bad object in function call (must be the owner or a direct or indirect descendant of owner)")
		assert(type(options.maxApplications) == "number", "maxApplications must be a number")
		button._applicationBar = { bar, options }
		Slots.Feed(env, c)
	end
	return button
end

function Slots.Install(env)
	env._slotAuras, env._slotContainers, env._slotEnchants = env._slotAuras or {}, {}, env._slotEnchants or {}
	env.AuraContainerItemEnchantmentSlot = env.AuraContainerItemEnchantmentSlot or { MainHand = 1, OffHand = 2, Ranged = 3 }
	env.Enum = env.Enum or {}
	env.Enum.StatusBarInterpolation = env.Enum.StatusBarInterpolation or { Immediate = 0, ExponentialEaseOut = 1 }
	function env._auraDenied()
		local secrets = not env._engine and env.C_Secrets
		return secrets and secrets.ShouldAurasBeSecret and secrets.ShouldAurasBeSecret()
	end
	local create = env.CreateFrame
	function env.CreateFrame(frameType, name, parent, template)
		local c = create(frameType, name, parent, template)
		if frameType ~= "AuraContainer" then
			return c
		end
		c._slots = {}
		c:SetScript("OnShow", function(self)
			self._rebuild = env._slotSight or nil
		end)
		function c.SetUnit(self, unit) self._unit = unit end
		function c.SetEnabled(self, on)
			self._enabled = on
			Slots.Feed(env, self)
		end
		function c.UpdateAllAuras(self) Slots.Feed(env, self) end
		function c.SetAuraSlotEnabled(self, key, on)
			self._slots[key].disabled = not on
			Slots.Feed(env, self)
		end
		-- A container with an aura group forbids untrusted layout scripts, so no container without one may anchor to it
		-- (Blizzard_CustomAuraContainer.lua:317-324).
		local point = c.SetPoint
		function c.SetPoint(self, at, other, ...)
			assert(not (type(other) == "table" and other._forbidLayout and not self._forbidLayout), "anchor target forbids untrusted layout scripts")
			return point(self, at, other, ...)
		end
		function c.AddAuraSlot(self, key, filter, options)
			assert(type(key) == "string" and key ~= "" and not self._slots[key], "aura slot keys are unique non-empty strings")
			local button = Button(env, self, create("Frame", nil, self))
			button:Hide()
			local sort, direction = env.AuraContainerSortMethod, env.AuraContainerSortDirection
			self._slots[key] = { filter = filter, frame = button, candidates = options and options.candidateFilters,
				newest = options and sort and options.sortMethod == sort.AuraInstanceIDOnly and options.sortDirection == direction.Reverse }
			Slots.Feed(env, self)
			return button
		end
		c.AddAuraGroup = env._slotGroups and function(self, key, filter, options)
			self._groups = self._groups or {}
			assert(not self._groups[key], "aura group keys are unique")
			local group = { filter = filter, candidates = options.candidateFilters, layout = options.layout, frames = {}, slots = {} }
			for i = 1, math.min(options.maxFrameCount or 8, 8) do
				local button = Button(env, self, create("Frame", nil, self))
				button:Hide()
				if options.initializeFrame then options.initializeFrame(button) end
				group.frames[i], group.slots[i] = button, { frame = button }
			end
			self._groups[key], self._forbidLayout = group, true
			Slots.Feed(env, self)
		end or nil
		function c.AddItemEnchantment(self, slot)
			local key = "enchant" .. tostring(slot)
			assert(not self._slots[key], "item enchantment already exists with this slot.")
			local button = Button(env, self, create("Frame", nil, self))
			button:Hide()
			self._slots[key] = { enchant = slot, frame = button }
			Slots.Feed(env, self)
			return button
		end
		env._slotContainers[#env._slotContainers + 1] = c
		return c
	end
end

local function Hears(env, c)
	return not env._slotSight or c:IsVisible()
end

-- Set(env, unit, auras) gives the unit these auras (each { id, count, harmful, mine }) and feeds every slot, as a
-- UNIT_AURA would. Change a count on the same table for an update; a new table is a new aura.
function Slots.Set(env, unit, auras)
	env._slotAuras[unit] = auras
	for _, c in ipairs(env._slotContainers) do
		if Hears(env, c) then
			Slots.Feed(env, c)
		end
	end
end

-- Enchant(env, slot, enchant) gives the weapon in slot (AuraContainerItemEnchantmentSlot) a temporary enchant
-- ({ start, duration }), or none with nil, and feeds every enchantment button.
function Slots.Enchant(env, slot, enchant)
	env._slotEnchants[slot] = enchant
	for _, c in ipairs(env._slotContainers) do
		if Hears(env, c) then
			Slots.Feed(env, c)
		end
	end
end

local function Rebuild(env, c)
	for _, slot in pairs(c._slots) do
		if slot.assigned ~= nil then
			slot.aura = nil
			Slots.Show(env, c, slot, nil)
		end
	end
	for _, group in pairs(c._groups or {}) do
		for _, slot in ipairs(group.slots) do
			if slot.assigned ~= nil then
				Slots.Show(env, c, slot, nil)
			end
		end
	end
	Feed(env, c)
end

-- Rebuild(env) is the next update of every container that showed again while env._slotSight was set.
function Slots.Rebuild(env)
	for _, c in ipairs(env._slotContainers) do
		if c._rebuild and c:IsVisible() then
			c._rebuild = nil
			Slots.Engine(env, Rebuild, env, c)
		end
	end
end

-- Readings(env) answers C_UnitAuras.GetUnitAuraBySpellID from the helpful auras Set gave each unit, as the client reads them out of combat:
-- one instance id per aura table, the priest's own unless the aura says mine = false, and no expiration time for an aura with no duration.
function Slots.Readings(env)
	local ids, serial = setmetatable({}, { __mode = "k" }), 0
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
		for _, a in ipairs(env._slotAuras[unit] or {}) do
			if a.id == id and not a.harmful then
				if not ids[a] then serial = serial + 1 ids[a] = serial end
				local length = a.duration or 0
				return { auraInstanceID = ids[a], spellId = id, sourceUnit = a.mine == false and "party9" or "player", expirationTime = length > 0 and (a.start or 0) + length or 0, duration = length }
			end
		end
	end
end

-- Deliver(env, unit, auras) sets the unit's auras and fires the UNIT_AURA the client sends for that unit alone: the auras it gained and
-- the ones it lost (by Readings' instance ids), or a full update when the list is cleared.
function Slots.Deliver(env, unit, auras)
	local kept, removed = {}, {}
	for _, a in ipairs(auras or {}) do kept[a] = true end
	for _, a in ipairs(env._slotAuras[unit] or {}) do
		local read = not kept[a] and not a.harmful and env.C_UnitAuras.GetUnitAuraBySpellID(unit, a.id)
		if read then removed[#removed + 1] = read.auraInstanceID end
		kept[a] = nil
	end
	local fresh = {}
	for _, a in ipairs(auras or {}) do
		if kept[a] then fresh[#fresh + 1] = a end
	end
	Slots.Set(env, unit, auras)
	if not auras then
		env.FireEvent("UNIT_AURA", unit, { isFullUpdate = true })
		return
	end
	local added = {}
	for _, a in ipairs(fresh) do
		local read = not a.harmful and env.C_UnitAuras.GetUnitAuraBySpellID(unit, a.id)
		if read then added[#added + 1] = { spellId = a.id, auraInstanceID = read.auraInstanceID } end
	end
	env.FireEvent("UNIT_AURA", unit, { isFullUpdate = false, addedAuras = added, removedAuraInstanceIDs = removed })
end

return Slots
