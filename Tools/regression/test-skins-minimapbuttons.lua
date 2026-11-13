-- test-skins-minimapbuttons.lua: the Blackthornes and 0xgle Bugs buttons keep the angle their addons gave them and stand on the edge of the square map, follow a drag, and get their own anchor back when their switch goes off.
local S = dofile("Tools/regression/skins_env.lua")

local function Near(a, b)
	return math.abs(a - b) < 0.001
end

-- The map is 140 across, so the edge is 70 + the gapSmall margin (4) = 74 from the centre.
local function Boot(shape)
	local env, K, ns = S.New({
		setup = function(env)
			env.Minimap = env.CreateFrame("Frame", "Minimap", env.UIParent)
			env.Minimap:SetSize(140, 140)
			local button = env.CreateFrame("Frame", "OxgleBugsMinimapButton", env.Minimap)
			button:SetSize(30, 30)
			button:SetPoint("CENTER", env.Minimap, "CENTER", 52, -52)
			local combined = env.CreateFrame("Frame", "BlackthornesMinimapButton", env.Minimap)
			combined:SetSize(31, 31)
			combined:SetPoint("CENTER", env.Minimap, "CENTER", -60, 0)
			if shape then
				env.GetMinimapShape = function()
					return shape
				end
			end
		end,
	})
	K.Modules.Enable("Skins")
	env.RunTimers()
	return env, K, ns
end

-- The square map: each button is pushed out along its own angle to the perimeter.
do
	local env = Boot("SQUARE")
	local button = env.OxgleBugsMinimapButton
	local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
	assert(point == "CENTER" and relativeTo == env.Minimap and relativePoint == "CENTER", "the 0xgle Bugs button stays anchored to the map's centre")
	assert(Near(x, 74) and Near(y, -74), "the 0xgle Bugs button stands on the square's corner at its own 45 degrees, got " .. tostring(x) .. ", " .. tostring(y))
	local combined = env.BlackthornesMinimapButton
	local _, _, _, bx, by = combined:GetPoint(1)
	assert(Near(bx, -74) and Near(by, 0), "the Blackthornes button stands on the square's left edge at its own angle, got " .. tostring(bx) .. ", " .. tostring(by))
end

-- A drag moves the angle with it, and the addon's own call is what is followed.
do
	local env, K = Boot("SQUARE")
	local button = env.OxgleBugsMinimapButton
	button:SetPoint("CENTER", env.Minimap, "CENTER", 0, -120)
	local _, _, _, x, y = button:GetPoint(1)
	assert(Near(x, 0) and Near(y, -74), "a drag straight down puts the button on the square's bottom edge, got " .. tostring(x) .. ", " .. tostring(y))
	K.Options.Write("Skins", "oxgleBugs.enabled", false)
	local _, _, _, rx, ry = button:GetPoint(1)
	assert(Near(rx, 0) and Near(ry, -120), "the switch off gives the drag's own anchor back, got " .. tostring(rx) .. ", " .. tostring(ry))
end

-- A round map and an unshaped one leave the buttons where their addons put them.
for _, case in ipairs({ { shape = "ROUND", label = "a round map" }, { shape = nil, label = "no shape at all" } }) do
	local env = Boot(case.shape)
	local button = env.OxgleBugsMinimapButton
	local _, _, _, x, y = button:GetPoint(1)
	assert(Near(x, 52) and Near(y, -52), case.label .. " leaves the 0xgle Bugs button where its addon put it, got " .. tostring(x) .. ", " .. tostring(y))
end

-- Every square shape counts, not only the one the Minimap module publishes.
do
	local env = Boot("TRICORNER-TOPRIGHT")
	local button = env.OxgleBugsMinimapButton
	local _, _, _, x, y = button:GetPoint(1)
	assert(Near(x, 74) and Near(y, -74), "a tricornet square is treated as square, got " .. tostring(x) .. ", " .. tostring(y))
end

-- Blackthornes makes its shared button a frame after login, behind the buttons each addon made: the wait still catches it.
do
	local env, K = S.New({
		setup = function(env)
			env.Minimap = env.CreateFrame("Frame", "Minimap", env.UIParent)
			env.Minimap:SetSize(140, 140)
			env.GetMinimapShape = function()
				return "SQUARE"
			end
			local butler = env.CreateFrame("Frame", "BlackthornesButlerMinimapButton", env.Minimap)
			butler:SetSize(31, 31)
			butler:SetPoint("CENTER", env.Minimap, "CENTER", 0, 75)
		end,
	})
	K.Modules.Enable("Skins")
	env.RunTimers()
	local shared = env.CreateFrame("Frame", "BlackthornesMinimapButton", env.Minimap)
	shared:SetSize(31, 31)
	shared:SetPoint("CENTER", env.Minimap, "CENTER", -60, 0)
	env.RunTickers()
	local _, _, _, x, y = shared:GetPoint(1)
	assert(Near(x, -74) and Near(y, 0), "the shared button made after login lands on the square's left edge too, got " .. tostring(x) .. ", " .. tostring(y))
end

print("skins minimap buttons ok")
