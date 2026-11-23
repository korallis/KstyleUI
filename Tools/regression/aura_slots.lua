-- aura_slots.lua: Blizzard's aura slots at the test boundary, for the class crowns and the crest's storm orbs. A CustomAuraContainerTemplate
-- container's AddAuraSlot button shows the first aura on the container's unit that passes the slot's filter string
-- and includeSpellIDs map (Blizzard_AuraContainerUtil.lua:89-111), and feeds the status bar SetApplicationBar gave it
-- as Blizzard_CustomAuraButton.lua:419-431 does: SetMinMaxValues(min, max(max, 1)), the secret count with the bar's
-- interpolation when the same aura changes and Immediate when one is assigned or cleared, and shown from min. The
-- button must own the bar (Blizzard_AuraContainerUtil.lua:311-333) and refuses addon calls while auras are secret
-- (DenyTaintedAccessWhenAurasAreSecret). A container feeds nothing until SetEnabled(true). A button plays the groups
-- AddAuraShownAnimation gave it when its aura appears and stops them when it goes, and restarts the groups
-- AddAuraAssignedAnimation gave it whenever a different aura is assigned (Blizzard_CustomAuraButton.lua:684-691).
--
--   local Slots = dofile("Tools/regression/aura_slots.lua")
--   Slots.Install(env)                                   -- in an env's setup, before the addon loads
--   Slots.Set(env, "target", { { id = 7386, count = 3, harmful = true } })   -- feeds every slot; nil clears
--
-- SetIcon, SetDurationCooldown, SetApplicationCount and SetDurationBar take regions the button owns and show the aura's icon, its stacks above one and its
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

function Slots.Feed(env, c)
	for _, slot in pairs(c._slots) do
		local aura
		if c._enabled == true and slot.enchant then
			aura = env._slotEnchants[slot.enchant]
		elseif c._enabled == true then
			for _, a in ipairs(env._slotAuras[c._unit] or {}) do
				if Matches(a, slot.filter, slot.candidates) then
					aura = aura and not slot.newest and aura or a
				end
			end
		end
		local update = aura ~= nil and aura == slot.aura
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
		if aura ~= slot.assigned then
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
	end
end

local function Restricted(env)
	if env.C_Secrets and env.C_Secrets.ShouldAurasBeSecret and env.C_Secrets.ShouldAurasBeSecret() then
		error("attempt to access a restricted aura button", 3)
	end
end

local function Button(env, c, button)
	-- AddAuraShownAnimation: the engine plays the group when the slot's aura appears and stops it when it goes
	-- (Blizzard_CustomAuraButton.lua:327-337, 694-705); its animations must target the button or a descendant.
	for _, kind in ipairs({ "Shown", "Assigned" }) do
		local list = {}
		button["_" .. kind:lower() .. "Animations"] = list
		button["AddAura" .. kind .. "Animation"] = function(_, group)
			Restricted(env)
			assert(Owns(button, group:GetParent()), "bad object in function call (must be the owner or a direct or indirect descendant of owner)")
			table.insert(list, group)
		end
		button["RemoveAura" .. kind .. "Animation"] = function(_, group)
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
	local create = env.CreateFrame
	function env.CreateFrame(frameType, name, parent, template)
		local c = create(frameType, name, parent, template)
		if frameType ~= "AuraContainer" then
			return c
		end
		c._slots = {}
		function c.SetUnit(self, unit) self._unit = unit end
		function c.SetEnabled(self, on)
			self._enabled = on
			Slots.Feed(env, self)
		end
		function c.UpdateAllAuras(self) Slots.Feed(env, self) end
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
			self._groups[key] = group
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

-- Set(env, unit, auras) gives the unit these auras (each { id, count, harmful, mine }) and feeds every slot, as a
-- UNIT_AURA would. Change a count on the same table for an update; a new table is a new aura.
function Slots.Set(env, unit, auras)
	env._slotAuras[unit] = auras
	for _, c in ipairs(env._slotContainers) do
		Slots.Feed(env, c)
	end
end

-- Enchant(env, slot, enchant) gives the weapon in slot (AuraContainerItemEnchantmentSlot) a temporary enchant
-- ({ start, duration }), or none with nil, and feeds every enchantment button.
function Slots.Enchant(env, slot, enchant)
	env._slotEnchants[slot] = enchant
	for _, c in ipairs(env._slotContainers) do
		Slots.Feed(env, c)
	end
end

return Slots
