-- aura_fixture_engine.lua: native aura filtering, sorting, binding (a timer formats with its textFormatter), dispel edges (aura.dispel, aura.stealable) and flow layout (a group starts its new line groupLineSpacing below the last, 0 unless set, as the engine's defaults) at the test boundary; fixtures stay outside addon Lua.
local Engine = {}
local GAME = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 }, Bleed = { 0.8, 0.1, 0.1 } }

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
			if count > 0 and offset > 0 then offset = offset + (group.layout.groupLineSpacing or 0) end
			container:_Acquire(key, count)
			group.assigned = {}
			local layout = group.layout
			local w, h, gap = layout.elementWidth, layout.elementHeight, layout.elementSpacing or 0
			local dx, dy = unpack(container._growth or { 1, -1 })
			local line, columns, run = container._line or math.huge, 1, w
			while columns < count and run + gap + w <= line do columns, run = columns + 1, run + gap + w end
			for i, button in ipairs(group.buttons) do
				button:SetShown(i <= count)
				if i <= count then
					local aura = matches[i]
					group.assigned[i] = aura.id
					button:ClearAllPoints()
					button:SetSize(w, h)
					button:SetPoint(container._anchor or "TOPLEFT", container, container._anchor or "TOPLEFT",
						dx * ((i - 1) % columns) * (w + gap), dy * (offset + math.floor((i - 1) / columns) * (h + (layout.lineSpacing or 0))))
					local bindings = button._aura
					if bindings.SetIcon then bindings.SetIcon[1]:SetTexture(env.Secret(aura.icon)) end
					local timer = bindings.SetDurationText
					local f = timer and timer[2] and timer[2].textFormatter
					if timer then timer[1]:SetText(env.Secret(f and f:Format(aura.left) or aura.left .. "s")) end
					if bindings.SetApplicationCount then bindings.SetApplicationCount[1]:SetText(env.Secret(aura.count or "")) end
					if bindings.SetDurationCooldown then bindings.SetDurationCooldown[1]:SetCooldown(env._time - 4, aura.left + 4) end
					if bindings.AddPandemicRegion then bindings.AddPandemicRegion[1]:SetShown(aura.pandemic == true) end
					local o = bindings.dispelOptions
					if o and (aura.dispel or bindings.dispelShown) then
						local show = aura.dispel ~= nil and (aura.harmful and o.showWhenHarmful or not aura.harmful and o.showWhenHelpful)
							and (o.stealableFilter == nil or aura.stealable) and true or false
						for _, texture in ipairs(bindings.dispel) do
							texture:SetShown(show)
							if show then texture:SetVertexColor(0.2, 0.6, 1) end
						end
						bindings.dispelShown = show
					end
				end
			end
			if count > 0 then
				local rows = math.ceil(count / columns)
				offset = offset + rows * h + (rows - 1) * (layout.lineSpacing or 0)
				wide = math.max(wide, math.min(count, columns) * (w + gap) - gap)
			end
		end
		container:SetSize(math.max(1, wide), math.max(1, offset))
		for _, slot in pairs(container._slots or {}) do
			local aura
			for _, each in ipairs(unit and container._enabled ~= false and slot.enabled and unit.auras or {}) do
				if each.dispel and Matches(each, slot.filter) then aura = aura or each end
			end
			slot.frame:SetShown(aura ~= nil)
			for _, texture in ipairs(aura and slot.frame._aura.dispel or {}) do
				local o = slot.frame._aura.dispelFor[texture]
				local c = o.customDispelColorMap and o.customDispelColorMap[aura.dispel]
				if o.customDispelAssetMap then texture:SetTexture(o.customDispelAssetMap[aura.dispel].asset) end
				texture:SetShown(true)
				local game = GAME[aura.dispel] or GAME.Magic
				texture:SetVertexColor(c and c.r or game[1], c and c.g or game[2], c and c.b or game[3])
			end
		end
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
