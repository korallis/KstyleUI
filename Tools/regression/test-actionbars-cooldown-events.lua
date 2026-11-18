-- test-actionbars-cooldown-events.lua: cooldown event orders keep the old sweep, recharge, GCD and ready-flash state; already clear widgets stay clear without engine calls.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W
local SPELL, ACTION = "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN"

local function fixture()
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local info = { isOnGCD = false }
	env.C_ActionBar.GetActionCooldown = function() return info end
	AB.Slot(env, 1, {
		texture = 135001, type = "spell", id = 101, cooldown = { name = "initial" },
		charges = { maxCharges = 2, currentCharges = 1, isActive = true }, chargeDuration = { name = "initial charge" },
	})
	local button = AB.Button(ns, "bar1", 1)
	local state = { flashes = 0 }
	button.FlashReady = function() state.flashes = state.flashes + 1 end
	-- Model the engine writes, including OnShow/OnHide, without consulting the regions for addon decisions.
	local function observe(region, key)
		region.SetCooldownFromDurationObject = function(self, duration)
			state[key] = duration.name
			local onShow = self:GetScript("OnShow")
			if onShow then onShow(self) end
		end
		region.Clear = function(self)
			state[key] = nil
			local onHide = self:GetScript("OnHide")
			if onHide then onHide(self) end
		end
	end
	observe(button.cooldown, "sweep")
	observe(button.chargeCooldown, "charge")
	env.SetCombat(true)
	return env, ns, button, info, state
end

-- Today's handlers, before this fix: action events preserve GCD classification; only spell events trust it.
local function previous(env, ns, event)
	for _, button in ipairs(ns.actionButtons) do
		button.cooldownCleared, button.chargeCooldownCleared = nil, nil
		ns.Button.UpdateCooldown(button, event == SPELL)
	end
	if event == SPELL then
		for _, button in ipairs(ns.petButtons) do ns.Button.Update(button, true) end
		for _, button in ipairs(ns.stanceButtons) do ns.Button.Update(button, true) end
		ns.Flyout.UpdateCooldown()
	end
end

for _, order in ipairs({ { SPELL, ACTION }, { ACTION, SPELL }, { SPELL }, { ACTION } }) do
	local env, _, button, info, state = fixture()
	local old, oldNS, oldButton, oldInfo, oldState = fixture()
	-- Keep the previous unguarded clears as the oracle, including the real-cooldown paint transition.
	oldButton.ClearCooldown = function(self)
		self.cooldown:Clear()
		if self.realCooldown ~= false then self.realCooldown = false; self:Paint() end
	end
	oldButton.ClearChargeCooldown = function(self) self.chargeCooldown:Clear() end
	local function same()
		for _, key in ipairs({ "sweep", "charge", "flashes" }) do
			assert(state[key] == oldState[key], key .. " differs from the previous handlers")
		end
		for _, key in ipairs({ "gcd", "realCooldown", "cooling" }) do
			assert(button[key] == oldButton[key], key .. " differs from the previous handlers")
		end
		assert(button.icon:GetVertexColor() == oldButton.icon:GetVertexColor(), "cooldown shading is unchanged")
	end
	for frame = 1, 3 do
		env._now, old._now = frame, frame
		for index, event in ipairs(order) do
			for _, e in ipairs({ env, old }) do
				local slot = e._game.slots[1]
				-- Even within one frame, an action-only update can carry a new duration or charge state.
				slot.cooldown = frame < 3 and { name = "sweep" .. frame .. index } or nil
				slot.chargeDuration = { name = "charge" .. frame .. index }
				slot.charges.isActive = frame == 1 or index == 2
			end
			info.isOnGCD, oldInfo.isOnGCD = event == SPELL, event == SPELL
			env.FireEvent(event)
			previous(old, oldNS, event)
			same()
			-- A second spell notification in the same frame must still refresh a changed GCD flag.
			if event == SPELL then
				info.isOnGCD, oldInfo.isOnGCD = false, false
				env.FireEvent(event)
				previous(old, oldNS, event)
				same()
			end
		end
		button.cooldown:GetScript("OnCooldownDone")(button.cooldown)
		oldButton.cooldown:GetScript("OnCooldownDone")(oldButton.cooldown)
		same()
	end
	AB.Slot(env, 1, nil)
	AB.Slot(old, 1, nil)
	for _ = 1, 2 do
		env.FireEvent(SPELL)
		previous(old, oldNS, SPELL)
		same()
	end
	assert(#env._errors == 0 and #old._errors == 0, AB.Errors(env) .. AB.Errors(old))
	assert(#env._blocked == 0 and #old._blocked == 0, "cooldown updates remain legal in combat")
end

do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local empty = AB.Button(ns, "bar1", 1)
	local clears = #W.Calls(empty.cooldown, "Clear")
	env.FireEvent(SPELL)
	env.FireEvent(ACTION)
	assert(#W.Calls(empty.cooldown, "Clear") == clears, "an empty button must not clear an already clear sweep")
	local button = K.Widgets.IconButton(K.Scale.Root())
	local function clearOnce(set, region, clear)
		assert(set(), "the fixture sets a cooldown")
		local count = #W.Calls(region(), "Clear")
		clear()
		clear()
		assert(#W.Calls(region(), "Clear") == count + 1, "each successful setter must rearm exactly one engine clear")
	end
	local sweep = function() return button.cooldown end
	local charge = function() return button.chargeCooldown end
	local clear = function() ns.Button.UpdateCooldown(button) end
	local clearCharge = clear
	for _ = 1, 2 do
		clearOnce(function() return button:SetCooldown(2, 8, true) end, sweep, clear)
		clearOnce(function() return button:SetCooldownFromDuration({ name = "sweep" }, false) end, sweep, clear)
		clearOnce(function() return button:SetChargeCooldownFromDuration({ name = "charge" }) end, charge, clearCharge)
	end
	local count = #W.Calls(button.cooldown, "Clear")
	assert(button:SetCooldown(env.Secret(2), 8) == false, "secret numeric cooldowns stay refused")
	clear()
	assert(#W.Calls(button.cooldown, "Clear") == count, "a refused setter must not rearm a clear")
	button.cooldown.SetCooldownFromDurationObject = false
	assert(button:SetCooldownFromDuration({}) == false, "missing duration setters stay refused")
	clear()
	assert(#W.Calls(button.cooldown, "Clear") == count, "a missing setter must not rearm a clear")
	assert(#env._errors == 0, AB.Errors(env))
end

print("action bar cooldown event state and clear transitions: ok")
