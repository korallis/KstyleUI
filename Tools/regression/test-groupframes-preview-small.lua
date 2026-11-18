-- test-groupframes-preview-small.lua: tall raid settings render and refresh inside the minimum Options window (#444).
local G = dofile("Tools/regression/group_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Scene = dofile("Tools/render/scene.lua")

for _, style in ipairs({ "Medallions", "Frames", "Orbs" }) do
	local env, K = G.New({ setup = function(e)
		e.C_AddOns = { LoadAddOn = function(name)
			if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
			return true
		end }
	end })
	local function settle()
		env.RunTimers()
		O.W.Settle(env)
		env.RunTimers()
	end
	K.Options.Write("HudStyle", "style", style:lower())
	K.Options.Write("GroupFrames", "raid.height", 120)
	K.Options.Write("GroupFrames", "raid.spacing", 40)
	K.Options.Write("GroupFrames", "raid.width", 40)
	assert(K.Options.Open("Profiles"))
	settle()
	local options = env._addons.KstyleUI_Options
	local window = options.Window.Frame()
	window:SetSize(880, 520)
	settle()
	assert(K.Options.Open("GroupFrames"))
	settle()
	local pane = options.Window.Parts().preview
	local preview = pane.current
	local function check(what)
		for _, canvas in ipairs({ preview.canvas, preview.raidCanvas }) do
			assert(canvas:GetNumPoints() > 0, style .. ": " .. what .. ": place both sample canvases")
		end
		local x, y, w, h = Scene.Rect(env, pane.holder)
		for _, block in ipairs({ preview.party, preview.raid, preview.clickCast }) do
			if block:IsVisible() then
				local bx, by, bw, bh = Scene.Rect(env, block)
				assert(bx >= x - 0.01 and by >= y - 0.01 and bx + bw <= x + w + 0.01 and by + bh <= y + h + 0.01,
					style .. ": " .. what .. ": fit the visible preview blocks inside their holder")
			end
		end
		for _, frames in ipairs({ preview.partyFrames, preview.raidFrames }) do
			for _, sample in ipairs(frames) do
				assert(sample.name:GetText() and sample.name:GetText() ~= "", style .. ": " .. what .. ": paint every sample")
				for _, text in ipairs({ sample.name, sample.healthText }) do
					local _, height = text:GetFont()
					assert(height >= 1 and height * K.Widgets.ScaleFactor(text) >= K.Scale.Pixel(1) - 0.001,
						style .. ": " .. what .. ": keep sample fonts above the floor")
				end
			end
		end
		assert(#env._errors == 0, table.concat(env._errors, "\n"))
	end
	check("first open")
	K.Options.Write("GroupFrames", "raid.height", 110)
	K.Options.Write("GroupFrames", "raid.spacing", 32)
	K.Options.Write("GroupFrames", "raid.healthText", "PERCENT")
	settle()
	check("settings change")
	assert(preview.raidFrames[1]:GetHeight() == 110, "use the changed raid dimensions")
	local formatted = preview.raidFrames[1].healthText._state.FormattedText
	assert(formatted and formatted[1] == "%d%%" and formatted[2] == 72, "paint the new health format instead of stale text")
	window:SetSize(1040, 850)
	settle()
	check("enlarged")
	window:SetSize(880, 520)
	settle()
	check("shrunk again")
end

print("groupframes small preview ok")
