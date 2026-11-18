-- test-skins-window-metrics.lua: each native window family opts into the same title, content and control measures.
local Windows = dofile("Tools/regression/skins_windows.lua")
local S = Windows.S

local function Boot(spec, metrics)
	local B, parts
	local env, K, ns = S.New({ saved = {
		version = 12, profiles = { Default = { Skins = { windowMetrics = metrics } } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
	}, before = function(e)
		B = S.Blizzard(e)
		parts = select(2, Windows.Build(spec.key, e, B))
	end })
	K.Modules.Enable("Skins")
	if spec.addon then S.LoadAddOn(env, spec.addon) end
	for _, frame in ipairs(parts.show) do S.Show(frame) end
	env.RunTimers()
	S.W.Settle(env)
	return env, K, ns, parts
end

for _, spec in ipairs(Windows.LIST) do
	local env, K, ns = Boot(spec, true)
	local count = 0
	for _, key in ipairs(spec.skins) do
		local def = ns.Skins.Get(key)
		if def.metrics then
			for _, name in ipairs(type(def.metrics) == "table" and def.metrics or { def.frame }) do
				local frame = env[name]
				local skin = frame and K.Skin.Parts(frame)
				if skin and skin.backdrop then
					count = count + 1
					assert(skin.backdrop.chrome.headerUnits == 32, spec.key .. ": use the 32-unit window title band")
					local container = frame.TitleContainer or type(frame.BorderFrame) == "table" and frame.BorderFrame.TitleContainer
					local title = container and container.TitleText or frame.Header and frame.Header.Text
					if title then
						assert(select(2, title:GetFont()) == K.Widgets.FontSize(title, 16), spec.key .. ": the window title reads at 16 units")
					end
				end
			end
		end
	end
	assert(count > 0, spec.key .. ": opt this window family into the shared native window measures")
	if spec.key == "merchant" then
		for _ = 1, 5 do
			env.MerchantFrame_UpdateMerchantInfo()
			local point, relative, on, _, y = env.MerchantItem2.AltCurrencyFrame:GetPoint(1)
			assert(point == "BOTTOMLEFT" and relative == env.MerchantItem2 and on == "BOTTOMLEFT" and math.abs(y) < 0.5, "native merchant updates must keep token prices below wrapped names")
		end
		env.MerchantItem2.MoneyFrame:Show()
		env.MerchantFrame_UpdateMerchantInfo()
		local mixedPoint, mixedRelative, mixedOn = env.MerchantItem2.AltCurrencyFrame:GetPoint(1)
		assert(mixedPoint == "LEFT" and mixedRelative == env.MerchantItem2.MoneyFrame and mixedOn == "RIGHT", "mixed gold and token prices retain Blizzard's separate currency chain")
		env.MerchantItem2.MoneyFrame:Hide()
		env.MerchantFrame_UpdateMerchantInfo()
		assert(env.MerchantItem1:GetTop() < env.MerchantFrame.FilterDropdown:GetBottom(), "merchant goods begin below the filter control")
		for i = 1, 10 do
			local slot = env["MerchantItem" .. i]
			assert(select(2, slot.MoneyFrame:GetFont()) == K.Widgets.FontSize(slot.MoneyFrame, 12), "merchant prices use the secondary text lane")
			local _, parent, _, _, y = slot.MoneyFrame:GetPoint(1)
			assert(parent == slot and math.abs(y) < 0.5, "merchant prices sit below two-line names at the row's lower edge")
		end
	end
	if spec.key == "trainer" then
		assert(env.ClassTrainerFrame.ScrollBox:GetTop() < env.ClassTrainerFrame.FilterDropdown:GetBottom(), "trainer rows begin below the filter and rank header")
	end
	if spec.key == "addonlist" then
		assert(env.AddonList.ScrollBox:GetTop() < env.AddonList.SearchBox:GetBottom(), "addon rows begin below the search control")
	end
	if spec.key == "friends" then
		assert(env.FriendsListFrame.ScrollBox:GetTop() < env.FriendsFrame.FriendsTabHeader.BattlenetFrame:GetBottom(), "the friends list begins below its broadcast header")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, spec.key .. ": " .. tostring(env._errors[1]))
	local prompts = 0
	K.Widgets.ReloadPrompt = function() prompts = prompts + 1 end
	K.Options.Write("Skins", "windowMetrics", false)
	assert(prompts == 1, "changing native window metrics uses the existing reload choice")
	local oldEnv, oldK, oldNs = Boot(spec, false)
	for _, key in ipairs(spec.skins) do
		local def = oldNs.Skins.Get(key)
		if def.metrics then
			for _, name in ipairs(type(def.metrics) == "table" and def.metrics or { def.frame }) do
				local frame = oldEnv[name]
				local skin = frame and oldK.Skin.Parts(frame)
				assert(not skin or not skin.backdrop or skin.backdrop.chrome.headerUnits ~= 32, spec.key .. ": reloading with metrics off restores the previous title band")
			end
		end
	end
	assert(#oldEnv._errors == 0 and oldK.ErrorCount() == 0, spec.key .. ": previous metrics reloads without errors")
end

print("skins window metrics ok")
