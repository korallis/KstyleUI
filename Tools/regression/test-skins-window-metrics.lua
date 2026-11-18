-- test-skins-window-metrics.lua: each native window family opts into the same title, content and control measures.
local Windows = dofile("Tools/regression/skins_windows.lua")
local S = Windows.S

for _, spec in ipairs(Windows.LIST) do
	local B, parts
	local env, K, ns = S.New({ before = function(e)
		B = S.Blizzard(e)
		parts = select(2, Windows.Build(spec.key, e, B))
	end })
	K.Modules.Enable("Skins")
	if spec.addon then S.LoadAddOn(env, spec.addon) end
	for _, frame in ipairs(parts.show) do S.Show(frame) end
	env.RunTimers()
	S.W.Settle(env)
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
end

print("skins window metrics ok")
