-- test-skins-window-reopen.lua: native left-to-right and right-to-left button chains keep their first-open layout after five opens.
local Windows = dofile("Tools/regression/skins_windows.lua")
local S = Windows.S
local selected = { addonlist = true, mail = true, worldmap = true, communities = true, merchant = true, talents = true }
local failures = {}
local function Check(ok, message)
	if not ok then failures[#failures + 1] = message end
end
for _, spec in ipairs(Windows.LIST) do
	if selected[spec.key] and (not arg[1] or arg[1] == spec.key) then
		local B, parts
		local env, K = S.New({ before = function(e)
			B = S.Blizzard(e)
			parts = select(2, Windows.Build(spec.key, e, B))
		end })
		K.Modules.Enable("Skins")
		if spec.addon then S.LoadAddOn(env, spec.addon) end
		local first = {}
		for opened = 1, 5 do
			for _, frame in ipairs(parts.show) do frame:Hide() end
			for _, frame in ipairs(parts.show) do S.Show(frame) end
			env.RunTimers()
			S.W.Settle(env)
			for i, frame in ipairs(B.made) do
				local kind = frame:GetObjectType()
				if kind ~= "Texture" and kind ~= "FontString" and frame:IsShown() then
					local rect = { frame:GetLeft(), frame:GetTop(), frame:GetWidth(), frame:GetHeight() }
					if opened == 1 then
						first[i] = rect
					elseif first[i] then
						for axis = 1, 4 do
							local a, b = first[i][axis], rect[axis]
							Check(not a or not b or math.abs(a - b) < 0.01, spec.key .. ": frame " .. i .. " axis " .. axis .. " drifted on open " .. opened)
						end
					end
				end
			end
			if spec.key == "talents" then
				for _, key in ipairs({ "SearchBox", "ApplyButton", "InspectCopyButton" }) do
					local control = env.PlayerSpellsFrame.TalentsFrame[key]
					Check(math.abs(control:GetHeight() - K.Widgets.Snap(control, 28)) < 0.01, "talents: " .. key .. " must be 28 units on open " .. opened)
				end
			end
		end
		if spec.key == "addonlist" then
			Check(env.AddonList.CancelButton:GetRight() <= env.AddonList:GetRight(), "AddonList Cancel must stay inside the window")
			for _, frame in ipairs(B.made) do
				if frame.LoadAddonButton then Check(frame.LoadAddonButton:GetHeight() <= frame:GetHeight(), "a list-row action must fit inside its native row") end
			end
		end
		Check(#env._errors == 0 and K.ErrorCount() == 0, spec.key .. ": no runtime errors")
		print(spec.key .. ": opened five times")
	end
end
assert(#failures == 0, table.concat(failures, "\n"))
print("native window reopening ok")
