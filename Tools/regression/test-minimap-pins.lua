-- test-minimap-pins.lua: the owner's live map (KSTY-77): RestedXP's guide pins that HereBeDragons floats on the minimap's edge for places off the map are hidden while they ride the edge of the square map, the pins on the map stay, and every addon's named minimap button, LibDBIcon or not, goes into the drawer, never a pin.
local M = dofile("Tools/regression/minimap_env.lua")

local function NoErrors(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
end

-- FakeHBD(env) -> a stand-in for HereBeDragons-Pins-2.0 (minor 17, as RestedXP embeds it): AddMinimapIconWorld
-- registers a pin in minimapPins and parents it to the minimap; Draw(pin, dx, dy) places it as drawMinimapPin does
-- on a square map, dx and dy the place's offset over the map's view radius: a pin past 0.9 of the half-width floats
-- on the edge at 0.9 when it asked to, and hides otherwise.
local function FakeHBD(env)
	local lib = { minimapPins = {}, activeMinimapPins = {} }
	function lib.AddMinimapIconWorld(self, ref, icon, instanceID, x, y, floatOnEdge)
		self.minimapPins[icon] = { instanceID = instanceID, x = x, y = y, floatOnEdge = floatOnEdge }
		icon:SetParent(env.Minimap)
		return true
	end
	function lib.Draw(pin, dx, dy)
		local data = lib.minimapPins[pin]
		local dist = math.max(dx * dx, dy * dy) / 0.81
		if dist > 1 and data.floatOnEdge then
			local root = math.sqrt(dist)
			dx, dy = dx / root, dy / root
		end
		if dist <= 1 or data.floatOnEdge then
			pin:Show()
			pin:ClearAllPoints()
			pin:SetPoint("CENTER", env.Minimap, "CENTER", dx * env.Minimap:GetWidth() / 2, -dy * env.Minimap:GetHeight() / 2)
			lib.activeMinimapPins[pin] = data
		else
			pin:Hide()
			lib.activeMinimapPins[pin] = nil
		end
	end
	return lib
end

local function Pin(env, hbd, floatOnEdge)
	local pin = env.CreateFrame("Button", nil, env.UIParent)
	pin:SetSize(12, 12)
	pin:Hide()
	hbd:AddMinimapIconWorld("RXPGuides", pin, 0, 1, 1, floatOnEdge)
	return pin
end

local hbd, pins, unknown
local env, K, ns = M.New({
	enabled = true,
	setup = function(e)
		local dbicon = M.FakeLibDBIcon(e)
		hbd = FakeHBD(e)
		e.LibStub = setmetatable({}, {
			__call = function(_, major)
				if major == "HereBeDragons-Pins-2.0" then
					return hbd
				end
				return dbicon
			end,
		})
		dbicon:Add("RXPGuides")
		dbicon:Add("BugSack")
		unknown = e.CreateFrame("Button", "SomeGuideMinimapButton", e.Minimap)
		unknown:SetSize(28, 28)
		unknown:SetPoint("CENTER", e.Minimap, "CENTER", 60, 60)
		pins = { inside = Pin(e, hbd, true), named = nil, edgeA = Pin(e, hbd, true), edgeB = Pin(e, hbd, true), plain = Pin(e, hbd, false) }
		pins.named = e.CreateFrame("Button", "GuidePin1", e.UIParent)
		pins.named:SetSize(12, 12)
		hbd:AddMinimapIconWorld("RXPGuides", pins.named, 0, 1, 1, true)
	end,
})
M.Settle(env)
NoErrors(env, K, "login")

local drawer = ns.Map.drawer
for _, button in ipairs({ env.LibDBIcon10_RXPGuides, env.LibDBIcon10_BugSack, unknown }) do
	assert(button:GetParent() == drawer.panel, button:GetName() .. " goes into the drawer, off the map face")
end
assert(drawer:Count() == 3, "the drawer holds the two LibDBIcon buttons and the other addon's own button")

hbd.Draw(pins.inside, 0.3, -0.2)
hbd.Draw(pins.named, 0.5, 0.1)
hbd.Draw(pins.edgeA, 2.4, 0.4)
hbd.Draw(pins.edgeB, -0.1, -3)
hbd.Draw(pins.plain, 0.2, 0.6)
for key, pin in pairs(pins) do
	assert(pin:GetParent() == env.Minimap, key .. ": a map pin stays on the map, never in the drawer")
end
assert(pins.inside:IsShown() and pins.named:IsShown() and pins.plain:IsShown(), "pins for places on the map stay on the map")
assert(not pins.edgeA:IsShown() and not pins.edgeB:IsShown(), "pins floated on the map's edge for places off the map are hidden")

hbd.Draw(pins.edgeA, 0.4, 0.4)
assert(pins.edgeA:IsShown(), "a pin whose place comes onto the map shows again where HereBeDragons puts it")
hbd.Draw(pins.inside, 0, 5)
assert(not pins.inside:IsShown(), "and one whose place leaves the map hides once it rides the edge")

local late = Pin(env, hbd, true)
hbd.Draw(late, -4, 0)
assert(not late:IsShown(), "a pin an addon adds after login is watched too")

K.Options.Write("Minimap", "drawer.edgePins", true)
M.Settle(env)
assert(pins.inside:IsShown() and pins.edgeB:IsShown() and late:IsShown(), "Addon pins on the map's edge brings the edge pins back")
hbd.Draw(pins.edgeB, 0, -6)
assert(pins.edgeB:IsShown(), "and keeps them while it is on")
K.Options.Write("Minimap", "drawer.edgePins", false)
M.Settle(env)
assert(not pins.edgeB:IsShown() and not late:IsShown(), "turning it off hides them again")

K.Modules.Disable("Minimap")
M.Settle(env)
assert(pins.edgeB:IsShown() and late:IsShown() and pins.inside:IsShown(), "turning the minimap off gives every edge pin back to its addon")
NoErrors(env, K, "pins")

print("minimap pins ok")
