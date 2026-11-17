-- aura_fixture_engine.lua: native aura filtering, sorting, binding and flow layout at the test boundary; fixtures stay outside addon Lua.
local Engine = {}

local function Matches(aura, filter)
	for part in filter:gmatch("[^| ]+") do
		if part == "HARMFUL" and not aura.harmful or part == "HELPFUL" and aura.harmful
			or part == "PLAYER" and not aura.mine or part == "!PLAYER" and aura.mine then
			return false
		end
	end
	return true
end

function Engine.Refresh(env)
	if env._refreshingAuraFixtures then return end
	env._refreshingAuraFixtures = true
	local restricted = env._restricted
	env._restricted = false
	for _, container in ipairs(env._containers) do
		local unit = env._units[container._unit]
		local offset, wide = 0, 0
		for _, key in ipairs(container._order) do
			local group, matches = container._groups[key], {}
			if unit and container._enabled ~= false and group.enabled then
				for _, aura in ipairs(unit.auras or {}) do
					if Matches(aura, group.filter) then matches[#matches + 1] = aura end
				end
			end
			local method = group.sort and group.sort[1] or group.options.sortMethod
			if method == env.AuraContainerSortMethod.ExpirationOnly or method == env.AuraContainerSortMethod.Expiration then
				table.sort(matches, function(a, b)
					if method == env.AuraContainerSortMethod.Expiration and a.mine ~= b.mine then return a.mine end
					if a.left ~= b.left then return a.left < b.left end
					return a.id < b.id
				end)
			end
			local count = math.min(#matches, group.max)
			container:_Acquire(key, count)
			group.assigned = {}
			local layout = group.layout
			local w, h, gap = layout.elementWidth, layout.elementHeight, layout.elementSpacing or 0
			local columns = math.max(1, math.floor(((container._line or math.huge) + gap) / (w + gap)))
			for i, button in ipairs(group.buttons) do
				button:SetShown(i <= count)
				if i <= count then
					local aura = matches[i]
					group.assigned[i] = aura.id
					button:ClearAllPoints()
					button:SetSize(w, h)
					button:SetPoint(container._anchor or "TOPLEFT", container, container._anchor or "TOPLEFT",
						(i - 1) % columns * (w + gap), -(offset + math.floor((i - 1) / columns) * (h + (layout.lineSpacing or 0))))
					local bindings = button._aura
					if bindings.SetIcon then bindings.SetIcon[1]:SetTexture(env.Secret(aura.icon)) end
					if bindings.SetDurationText then bindings.SetDurationText[1]:SetText(env.Secret(aura.left .. "s")) end
					if bindings.SetApplicationCount then bindings.SetApplicationCount[1]:SetText(env.Secret(aura.count or "")) end
					if bindings.SetDurationCooldown then bindings.SetDurationCooldown[1]:SetCooldown(env._time - 4, aura.left + 4) end
					if bindings.AddPandemicRegion then bindings.AddPandemicRegion[1]:SetShown(aura.pandemic == true) end
				end
			end
			if count > 0 then
				offset = offset + math.ceil(count / columns) * h
				wide = math.max(wide, math.min(count, columns) * (w + gap) - gap)
			end
		end
		container:SetSize(math.max(1, wide), math.max(1, offset))
	end
	env._restricted = restricted
	env._refreshingAuraFixtures = false
end

function Engine.Install(env)
	local listener = env.CreateFrame("Frame")
	for _, event in ipairs({ "UNIT_AURA", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH" }) do listener:RegisterEvent(event) end
	listener:SetScript("OnEvent", function() Engine.Refresh(env) end)
	Engine.Refresh(env)
end

return Engine
