-- test-layout-labels.lua: video issues 4-7 keep tags, coordinates, game text, thin movers and the toolbar apart.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function Overlap(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01
		and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local failed = {}
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 }, { 5120, 1440 } }) do
	local env, K = W.New({ width = screen[1], height = screen[2], size = "auto", uiScale = 768 / 1080,
		setup = function(e) e._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end end })
	local function Element(key, label, x, y, width, height)
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		frame:SetSize(width, height)
		K.Layout.Register(frame, key, { anchor = "BOTTOM", x = x, y = y }, { label = label, scalable = true })
		assert(K.Layout.Update(key, { anchor = "BOTTOM", x = x, y = y }))
	end
	Element("cooldowns.essential", "Essential cooldowns", 0, 339, 490, 80)
	Element("cooldowns.utility", "Utility cooldowns", 0, 405, 300, 80)
	Element("databars.xp", "Experience bar", 0, 52, 1200, 3)
	Element("actionbars.bar1", "Action Bar 1", -340, 62, 520, 42)
	Element("databars.strip", "Clock", 0, 37, 1200, 12)
	Element("chat.main", "Chat", -650, 17, 442, 186)
	assert(K.Layout.Enter())
	local Mode = K.Layout.Mode
	Mode.Select("cooldowns.utility")
	Scene.Build(env)
	local function Rect(region) return { Scene.Rect(env, region) } end
	local function Check(issue, fn)
		local ok, err = pcall(fn)
		if not ok then failed[#failed + 1] = screen[1] .. " issue " .. issue .. ": " .. tostring(err) end
	end
	Check(4, function()
		local plate = Mode.Plate("cooldowns.utility")
		assert(not Overlap(Rect(Mode.Plate("cooldowns.essential").label), Rect(plate.info)),
			"keep one mover's readout clear of its neighbour's name even when their bodies overlap")
		assert(not Overlap(Rect(plate.label), Rect(plate.info)), "put the mover name and coordinates on separate lines")
		for _, key in ipairs({ "cooldowns.essential", "cooldowns.utility" }) do
			local tag = Rect(Mode.Plate(key).tag)
			for _, other in ipairs({ "cooldowns.essential", "cooldowns.utility" }) do
				assert(not Overlap(tag, Rect(Mode.Plate(other))), "place cooldown tags outside occupied movers")
			end
		end
	end)
	Check(5, function()
		assert(not Overlap(Rect(Mode.Toolbar()), Rect(Mode.Plate("integrations.announcementLane"))),
			"place the toolbar above the boss announcements mover")
	end)
	Check(6, function()
		local plate = Mode.Plate("databars.xp")
		assert(plate:GetHeight() == 16, "keep the 16-unit thin mover grab area used by wheel and coverage hit tests")
		assert(not Overlap(Rect(plate), Rect(Mode.Plate("actionbars.bar1"))), "keep the XP mover below Action Bar 1")
		assert(not Overlap(Rect(plate.tag), Rect(Mode.Plate("databars.strip"))), "keep the XP label clear of the clock")
	end)
	Check(7, function()
		assert(not Overlap(Rect(Mode.Plate("chat.main").tag), Rect(Mode.Plate("chat.main"))),
			"place the chat label outside the chat's tabs and messages")
	end)
	Check("tags", function()
		for _, coordinates in ipairs({ true, false }) do
			K.Options.Write("Layout", "showCoordinates", coordinates)
			Scene.Build(env)
			local tags = {}
			for _, el in ipairs(K.Layout.Elements()) do
				local plate = Mode.Plate(el.key)
				if plate and plate:IsShown() then
					local tag = Rect(plate.tag)
					assert(plate.tag:IsShown(), "every fixture's name remains visible: " .. el.key)
					for _, other in ipairs(K.Layout.Elements()) do
						local mover = Mode.Plate(other.key)
						if mover and mover:IsShown() then
							Check("tags", function() assert(not Overlap(tag, Rect(mover)), "keep tags outside all movers") end)
						end
					end
					for _, other in ipairs(tags) do
						Check("tags", function() assert(not Overlap(tag, other), "keep adjacent tags apart") end)
					end
					tags[#tags + 1] = tag
				end
			end
		end
	end)
	assert(#env._errors == 0, tostring(env._errors[1]))
end
for _, err in ipairs(failed) do print(err) end
assert(#failed == 0, "fix Layout Mode label packing, toolbar placement and thin mover footprints")
print("layout labels ok: video issues 4-7 at four screen sizes")
