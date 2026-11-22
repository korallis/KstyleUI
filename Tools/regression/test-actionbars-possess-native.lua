-- test-actionbars-possess-native.lua: keep native possession clicks, skin and move the frame, and defer movement in combat.
local AB = dofile("Tools/regression/actionbars_env.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K = AB.New({ width = screen[1], height = screen[2] })
	AB.Enable(env, K)
	local frame = env.PossessActionBar
	assert(K.Layout.Element("actionbars.possess").frame == frame, "move the native frame, retaining native buttons and cancellation")
	assert(not frame:IsShown(), "native possess visibility stays native")
	assert(not K.Setup.Layouts.Enabled("DPS", K.Store.Profile())["actionbars.possess"], "the hidden native bar does not reserve space")
	frame:Show()
	assert(K.Setup.Layouts.Enabled("DPS", K.Store.Profile())["actionbars.possess"], "possession visibility enables its setup footprint")
	frame:Hide()
	for _, style in ipairs({ "medallions" }) do
		local width, height = K.Setup.Layouts.Footprint("DPS", "actionbars.possess", style)
		assert(math.abs(width - frame:GetWidth()) <= K.Scale.Pixel(1) and math.abs(height - frame:GetHeight()) <= K.Scale.Pixel(1), "native possess has a setup footprint in " .. style)
		assert(K.Setup.Layouts.Positions("DPS", style, K.Scale.Aspect())["actionbars.possess"], "native possess participates in setup positions")
	end
	for _, button in ipairs(frame.actionButtons) do
		assert(K.Skin.Parts(button).backdrop.chrome, "native possess uses the shared icon chrome")
	end
	env.SetCombat(true)
	K.Layout.Update("actionbars.possess", { x = 140, y = 180 })
	assert(#env._blocked == 0, "native possess movement waits for combat")
	env.SetCombat(false)
	assert(K.Layout.Get("actionbars.possess").x == 140 and K.Layout.Get("actionbars.possess").y == 180)
	env._game.possess = true
	frame.actionButtons[2]:Click()
	assert(not env._game.possess and AB.Used(env) == "cancelpossess", "the native cancel-possession click survives")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
print("ok native possess skin and mover")
