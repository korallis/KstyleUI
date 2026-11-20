-- test-skins-followups.lua: deterministic restyles, shrinking story cards, shared addon headings and a respectful Questie first choice.
local S = dofile("Tools/regression/skins_env.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")
local failures = {}
local function Check(name, fn)
	local ok, err = pcall(fn)
	if not ok then failures[#failures + 1] = name .. ": " .. tostring(err); print(failures[#failures]) end
end

Check("restyle order", function()
	local _, _, ns = S.New()
	local objects, nextIndex = {}, 1
	for i = 1, 32 do
		objects[i] = { Restyle = function() assert(nextIndex == i, "Restyle skin objects in registration order so SectionCap always precedes Path"); nextIndex = nextIndex + 1 end }
		ns.Style.Track(objects[i])
		ns.Style.Track(objects[i])
	end
	ns.Style.RestyleAll()
	assert(nextIndex == 33, "Restyle each tracked skin object once in registration order")
end)

for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 2560, height = 1440 }, { width = 5120, height = 1440 }, { width = 3840, height = 2160 } }) do
	Check("shrink " .. screen.width, function()
		local R = Boot({ width = screen.width, height = screen.height, uiScale = 768 / 1080 }, nil, nil, true)
		local path = R.ns.RestedXP.Chrome.Path(R.rxp.RXPFrame)
		local capHeight = path.cap:GetHeight()
		for _ = 1, 3 do
			R.ns.Style.RestyleAll()
			assert(path.cap:GetHeight() == capHeight, "Keep the RestedXP cap height deterministic after every restyle")
		end
		local before = path.card:GetHeight()
		for i = #R.quests, 2, -1 do R.log.Untrack(R.quests[i].id) end
		R.rxp.fake.guide({ { index = 12, elements = { { text = "Talk to Joshua", textOnly = true } } } })
		R.rxp.SetStep(1)
		R.settle()
		assert(path.card:GetHeight() < before, "Compute guide height from its current steps")
		R.K.Options.Write("Skins", "restedXP.compose", false)
		R.settle()
		local natural = R.ns.Quests.Card():GetHeight()
		R.ns.QuestCard.Resize(natural + 100)
		R.ns.QuestCard.Render()
		assert(R.ns.Quests.Card():GetHeight() == natural, "Keep the quest card's natural height separate from its aligned height")
	end)
	Check("base quest card " .. screen.width, function()
		local R = Boot(screen, nil, nil, true)
		R.K.Options.Write("Skins", "restedXP.compose", false)
		R.settle()
		local before = R.ns.Quests.Card():GetHeight()
		for i = #R.quests, 2, -1 do R.log.Untrack(R.quests[i].id) end
		R.settle()
		assert(R.ns.Quests.Card():GetHeight() < before, "Shrink the base quest card when tracked content shrinks")
	end)
	Check("Questie first choice " .. screen.width, function()
		local R = Boot(screen, nil, nil, true, Questie.Install)
		assert(R.questie.calls == 0 and R.env.Questie.db.profile.trackerEnabled, "Seed the first tracker choice from Questie's current state; never switch it off automatically")
		assert(R.K.Store.Module("Integrations").questTracker == "questie", "Remember the first detected Questie tracker choice")
		local parts = R.K.Skin.Parts(R.questie.frame)
		assert(parts and parts.backdrop and parts.backdrop:IsShown(), "Card Questie's own tracker frame with the shared KstyleUI window skin")
		local point = { R.questie.frame:GetPoint(1) }
		R.questie:Update()
		R.settle()
		for i, value in ipairs(point) do assert(select(i, R.questie.frame:GetPoint(1)) == value, "Skin Questie without moving its saved position") end
		R.K.Options.Write("Skins", "questie.enabled", false)
		R.settle()
		assert(not parts.backdrop:IsShown(), "Make Questie's card toggleable without disabling its tracker")
	end)
	Check("Questie card " .. screen.width, function()
		local R = Boot(screen, nil, nil, true, function(env, log)
			env.KstyleUI.Store.Module("Integrations").questTracker = "questie"
			return Questie.Install(env, log)
		end)
		local parts = R.K.Skin.Parts(R.questie.frame)
		assert(parts and parts.backdrop, "Card Questie's own tracker using the shared window builder")
		local header = R.env.Questie_HeaderFrame
		assert(header.trackedQuests.label:GetAlpha() == 0, "Replace Questie's native header with the shared SectionCap")
		assert(header.questieIcon.texture:GetAlpha() == 0, "Hide Questie's native icon art under the shared header while keeping its button")
		local cap
		for _, child in ipairs({ header:GetChildren() }) do if child.label and child.gem and child.rule then cap = child end end
		assert(cap and cap:IsShown(), "Use the shared SectionCap for Questie's own header")
		assert(cap.count:GetText() == "8/40", "Place Questie's tracker count in the shared header's number column")
	end)
end

Check("existing tracker choices", function()
	for _, choice in ipairs({ "kstyleui", "questie" }) do
		local R = Boot({ width = 1920, height = 1080 }, nil, nil, true, function(env, log)
			env.KstyleUI.Store.Module("Integrations").questTracker = choice
			return Questie.Install(env, log)
		end)
		assert(R.K.Store.Module("Integrations").questTracker == choice, "Keep an existing explicit tracker choice on first Questie detection")
		assert(R.env.Questie.db.profile.trackerEnabled == (choice == "questie"), "Apply only the player's explicit tracker choice")
	end
end)

for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 2560, height = 1440 }, { width = 5120, height = 1440 }, { width = 3840, height = 2160 } }) do
Check("shared menu heading " .. screen.width, function()
	local E = dofile("Tools/regression/native_menu_env.lua")
	local env, _, _, nm = E.New({ material = "Slate", setup = function(e)
		e.GetPhysicalScreenSize = function() return screen.width, screen.height end
		e.UIParent:SetSize(768 * screen.width / screen.height, 768)
	end })
	local menu = E.Quest(env, nm)
	local row = menu.rows[1]
	local cap
	for _, child in ipairs({ row:GetChildren() }) do if child.label and child.gem and child.rule then cap = child end end
	assert(cap and cap:IsVisible(), "Use the shared SectionCap for native menu headers")
	nm.Reinitialize(menu)
	assert(cap:IsVisible(), "Keep the shared menu heading after native menu refresh")
	local text = row.fontString
	nm.Close(menu)
	assert(not cap:IsShown() and text:GetAlpha() == 1, "Release shared menu headers before pooled native rows are reused")
end)

Check("shared v2 heading " .. screen.width, function()
	local Fake = dofile("Tools/regression/restedxp_fake.lua")
	local rxp
	local env, K, ns = S.New({ width = screen.width, height = screen.height, setup = function(e) rxp = Fake.Install(e, { v2 = true }) end })
	K.Modules.Enable("Skins")
	env.RunTimers()
	local title = rxp.v2.state.guideWindow.title
	assert(ns.Parts.HeadingOf(ns.RestedXP.Chrome.Caption(title)), "Use the shared window heading for RestedXP's Speedrun Guide header")
end)

end

assert(#failures == 0, table.concat(failures, "\n"))
print("test-skins-followups: ok")
