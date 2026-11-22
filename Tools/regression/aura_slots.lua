-- aura_slots.lua: Blizzard's aura slots at the test boundary, for the class crowns. A CustomAuraContainerTemplate
-- container's AddAuraSlot button shows the first aura on the container's unit that passes the slot's filter string
-- and includeSpellIDs map (Blizzard_AuraContainerUtil.lua:89-111), and feeds the status bar SetApplicationBar gave it
-- as Blizzard_CustomAuraButton.lua:419-431 does: SetMinMaxValues(min, max(max, 1)), the secret count with the bar's
-- interpolation when the same aura changes and Immediate when one is assigned or cleared, and shown from min. The
-- button must own the bar (Blizzard_AuraContainerUtil.lua:311-333) and refuses addon calls while auras are secret
-- (DenyTaintedAccessWhenAurasAreSecret). A container feeds nothing until SetEnabled(true).
--
--   local Slots = dofile("Tools/regression/aura_slots.lua")
--   Slots.Install(env)                                   -- in an env's setup, before the addon loads
--   Slots.Set(env, "target", { { id = 7386, count = 3, harmful = true } })   -- feeds every slot; nil clears
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
		if c._enabled == true then
			for _, a in ipairs(env._slotAuras[c._unit] or {}) do
				if Matches(a, slot.filter, slot.candidates) then
					aura = a
					break
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
		slot.frame:SetShown(aura ~= nil)
	end
end

local function Button(env, c, button)
	function button.SetApplicationBar(_, bar, options)
		if env.C_Secrets and env.C_Secrets.ShouldAurasBeSecret and env.C_Secrets.ShouldAurasBeSecret() then
			error("attempt to access a restricted aura button")
		end
		assert(Owns(button, bar), "bad object in function call (must be the owner or a direct or indirect descendant of owner)")
		assert(type(options.maxApplications) == "number", "maxApplications must be a number")
		button._applicationBar = { bar, options }
		Slots.Feed(env, c)
	end
	return button
end

function Slots.Install(env)
	env._slotAuras, env._slotContainers = env._slotAuras or {}, {}
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
			self._slots[key] = { filter = filter, frame = button, candidates = options and options.candidateFilters }
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

return Slots
