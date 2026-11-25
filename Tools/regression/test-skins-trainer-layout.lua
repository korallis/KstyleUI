-- test-skins-trainer-layout.lua: the warlock trainer keeps Blizzard's row heights, holds wrapped requirements inside them and reserves a separate footer.
-- Intent: buying from a trainer must not raise ADDON_ACTION_FORBIDDEN. Blizzard's secure list code calls the list's
-- row-height function and keeps what it returns, so an addon function there taints the selection the Train click reads.
local Windows = dofile("Tools/regression/skins_windows.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local S = Windows.S

local function Boot(off, metrics, profession)
	local env, K, ns = S.New({
		saved = { version = 12, profiles = { Default = { Skins = { trainer = { enabled = not off }, windowMetrics = metrics, text = { size = 1.2 } } } },
			characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = Common.ForceScreen,
		before = function(e)
			local frame = Windows.Build("trainer", e, S.Blizzard(e))
			if profession then
				frame.skillStepButton:Show()
				e.ClassTrainerFrame_Update()
			end
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_TrainerUI")
	S.Show(env.ClassTrainerFrame)
	env.RunTimers()
	S.W.Settle(env)
	return env, K, ns
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 3456, 2234 } }) do
	Common.SCREEN = { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" }
	local env, K, ns = Boot()
	local frame = env.ClassTrainerFrame
	local function Contains(row)
		local text = row.subText
		local height = assert(text:GetStringHeight())
		assert(text:GetTop() - height >= row:GetBottom() + 1,
			"trainer requirements spill below the row: size the text so the name and two lines fit the row's own height")
		assert(text:GetTop() <= row.name:GetBottom() + 0.01, "trainer requirements must clear the skill name")
	end
	local function Check()
		frame.ScrollBox:FullUpdate()
		assert(frame.ScrollBox:GetView().calculator == nil,
			"the trainer skin must leave the list's row-height function alone: replacing it taints the Train click")
		local wrapped = 0
		frame.ScrollBox:ForEachFrame(function(row)
			assert(row:GetHeight() == 47, "trainer skill rows keep Blizzard's row height")
			Contains(row)
			if row.subText:GetNumLines() == 2 then wrapped = wrapped + 1 end
		end)
		assert(wrapped >= 1, "exercise the long Curse of Weakness requirement, which needs two lines")
		assert(frame.ScrollBox:GetBottom() > frame.TrainButton:GetTop(), "trainer list must stop above the Train button")
		assert(frame.ScrollBox:GetBottom() > frame.money:GetTop(), "trainer list must stop above the money line")
		assert(frame.money:GetRight() < frame.TrainButton:GetLeft(), "money and Train button must have separate footer space")
		assert(frame.TrainButton:GetBottom() >= frame:GetBottom() + 6, "Train button must stay inside the window")
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
	assert(ns.Skins.IsApplied("trainer"))
	Check()
	for _ = 1, 3 do
		env.ClassTrainerFrame_Update()
		S.Show(frame)
		env.RunTimers()
		S.W.Settle(env)
		Check()
	end
	env.SetCombat(true)
	env.ClassTrainerFrame_Update()
	assert(frame.ScrollBox:GetNumPoints() == 1, "trainer layout changes must wait for combat to end")
	env.SetCombat(false)
	Check()
	K.Options.Write("Skins", "text.size", 1.4)
	env.RunTimers()
	S.W.Settle(env)
	Check()
	local old = Boot(true)
	assert(old.ClassTrainerFrame.ScrollBox:GetHeight() == 330, "trainer skin off retains Blizzard's scroll height")
	assert(old.ClassTrainerFrame.ScrollBox._rows[1]:GetHeight() == 47, "trainer skin off retains Blizzard's row height")
	local legacy = Boot(false, false, true).ClassTrainerFrame
	legacy.ScrollBox:FullUpdate()
	assert(legacy.ScrollBox:GetHeight() == 278 and legacy.ScrollBox._rows[1]:GetHeight() == 47,
		"Consistent window spacing off must retain native trainer list and row sizes")
	assert(legacy.skillStepButton:GetHeight() == 40, "spacing off must retain the native profession upgrade row")
	assert(select(5, legacy.money:GetPoint(1)) == 0, "spacing off must retain the native money anchor")
	local profession, professionK = Boot(false, true, true)
	local upgrade = profession.ClassTrainerFrame.skillStepButton
	for _, size in ipairs({ 1.2, 1.4 }) do
		professionK.Options.Write("Skins", "text.size", size)
		profession.ClassTrainerFrame_Update()
		profession.RunTimers()
		S.W.Settle(profession)
		Contains(upgrade)
		assert(profession.ClassTrainerFrame.ScrollBox:GetTop() < upgrade:GetBottom(),
			"the trainer list must clear the fitted profession upgrade row")
	end
	print("trainer layout " .. screen[1] .. "x" .. screen[2] .. " ok")
end
print("skins trainer layout ok")
