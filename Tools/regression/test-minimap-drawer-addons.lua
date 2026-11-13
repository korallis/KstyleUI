-- test-minimap-drawer-addons.lua: the drawer collects the minimap buttons Blackthornes and 0xgle Bugs draw themselves, keeps them through their addons' own moves and shows, and hands them back where their addons last put them.
local M = dofile("Tools/regression/minimap_env.lua")

local function NoErrors(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
end

local function Thornes(env, name, degrees)
	local a = math.rad(degrees)
	local r = env.Minimap:GetWidth() / 2 + 5
	local button = env.CreateFrame("Button", name, env.Minimap)
	button:SetSize(31, 31)
	button:RegisterForDrag("LeftButton")
	button.backdrop = button:CreateTexture(nil, "BACKGROUND")
	button.art = button:CreateTexture(nil, "ARTWORK")
	button.art:SetSize(18, 18)
	button.art:SetPoint("CENTER")
	button.ring = button:CreateTexture(nil, "OVERLAY")
	button.ring:SetSize(53, 53)
	button.ring:SetPoint("TOPLEFT")
	button:SetPoint("CENTER", env.Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
	return button
end

local function Oxgle(env)
	local button = env.CreateFrame("Button", "OxgleBugsMinimapButton", env.Minimap)
	button:SetSize(30, 30)
	button:RegisterForDrag("LeftButton")
	button.backdrop = button:CreateTexture(nil, "BACKGROUND")
	button.backdrop:SetAllPoints()
	button.art = button:CreateTexture(nil, "ARTWORK")
	button.art:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
	button.art:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
	button.edge = button:CreateTexture(nil, "BORDER")
	button:SetPoint("CENTER", env.Minimap, "CENTER", 52, -52)
	return button
end

local env, K, ns = M.New({
	enabled = true,
	setup = function(e)
		Oxgle(e)
		Thornes(e, "BlackthornesButlerMinimapButton", 290)
		Thornes(e, "BlackthornesPetsMinimapButton", 260)
	end,
})
M.Settle(env)
NoErrors(env, K, "login")

local drawer = ns.Map.drawer
local toggle = ns.Map.column.buttons.drawer
local bugs, butler, pets = env.OxgleBugsMinimapButton, env.BlackthornesButlerMinimapButton, env.BlackthornesPetsMinimapButton

-- Collecting -----------------------------------------------------------------------------------------------------

for _, button in ipairs({ bugs, butler, pets }) do
	assert(button:GetParent() == drawer.panel, button:GetName() .. " moves into the drawer, off the map")
	assert(select(2, button:GetPoint(1)) == drawer.panel, button:GetName() .. " sits in the drawer's grid")
	assert(button.art:GetAlpha() ~= 0, button:GetName() .. " keeps its own icon")
	assert(button.backdrop:GetAlpha() == 0, button:GetName() .. " loses its own backdrop for the drawer's tile")
end
assert(butler.ring:GetAlpha() == 0, "the round ring Blackthornes draws for a circle map goes")
assert(drawer:Count() == 3 and toggle:IsShown(), "the drawer button shows for the three buttons")
local _, _, _, ix, iy = butler.art:GetPoint(1)
assert(select(1, butler.art:GetPoint(1)) == "CENTER" and (ix or 0) == 0 and (iy or 0) == 0, "the icon is centred on its tile as a LibDBIcon one is")

-- The addons keep running their own code -------------------------------------------------------------------------

local r = env.Minimap:GetWidth() / 2 + 5
butler:ClearAllPoints()
butler:SetPoint("CENTER", env.Minimap, "CENTER", 0, -r)
assert(select(2, butler:GetPoint(1)) == drawer.panel and butler:GetNumPoints() == 1, "an addon's own move puts the button back in its drawer slot")

local shared = Thornes(env, "BlackthornesMinimapButton", 200)
butler:Hide()
pets:Hide()
assert(drawer:Count() == 1, "the buttons Blackthornes hides when it combines them leave the grid")
env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
env.RunTimers()
M.Settle(env)
assert(shared:GetParent() == drawer.panel, "the shared button Blackthornes makes a frame after login joins the drawer")
assert(drawer:Count() == 2, "the shared button and 0xgle Bugs fill the grid")
NoErrors(env, K, "addon moves")

-- Handing back ---------------------------------------------------------------------------------------------------

K.Options.Write("Minimap", "column.drawer", false)
M.Settle(env)
assert(bugs:GetParent() == env.Minimap and butler:GetParent() == env.Minimap, "with the drawer off, the buttons go back on the map")
local point, relativeTo, relativePoint, x, y = bugs:GetPoint(1)
assert(point == "CENTER" and relativeTo == env.Minimap and relativePoint == "CENTER" and x == 52 and y == -52 and bugs:GetNumPoints() == 1, "0xgle Bugs is back where its addon put it")
local _, _, _, bx, by = butler:GetPoint(1)
assert(math.abs(bx) < 0.001 and by == -r, "Butler is back where its addon last moved it, not where it was at login")
local a1, _, _, ax, ay = bugs.art:GetPoint(1)
local a2, _, _, bx2, by2 = bugs.art:GetPoint(2)
assert(bugs.art:GetNumPoints() == 2 and a1 == "TOPLEFT" and ax == 3 and ay == -3 and a2 == "BOTTOMRIGHT" and bx2 == -3 and by2 == 3, "0xgle Bugs' icon gets its own inset back")
assert(select(1, butler.art:GetPoint(1)) == "CENTER" and math.abs(butler.art:GetWidth() - 18) < 0.001, "Blackthornes' icon gets its own size back")
assert(math.abs(bugs:GetWidth() - 30) < 0.001 and math.abs(shared:GetWidth() - 31) < 0.001, "each button gets its own size back")
NoErrors(env, K, "handing back")

-- A frame of the same name that another addon already took off the map is left alone -----------------------------

do
	local oenv, oK, ons = M.New({
		enabled = true,
		setup = function(e)
			local holder = e.CreateFrame("Frame", nil, e.UIParent)
			local button = Oxgle(e)
			button:SetParent(holder)
		end,
	})
	M.Settle(oenv)
	assert(oenv.OxgleBugsMinimapButton:GetParent() ~= ons.Map.drawer.panel, "a button not on the map is not the drawer's to take")
	NoErrors(oenv, oK, "elsewhere")
end

print("minimap drawer addons ok")
