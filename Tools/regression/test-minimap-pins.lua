-- test-minimap-pins.lua: the owner's live map (KSTY-77): RestedXP's guide pins that HereBeDragons floats on the minimap's edge for places off the map are faded out while they ride the edge of the square map, the pins on the map stay, and every addon's named minimap button, LibDBIcon or not, goes into the drawer, never a pin, a pin HereBeDragons released or a button nobody can click.
local M = dofile("Tools/regression/minimap_env.lua")
local Budget = dofile("Tools/regression/instruction_budget.lua")

local function NoErrors(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
end

-- FakeHBD(env) -> a stand-in for HereBeDragons-Pins-2.0 (minor 17, as RestedXP embeds it): AddMinimapIconWorld
-- registers a pin in minimapPins and parents it to the minimap; Draw(pin, dx, dy) places it as drawMinimapPin does
-- on a square map, dx and dy the place's offset over the map's view radius: a pin past 0.9 of the half-width floats
-- on the edge at 0.9 when it asked to, and hides otherwise. RemoveMinimapIcon forgets a pin and hides it where it is,
-- still a child of the minimap, as the library does.
local function FakeHBD(env)
	local lib = { minimapPins = {}, activeMinimapPins = {} }
	function lib.AddMinimapIconWorld(self, ref, icon, instanceID, x, y, floatOnEdge)
		self.minimapPins[icon] = { instanceID = instanceID, x = x, y = y, floatOnEdge = floatOnEdge }
		icon:SetParent(env.Minimap)
		return true
	end
	function lib.RemoveMinimapIcon(self, _, icon)
		self.minimapPins[icon], self.activeMinimapPins[icon] = nil, nil
		icon:Hide()
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
	pin:EnableMouse(true)
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
		unknown:SetScript("OnClick", function() end)
		pins = { inside = Pin(e, hbd, true), named = nil, edgeA = Pin(e, hbd, true), edgeB = Pin(e, hbd, true), plain = Pin(e, hbd, false) }
		pins.named = e.CreateFrame("Button", "GuidePin1", e.UIParent)
		pins.named:SetSize(12, 12)
		hbd:AddMinimapIconWorld("RXPGuides", pins.named, 0, 1, 1, true)
	end,
})
M.Settle(env)
NoErrors(env, K, "login")

-- A pin its addon hid is not on show, and neither is one KstyleUI faded out on the map's edge.
local function Seen(pin)
	return pin:IsShown() and pin:GetAlpha() ~= 0
end

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
assert(Seen(pins.inside) and Seen(pins.named) and Seen(pins.plain), "pins for places on the map stay on the map")
assert(not Seen(pins.edgeA) and not Seen(pins.edgeB), "pins floated on the map's edge for places off the map are hidden")
assert(pins.edgeA:IsShown() and not pins.edgeA:IsMouseEnabled(), "HereBeDragons shows every pin again on every frame the player moves, so an edge pin fades with SetAlpha(0) and its mouse off; Hide would flip it shown and hidden every frame")

hbd.Draw(pins.edgeA, 0.4, 0.4)
assert(Seen(pins.edgeA) and pins.edgeA:GetAlpha() == 1, "a pin whose place comes onto the map shows again where HereBeDragons puts it")
hbd.Draw(pins.inside, 0, 5)
assert(not Seen(pins.inside), "and one whose place leaves the map hides once it rides the edge")
pins.inside:SetAlpha(0.6)
hbd.Draw(pins.inside, 0, 5)
assert(not Seen(pins.inside), "a pin its addon repaints while it rides the edge fades out again on the next frame")

local late = Pin(env, hbd, true)
hbd.Draw(late, -4, 0)
assert(not Seen(late), "a pin an addon adds after login is watched too")

K.Options.Write("Minimap", "drawer.edgePins", true)
M.Settle(env)
assert(Seen(pins.inside) and Seen(pins.edgeB) and Seen(late), "Addon pins on the map's edge brings the edge pins back")
hbd.Draw(pins.edgeB, 0, -6)
assert(Seen(pins.edgeB), "and keeps them while it is on")

-- The hooks other addons call every frame ------------------------------------------------------------------------

-- HereBeDragons places every active pin again on every frame the player moves, so the pin hook must do no work
-- while nothing is hidden: no library lookup, no setting read, no measuring.
local function Frame()
	for _, pin in pairs(pins) do
		hbd.Draw(pin, 0.3, 0.2)
	end
end
Frame()
Budget(Frame, 60, "Pins.Check must return at once while edge pins are kept: read state.hide, which Pins.Sync sets, before any other work")
K.Options.Write("Minimap", "drawer.edgePins", false)
M.Settle(env)
hbd.Draw(pins.edgeB, 0, -6)
assert(not Seen(pins.edgeB) and not Seen(late), "turning it off hides them again")

-- The drawer takes buttons, never pins ---------------------------------------------------------------------------

-- A pin HereBeDragons released stays a hidden child of the minimap for its addon's pool, and a gathering addon's
-- node is a named Button nobody can click. Collect runs on every drawer open and every ADDON_LOADED.
hbd:RemoveMinimapIcon("RXPGuides", pins.named)
local node = env.CreateFrame("Button", "SomeGatherNode1", env.Minimap)
node:SetSize(12, 12)
node:SetPoint("CENTER", env.Minimap, "CENTER", 10, 10)
drawer:Collect()
for _, frame in ipairs({ pins.named, node }) do
	assert(frame:GetParent() == env.Minimap, "the drawer took in " .. frame:GetName() .. ", a map pin HereBeDragons released or a Button with no click script; Pins.Is must stay true for any frame HereBeDragons ever held, and the drawer must skip a Button with no OnClick, OnMouseUp or OnMouseDown")
end
assert(drawer:Count() == 3, "the drawer still holds only the three addon buttons")
pins.named = nil

-- A button's addon showing it again, as LibDBIcon does on every refresh, must not lay the whole drawer out again.
local layouts, layout = 0, drawer.Layout
drawer.Layout = function(...)
	layouts = layouts + 1
	return layout(...)
end
unknown:Show()
layouts = 0
for _ = 1, 50 do
	unknown:Show()
end
assert(layouts == 0, "showing a button that is already shown laid the drawer out " .. layouts .. " times; lay out only when its shown state changes")
unknown:Hide()
unknown:Show()
assert(layouts == 2, "hiding a button and showing it again still lays the drawer out")
drawer.Layout = nil

K.Modules.Disable("Minimap")
M.Settle(env)
assert(Seen(pins.edgeB) and Seen(late) and Seen(pins.inside) and late:IsMouseEnabled(), "turning the minimap off gives every edge pin back to its addon")
NoErrors(env, K, "pins")

print("minimap pins ok")
