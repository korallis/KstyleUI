-- questcard_guide_env.lua: the Medallions quest card and RestedXP guide in one live Skins environment.
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local RestedXP = dofile("Tools/regression/restedxp_fake.lua")
local Scene = dofile("Tools/render/scene.lua")

return function(screen, item, previous, nativeRects, questie)
	local rxp, log, other
	local quests = Quests.List(8, 1)
	quests[1].title = "A Putrid Task"
	quests[1].objectives = { { text = "Putrid Claw: 0/7", finished = false } }
	if item then quests[1].item = { link = "item:5179", icon = 134339 } end
	local env, K, ns = S.New({
		width = screen.width, height = screen.height, uiScale = screen.uiScale,
		saved = {
			version = 12, profiles = { Default = { HudStyle = { style = "medallions" }, Skins = previous and { quests = { continuation = false }, restedXP = { compose = false }, steelButtons = false, windowMetrics = false } or nil } },
			characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
		},
		setup = function(e)
			if nativeRects then e._resolveRects = true end
			e._size, e._fitScale = screen.size or "auto", true
			e.UnitClass = function() return "Warlock", "WARLOCK", 9 end
			log = Quests.Install(e, quests)
			rxp = RestedXP.Install(e, {})
			rxp.currentGuide = { name = "1-6 Tirisfal Glades", subgroup = "Horde Undead" }
			e._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
			if questie then other = questie(e, log) end
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.RXPFrame.GuideName.text:SetText("1-6 Tirisfal Glades\nHorde Undead")
	rxp.fake.guide({ { index = 11, elements = {
		{ text = "Talk to Joshua", textOnly = true },
		{ text = "Buy Refreshing Spring Water from him", textOnly = true },
		{ text = "Refreshing Spring Water: 0/5" },
	} } })
	rxp.SetStep()
	rxp.targeting:UpdateTargetFrame(1, 0)
	rxp.UpdateItemFrame(nil, 1)
	local function Settle()
		env.RunTimers()
		S.W.Settle(env)
		env.RunTimers()
	end
	Settle()
	return { env = env, K = K, ns = ns, rxp = rxp, log = log, quests = quests, settle = Settle, questie = other }
end
