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
	assert(#env._errors == 0 and K.ErrorCount() == 0, spec.key .. ": " .. tostring(env._errors[1]))
end

print("skins window metrics ok")
