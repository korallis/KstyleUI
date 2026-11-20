-- test-medallions-story-tops.lua: sibling story cards align below the minimap plaque at the standard gap, with saved positions left alone.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local M = dofile("Tools/regression/minimap_env.lua")

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	for _, frame in ipairs({ "medallion", "ring", "classic" }) do
		local R = Boot({ width = screen[1], height = screen[2], frame = frame }, nil, nil, true)
		local env, K, ns = R.env, R.K, R.ns
		M.Blizzard(env, {})
		dofile("Tools/regression/load_files.lua")(M.Files(), env)
		K.Modules.Enable("Minimap")
		M.Settle(env)
		R.settle()
		local function Rect(f) return assert(G.ScaledRect(f, env.UIParent, K.Scale.Root())) end
		local quest = Rect(ns.QuestCard.Frame())
		local guide = Rect(K.Skin.Parts(R.rxp.RXPFrame).backdrop)
		local plaque = Rect(env._addons.KstyleUI_Minimap.Map.face.plaques[2])
		local pixel, gap = K.Scale.Pixel(1) + 0.01, K.Setup.Layouts.STORY_GAP
		local label = frame .. " " .. screen[1] .. "x" .. screen[2]
		assert(math.abs(quest.top - guide.top) <= pixel, label .. ": top-align the sibling story cards")
		for _, card in ipairs({ quest, guide }) do
			local clearance = plaque.bottom - card.top
			assert(clearance >= gap - 2 * pixel and clearance <= gap + 4,
				label .. ": leave the standard sixteen-unit gap below the coordinates plaque, got " .. clearance)
		end
		R.rxp.RXPFrame:Hide()
		env._loaded.RXPGuides = nil
		K.Callbacks.Fire("SettingChanged", "Skins", "restedXP.rail")
		R.settle()
		assert(math.abs(Rect(ns.QuestCard.Frame()).top - quest.top) <= pixel,
			label .. ": keep the same quest top without RestedXP")
		for _, key in ipairs({ "skins.quests", "skins.guide" }) do
			assert(K.Layout.Update(key, { anchor = "TOPRIGHT", x = -900, y = -400 }, true))
		end
		K.Options.Write("Minimap", "frame", frame == "classic" and "ring" or "classic")
		M.Settle(env)
		R.settle()
		for _, key in ipairs({ "skins.quests", "skins.guide" }) do
			local saved, placed = K.Store.Layout()[key], K.Layout.Get(key)
			assert(saved.x == -900 and saved.y == -400 and placed.x == -900 and placed.y == -400,
				label .. ": change story defaults only; preserve saved " .. key)
		end
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
end
print("Medallions story tops ok: 24 frame/screen/guide cases and saved positions")
