-- test-setup-scroll-rect.lua: the setup's Welcome, Modules and Your addons lists draw every row on first open, before any tick or scroll, at every owner screen; the client draws a scroll child only within the rect its scroll frame last took.
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local Suite = dofile("Tools/regression/suite_env.lua")
local Fake = dofile("Tools/regression/addons_fake.lua")

local env = Stubs.NewEnv()
local scroll = env.CreateFrame("ScrollFrame", nil, env.UIParent)
local child = env.CreateFrame("Frame", nil, scroll)
child:SetSize(100, 1)
scroll:SetScrollChild(child)
child:SetHeight(300)
assert(env.Undrawn(scroll) == 299, "a child grown after SetScrollChild stays undrawn past its old rect")
scroll:SetVerticalScroll(0)
assert(env.Undrawn(scroll) == 299, "a scroll that does not move keeps the old rect")
scroll:UpdateScrollChildRect()
assert(env.Undrawn(scroll) == 0, "UpdateScrollChildRect takes the new rect")
child:SetHeight(400)
scroll:SetVerticalScroll(10)
assert(env.Undrawn(scroll) == 0, "and so does a scroll that moves")
scroll:SetVerticalScroll(env.Secret(5))
scroll:SetVerticalScroll(env.Secret(6))
env.SetQuiet(true)
assert(dofile("Tools/regression/measure.lua").Run(function() scroll:SetScrollChild(child) end).kb == 0, "a repeated quiet SetScrollChild allocates nothing")
env.SetQuiet(false)

for _, locale in ipairs({ "enUS", "deDE" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local label = locale .. " " .. screen[1] .. "x" .. screen[2]
		local game, K = Suite.New({ version = 42, profiles = { Default = {} }, characters = {}, account = { setupSeen = true } }, screen[1], screen[2], function(e)
			Fake.Install(e)
			e.GetLocale = function() return locale end
		end)
		assert(K.Setup.Open(true))
		local panel = K.Setup.window
		for _, page in ipairs({ { 1, panel.pages[1].scroll }, { 4, panel.moduleScroll }, { 5, panel.addons.scroll } }) do
			local step, list = page[1], page[2]
			assert(K.Setup.Go(step))
			assert(game.Undrawn(list) == 0, label .. " step " .. step .. ": " .. game.Undrawn(list) .. " units of the list stay undrawn until a scroll; call UpdateScrollChildRect after resizing a scroll child")
		end
		assert(#game._errors == 0, label .. ": " .. tostring(game._errors[1]))
	end
end
print("setup scroll rect ok")
