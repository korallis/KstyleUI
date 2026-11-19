-- test-skins-trainer-layout.lua: the warlock trainer holds wrapped requirements and reserves a separate footer.
local Windows = dofile("Tools/regression/skins_windows.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local S = Windows.S

local function Boot(off)
	local env, K, ns = S.New({
		saved = { version = 12, profiles = { Default = { Skins = { trainer = { enabled = not off }, text = { size = 1.2 } } } },
			characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = Common.ForceScreen,
		before = function(e) Windows.Build("trainer", e, S.Blizzard(e)) end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_TrainerUI")
	S.Show(env.ClassTrainerFrame)
	env.RunTimers()
	S.W.Settle(env)
	return env, K, ns
end

local env, K, ns = Boot()
local frame = env.ClassTrainerFrame
local function Check()
	frame.ScrollBox:FullUpdate()
	local wrapped = 0
	frame.ScrollBox:ForEachFrame(function(row)
		local text = row.subText
		local height = assert(text:GetStringHeight())
		assert(text:GetTop() - height >= row:GetBottom() + 1,
			"trainer requirements spill below the row: size the row for two lines and place subText below the name")
		assert(text:GetTop() <= row.name:GetBottom() + 0.01, "trainer requirements must clear the skill name")
		if text:GetNumLines() == 2 then wrapped = wrapped + 1 end
	end)
	assert(wrapped >= 3, "exercise the screenshot's long Demon Skin, Curse of Weakness and Shadow Bolt requirements")
	assert(frame.ScrollBox:GetBottom() > frame.TrainButton:GetTop(), "trainer list must stop above the Train button")
	assert(frame.ScrollBox:GetBottom() > frame.money:GetTop(), "trainer list must stop above the money line")
	assert(frame.money:GetRight() < frame.TrainButton:GetLeft(), "money and Train button must have separate footer space")
	assert(frame.TrainButton:GetBottom() >= frame:GetBottom() + 6, "Train button must stay inside the window")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
assert(ns.Skins.IsApplied("trainer"))
assert(frame.ScrollBox:GetView().calculator(1, { GetData = function() return { categoryInfo = {} } end }) == 25,
	"trainer category rows retain their native extent")
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
print("skins trainer layout ok")
