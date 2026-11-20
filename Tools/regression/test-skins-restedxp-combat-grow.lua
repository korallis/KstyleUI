-- test-skins-restedxp-combat-grow.lua: in Orbs, where the quest card stands on the guide's card, on every screen the crew checks, a current step that grows from one line to five in combat keeps the guide's card top where the rail hung it and grows down: every line shows with its tick box taking the mouse, later steps rest under the "more" line, and no tick box sits over the quest card.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Cross(a, b)
	return math.min(a.top, b.top) > math.max(a.bottom, b.bottom) and math.min(a.right, b.right) > math.max(a.left, b.left)
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local rxp
	local env, K, ns = S.New({
		width = screen[1], height = screen[2],
		saved = { version = 42, profiles = { Default = { HudStyle = { style = "orbs" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(e)
			e._size, e._fitScale, e._resolveRects = "auto", true, true
			Quests.Install(e, Quests.List(9))
			rxp = Fake.Install(e, {})
		end,
		before = function(e) Quests.Tracker(e, S.Blizzard(e)) end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.fake.open(rxp.RXPFrame)
	rxp.SetStep(1, 1)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	local function Rect(region) return Geometry.ScaledRect(region, env.UIParent, K.Scale.Root()) end
	local size = screen[1] .. "x" .. screen[2]
	local glass, quest = K.Skin.Parts(rxp.RXPFrame).backdrop, Rect(ns.Quests.Parts().glass)
	local top = Rect(glass).top
	assert(ns.Quests.Card():IsShown() and not Cross(Rect(glass), quest), size .. ": the quest card stands clear of the guide out of combat")
	env.SetCombat(true)
	for _, count in ipairs({ 1, 3 }) do
		rxp.SetStep(count, 5)
		env.RunTimers()
		local pool = rxp.RXPFrame.CurrentStepFrame.framePool
		local tag = size .. ", " .. count .. " steps in combat: "
		assert(math.abs(Rect(glass).top - top) < 0.01, tag .. "the card keeps its top, got " .. Rect(glass).top .. " for " .. top)
		for e, row in ipairs(pool[1].elements) do
			assert(row:GetAlpha() > 0 and row.button:IsMouseEnabled(), tag .. "line " .. e .. " shows with its tick box taking the mouse")
			assert(not Cross(Rect(row.button), quest), tag .. "line " .. e .. "'s tick box sits over the quest card")
		end
		for i = 2, count do
			assert(pool[i]:GetAlpha() == 0 and not pool[i].elements[1].button:IsMouseEnabled(), tag .. "step " .. i .. " rests under the more line")
		end
		assert(ns.RestedXP.Rail.Hidden() == count - 1, tag .. "the more line counts the later steps")
	end
end

print("skins restedxp combat grow ok")
