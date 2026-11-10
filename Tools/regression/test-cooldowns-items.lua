-- test-cooldowns-items.lua: item-backed mirror timers use safe item timings, canonical icons and native charge/cast-count priority.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local function plain(env, value)
	if env.issecretvalue(value) then
		return env.Reveal(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function New(kind, change)
	local first = { category = C.CATEGORY.Essential }
	if kind == "equipped" then
		first.equipSlot = 13
	elseif kind == "category" then
		first.spellCategoryID = 30
	else
		first.spellID = 1001
	end
	local state = {
		spell = 7001, itemID = 8001, count = 5, icon = 987654,
		item = { startTime = 990, duration = 30, modRate = 1, isEnabled = true, isActive = true, isOnGCD = false },
		inventory = { 990, 30, 1, false },
		itemCalls = {}, spellCalls = {}, countCalls = {}, inventoryCalls = 0, unsafeCalls = 0,
	}
	local env, K, ns = C.New({
		cooldowns = { [101] = first, [102] = { spellID = 1002, category = C.CATEGORY.Essential, charges = true } },
		setup = function(e)
			C.Game(e)
			local create = e.CreateFrame
			e.CreateFrame = function(objectType, ...)
				local frame = create(objectType, ...)
				if objectType == "Cooldown" then
					local set = frame.SetCooldown
					frame.SetCooldown = function(self, start, duration, rate)
						for _, value in ipairs({ start, duration, rate or 1 }) do
							if e.issecretvalue(value) or not finite(value) then
								state.unsafeCalls = state.unsafeCalls + 1
								error("unsafe numeric cooldown setter")
							end
						end
						if state.setterError then error("item setter failed") end
						return set(self, start, duration, rate)
					end
				end
				return frame
			end
			e.C_Spell.GetLastCategoryCooldownSource = function(category)
				assert(category == 30)
				return state.spell, state.itemID
			end
			e.C_Spell.GetItemCooldown = function(itemID)
				state.itemCalls[#state.itemCalls + 1] = itemID
				if state.itemError then error("item getter failed") end
				return state.item
			end
			local spellDuration = e.C_Spell.GetSpellCooldownDuration
			e.C_Spell.GetSpellCooldownDuration = function(spell, ignoreGCD)
				state.spellCalls[#state.spellCalls + 1] = { spell, ignoreGCD }
				return spellDuration(spell, ignoreGCD)
			end
			e.C_Spell.GetSpellCastCount = function(spell)
				state.countCalls[#state.countCalls + 1] = spell
				if plain(e, spell) == 1002 then return 99 end
				return state.count
			end
			e.C_StringUtil.TruncateWhenZero = function(count)
				local value = plain(e, count)
				local text = value == 0 and "" or tostring(math.floor(value))
				return e.Secret(text)
			end
			e.GetInventoryItemCooldown = function(unit, slot)
				assert(unit == "player" and slot == 13)
				state.inventoryCalls = state.inventoryCalls + 1
				return unpack(state.inventory)
			end
			e.GetInventoryItemTexture = function(unit, slot)
				assert(unit == "player" and slot == 13)
				return state.icon
			end
			e._cdm.charges[1002] = { current = 2, max = 3 }
			if change then change(e, state) end
		end,
	})
	K.Options.Write("Cooldowns", "essential.readyGlow", true)
	C.Enable(env, K)
	local row = ns.Mirror.Row("essential")
	return env, K, ns, row.icons[1], state, row.icons[2]
end

local function raw(icon, start, duration, rate)
	local call = W.LastCall(icon.cooldown, "SetCooldown")
	assert(call and call[1] == start and call[2] == duration and call[3] == rate, "the mirror uses the item's own raw cooldown, including its rate")
end

local function done(icon)
	icon.cooldown:GetScript("OnCooldownDone")(icon.cooldown)
end

local function mirrored(ns)
	assert(ns.Path.Get("essential") == "mirror", "safe item values keep the row mirrored")
end

local function failed(env, ns, icon, state)
	assert(ns.Path.Get("essential") == "reskin", "an unusable item timer falls back to the native viewer")
	assert(not icon.cooldownsRow.content:IsShown() and env._viewers.EssentialCooldownViewer:GetAlpha() == 1, "fallback hides the mirror and restores the native viewer")
	assert(state.unsafeCalls == 0, "unsafe timing never reaches a numeric setter, even inside pcall")
end

do
	local env, _, ns, icon, state = New("equipped")
	mirrored(ns)
	raw(icon, 990, 30, 1)
	assert(icon.icon:GetTexture() == state.icon, "a no-spell equipped entry keeps its inventory icon")
	assert(icon.onCooldown and not icon.ready, "an equipped item is cooling, not ready")
	assert(state.inventoryCalls > 0, "the equipped item timer is read")
	state.inventory = { 0, 0, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(icon.onCooldown == false and icon.ready == true and W.LastCall(icon.cooldown, "Clear"), "clearing an equipped cooldown also clears its cooling state")
	state.inventory = { 990, 30, 1, false }
	state.icon = 123456
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 13, true)
	raw(icon, 990, 30, 1)
	assert(icon.icon:GetTexture() == 123456 and icon.onCooldown and not icon.ready, "equipment-only events refresh both icon and timer")
	env._time = 1025
	done(icon)
	assert(icon.onCooldown == false and icon.ready == true, "completion rechecks the item and clears an expired timer without a spell")
end

do
	local env, _, ns, icon, state, ordinary = New("category")
	mirrored(ns)
	raw(icon, 990, 30, 1)
	assert(icon.icon:GetTexture() == ns.Data.CATEGORY_ICONS[30], "a category deliberately keeps its canonical icon, not the last item's icon")
	for _, call in ipairs(state.spellCalls) do
		assert(plain(env, call[1]) ~= 7001, "an available item timer must not use an unrelated category spell duration")
	end
	assert(icon.count:GetText() == 5, "the resolved category spell supplies its cast count")
	assert(plain(env, ordinary.count:GetText()) == 2, "explicit multi-charge info takes priority over cast count 99")
	assert(W.LastCall(ordinary.cooldown, "SetCooldownFromDurationObject"), "ordinary spells still use duration objects")
	state.spell, state.itemID, state.count = 7002, 8002, 0
	state.item = { startTime = 995, duration = 80, modRate = 2, isEnabled = true, isActive = true }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	raw(icon, 995, 80, 2)
	assert(state.itemCalls[#state.itemCalls] == 8002 and icon.count:GetText() == "", "an item-only event resolves a changed source and clears a plain zero count")
	state.count = 8
	env.FireEvent("SPELL_UPDATE_USES", 7002)
	assert(icon.count:GetText() == 8, "use-count events refresh category counts")
	state.item.duration = 90
	env.FireEvent("SPELL_UPDATE_USES", 7002)
	raw(icon, 995, 90, 2)
	state.item = nil
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	local duration = W.LastCall(icon.cooldown, "SetCooldownFromDurationObject")
	assert(duration and duration[1].spell == 7002, "only an absent item cooldown falls back to the resolved spell duration")
	state.spell, state.itemID = nil, nil
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(icon.onCooldown == false and icon.ready == true and icon.count:GetText() == "", "a cleared category source clears cooldown state and count")
end

do
	local env, _, ns, icon, state = New("category", function(e, s)
		s.spell, s.itemID, s.count = e.Secret(7001), e.Secret(8001), e.Secret(6)
	end)
	mirrored(ns)
	raw(icon, 990, 30, 1)
	assert(plain(env, state.itemCalls[1]) == 8001 and plain(env, state.countCalls[1]) == 7001, "secret source IDs pass only to APIs that accept them")
	assert(plain(env, icon.count:GetText()) == "6", "a poisoned secret count is formatted by the engine and passed straight to the widget")
	state.item = nil
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	mirrored(ns)
	assert(plain(env, W.LastCall(icon.cooldown, "SetCooldownFromDurationObject")[1].spell) == 7001, "the absent item path can still use a secret spell duration object")
end

do
	local env, _, ns, icon = New("category", function(e)
		e._cdm.cooldowns[101].spellID = 9000
	end)
	mirrored(ns)
	assert(icon.icon:GetTexture() == ns.Data.CATEGORY_ICONS[30], "a category keeps its canonical icon even when metadata also has a spell")
	assert(icon.count:GetText() == 5, "category counts use the resolved source, not its catalog spell")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	raw(icon, 990, 30, 1)
end

do
	local env, _, ns, icon, state = New("category", function(e)
		e._cdm.cooldowns[101].spellID = 9000
		e._cdm.cooldowns[101].charges = true
		e._cdm.charges[9000] = { current = 2, max = 3 }
		e._cdm.charges[7001] = { current = 1, max = 2 }
		local get = e.C_Spell.GetSpellCharges
		e.C_Spell.GetSpellCharges = function(spell)
			assert(spell == 9000 or spell == 1002, "charges only query catalog spells")
			return get(spell)
		end
	end)
	mirrored(ns)
	assert(plain(env, icon.count:GetText()) == 2, "explicit charges use the catalog spell, not the category's last source")
	assert(W.LastCall(icon.chargeCooldown, "SetCooldownFromDurationObject")[1].spell == 9000, "recharge duration follows the same catalog spell")
	assert(#state.countCalls == 0, "explicit multi-charge data never queries cast counts")
	env._cdm.charges[9000] = { current = 1, max = 1 }
	env.FireEvent("SPELL_UPDATE_CHARGES")
	assert(icon.count:GetText() == 5, "without multi-charge data, cast count uses the resolved category spell")
	env._cdm.charges[9000] = { current = 2, max = 3 }
	env.C_Spell.GetLastCategoryCooldownSource = nil
	env.FireEvent("SPELL_UPDATE_CHARGES")
	assert(plain(env, icon.count:GetText()) == 2, "an unavailable category source cannot suppress explicit charges")
end

for _, kind in ipairs({ "category", "spell" }) do
	local env, _, ns, icon, state = New(kind, function(e, s) s.count = e.Secret(0) end)
	mirrored(ns)
	assert(plain(env, icon.count:GetText()) == "", "secret zero use count is empty without a Lua comparison")
	state.count = env.Secret(6)
	env.FireEvent("SPELL_UPDATE_USES", 7001)
	assert(plain(env, icon.count:GetText()) == "6", "positive secret uses are still visible")
	state.count = env.Secret(0)
	env.FireEvent("SPELL_UPDATE_USES", 7001)
	assert(plain(env, icon.count:GetText()) == "", "a later secret zero clears the old count")
end

for _, change in ipairs({
	function(e) e.C_StringUtil.TruncateWhenZero = nil end,
	function(e) e.C_StringUtil.TruncateWhenZero = function() error("formatter failed") end end,
	function(e) e.C_StringUtil.TruncateWhenZero = function() return nil end end,
}) do
	local env, _, ns, icon, state = New("category", function(e, s)
		s.count = e.Secret(6)
		change(e)
	end)
	failed(env, ns, icon, state)
end

for _, kind in ipairs({ "equipped", "category" }) do
	local env, _, ns, icon, state = New(kind, function(_, s)
		s.inventory[4] = true
		s.item.isOnGCD = true
	end)
	assert(icon.onCooldown and not icon.ready, "initial item refresh must not trust the GCD flag")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(icon.onCooldown == false and icon.ready == true, "only the spell cooldown event can classify item GCD")
	for _, event in ipairs({ "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED", "SPELL_UPDATE_USES" }) do
		env.FireEvent(event, 13, true)
		assert(icon.onCooldown and not icon.ready, event .. " must not validate the GCD flag")
	end
	done(icon)
	assert(icon.onCooldown and not icon.ready, "completion is not a spell cooldown event")
	state.inventory, state.item = { 0, 0, 1, false }, { startTime = 0, duration = 0, modRate = 1, isEnabled = true, isActive = false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(icon.onCooldown == false and icon.ready == true, "an inactive item clears state")
	mirrored(ns)
end

for _, field in ipairs({ "startTime", "duration", "modRate", "isEnabled", "isActive" }) do
	local env, _, ns, icon, state = New("category", function(e, s)
		s.item[field] = e.Secret(s.item[field])
	end)
	failed(env, ns, icon, state)
end
for _, field in ipairs({ "startTime", "duration", "modRate" }) do
	for _, value in ipairs({ 0 / 0, math.huge, -math.huge }) do
		local env, _, ns, icon, state = New("category", function(_, s) s.item[field] = value end)
		failed(env, ns, icon, state)
	end
end
for _, index in ipairs({ 1, 2, 3 }) do
	local env, _, ns, icon, state = New("equipped", function(e, s) s.inventory[index] = e.Secret(s.inventory[index]) end)
	failed(env, ns, icon, state)
end
for _, index in ipairs({ 1, 2 }) do
	for _, value in ipairs({ 0 / 0, math.huge, -math.huge }) do
		local env, _, ns, icon, state = New("equipped", function(_, s) s.inventory[index] = value end)
		failed(env, ns, icon, state)
	end
end
for _, change in ipairs({
	function(e) e.GetInventoryItemCooldown = nil end,
	function(e) e.GetInventoryItemCooldown = function() error("inventory getter failed") end end,
	function(_, s) s.inventory[3] = true end,
	function(_, s) s.inventory[3] = 7 end,
	function(_, s) s.inventory[3] = 0 end,
}) do
	local env, _, ns, icon, state = New("equipped", change)
	failed(env, ns, icon, state)
end
for _, change in ipairs({
	function(e) e.C_Spell.GetItemCooldown = nil end,
	function(e) e.C_Spell.GetLastCategoryCooldownSource = nil end,
	function(e) e.C_Spell.GetLastCategoryCooldownSource = function() error("source getter failed") end end,
	function(_, s) s.itemError = true end,
	function(_, s) s.setterError = true end,
	function(e, s) s.item = e.Secret({}) end,
	function(_, s) s.item.modRate = nil end,
	function(_, s) s.item.isEnabled = 1 end,
	function(_, s) s.item.isActive = 1 end,
	function(_, s) s.item.isEnabled = false end,
	function(_, s) s.item.modRate = 0 end,
	function(_, s) s.item.duration = -1 end,
}) do
	local env, _, ns, icon, state = New("category", change)
	failed(env, ns, icon, state)
end

do
	local env, _, ns, icon, state = New("category", function(e, s) s.item.isOnGCD = e.Secret(true) end)
	mirrored(ns)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	failed(env, ns, icon, state)
end

do
	local env, _, ns, icon, state = New("equipped", function(e, s) s.inventory[4] = e.Secret(true) end)
	mirrored(ns)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	failed(env, ns, icon, state)
end

do
	local env, _, ns, icon = New("category")
	env._time = 1030
	done(icon)
	mirrored(ns)
	assert(icon.onCooldown == false and icon.ready == true, "category completion clears its own expired item timer without consulting the category spell")
end

do
	local env, _, ns, icon, state = New("category")
	state.item = nil
	env.C_Spell.GetSpellCooldownDuration = nil
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	failed(env, ns, icon, state)
end

do
	local env, _, ns, icon, state = New("spell")
	mirrored(ns)
	assert(W.LastCall(icon.cooldown, "SetCooldownFromDurationObject")[1].spell == 1001, "ordinary spell cooldowns keep their duration-object path")
	assert(icon.count:GetText() == 5, "ordinary use-count spells follow the native count fallback")
	local count = #state.spellCalls
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 13, true)
	assert(#state.spellCalls == count, "item-only events do not refresh unrelated ordinary spell timers")
	state.count = 0
	env.FireEvent("SPELL_UPDATE_USES", 1001)
	assert(icon.count:GetText() == "", "ordinary plain zero use counts clear")
end

print("cooldowns items ok")
