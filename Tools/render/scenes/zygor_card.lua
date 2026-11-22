-- zygor_card.lua: the Zygor guide card and the Medallions quest card in one live Skins environment, from the Zygor test fake (its window, title bar, step line and controls; it draws no step rows of its own).
local Common = dofile("Tools/render/scenes/_common.lua")
local S = dofile("Tools/regression/skins_env.lua")
local Zygor = dofile("Tools/regression/zygor_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")

return Common.Run(function()
	local screen, zygor = Common.SCREEN, nil
	local env, K = S.New({
		width = screen.width, height = screen.height, uiScale = screen.uiScale,
		saved = { version = 12, profiles = { Default = { Minimap = { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(e)
			e._size, e._fitScale = screen.size or "auto", true
			e._textWidth = function(text, path, size) return Common.Scene.TextWidth(text, size, path) end
			Quests.Install(e, Quests.List(4))
			zygor = Zygor.Install(e, {})
		end,
		before = function(e) Quests.Tracker(e, S.Blizzard(e)) end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	zygor.Show()
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	local scene = Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(env, K)
	assert(not err, err)
	scene.log[#scene.log + 1] = "zygor: the Zygor fake's window in its guide card, the quest card on the story rail"
	return scene
end)
