-- test-options-calm-motion.lua: with One motion style off, page cascades finish in 450 ms, search interrupts them, previews fade and a closing window reopens at its current alpha.
local O = dofile("Tools/regression/options_env.lua")
local env, K, ns = O.New()
local W = O.W
K.Options.Open("General")
W.Settle(env)
K.Store.Account().motionOneStyle = false
K.Options.Open("Profiles")
K.Options.Open("General")
local parts = ns.Window.Parts()
local list = parts.content
assert(list.rows[1]:GetAlpha() == 0, "changing a page starts its cascade")
W.Tick(env, 0.451)
for _, row in ipairs(list.rows) do
	assert(row:GetAlpha() == 1, "finish every visible row within 450 ms")
end
assert(K.Appearance.Get("calmLists") == true, "calmer settings lists default on")
K.Options.Open("Profiles")
K.Options.Open("General")
parts.search:SetText("font")
parts.search:GetScript("OnTextChanged")(parts.search, true)
for _, row in ipairs(list.rows) do
	assert(row:GetAlpha() == 1, "search cancels a running cascade and shows results at once")
end
parts.search:SetText("motion")
parts.search:GetScript("OnTextChanged")(parts.search, true)
for _, row in ipairs(list.rows) do
	assert(row:GetAlpha() == 1, "each search keystroke keeps results visible")
end
parts.search:SetText("")
parts.search:GetScript("OnTextChanged")(parts.search, true)
K.Store.Account().motionOneStyle = nil
W.Settle(env)
local win = ns.Window.Frame()
win:Close()
W.Tick(env, 0.07)
local alpha = win:GetAlpha()
assert(alpha > 0 and alpha < 1, "sample the closing panel halfway through its fade")
K.Options.Open("General")
assert(win:GetAlpha() == alpha and not win.closing, "reopening continues from the current alpha")
W.Tick(env, 0.3)
assert(win:IsShown() and win:GetAlpha() == 1, "the reopened window reaches full alpha")
K.Options.Open("About")
K.Options.Open("General")
local sample = parts.preview.current
assert(sample:GetAlpha() == 0, "a changed preview starts faded")
W.Tick(env, 0.1)
assert(sample:GetAlpha() > 0 and sample:GetAlpha() < 1, "a preview fades for 200 ms")
W.Tick(env, 0.101)
assert(sample:GetAlpha() == 1, "the preview fade finishes in 200 ms")
K.Options.Write("Appearance", "calmLists", false)
env.RunTimers()
W.Settle(env)
parts.search:SetText("font")
parts.search:GetScript("OnTextChanged")(parts.search, true)
assert(list.rows[1]:GetAlpha() == 0 and list.revealLimit == nil, "off restores the original search cascade")
W.Tick(env, 0.46)
assert(list.rows[#list.rows]:GetAlpha() < 1, "off restores the uncapped list stagger")
W.Settle(env)
win:Close()
K.Options.Open("General")
assert(win.closing, "off restores the previous handling of a closing window")
assert(#env._errors == 0, tostring(env._errors[1]))
for _, combat in ipairs({ false, true }) do
	local e, kit, options = O.New()
	kit.Motion.SetLevel(combat and "full" or "reduced")
	e.SetCombat(combat)
	kit.Options.Open("General")
	local frame = options.Window.Frame()
	assert(frame:IsShown() and not frame.rise:IsPlaying(), "combat and Calm suppress the panel rise")
	O.W.Tick(e, 0.05)
	if combat then
		assert(frame:GetAlpha() == 1 and not frame.fadeIn:IsPlaying(), "no panel fade runs in combat")
	else
		assert(frame:GetAlpha() > 0 and frame:GetAlpha() < 1, "Calm keeps the panel opening fade")
	end
	O.W.Tick(e, 0.101)
	assert(frame:GetAlpha() == 1, "Calm opens within 150 ms")
	frame:Close()
	assert(frame:IsShown() == not combat, "combat closes at once while Calm keeps the closing fade")
	O.W.Tick(e, 0.15)
	assert(not frame:IsShown(), "Calm closes within 150 ms")
end
print("options calm motion ok")
