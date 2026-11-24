-- test-options-calm-motion.lua: with One motion style off, page cascades finish in 450 ms, search interrupts them, and the window and its previews show and hide at once.
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
assert(not win:IsShown(), "the window closes at once")
K.Options.Open("General")
assert(win:IsShown() and win:GetAlpha() == 1, "and reopens whole at once")
K.Options.Open("About")
K.Options.Open("General")
local sample = parts.preview.current
assert(sample:IsShown() and sample:GetAlpha() == 1, "a changed preview shows whole at once, with no fade")
K.Options.Write("Appearance", "calmLists", false)
env.RunTimers()
W.Settle(env)
parts.search:SetText("font")
parts.search:GetScript("OnTextChanged")(parts.search, true)
assert(list.rows[1]:GetAlpha() == 0 and list.revealLimit == nil, "off restores the original search cascade")
W.Tick(env, 0.46)
assert(list.rows[#list.rows]:GetAlpha() < 1, "off restores the uncapped list stagger")
assert(#env._errors == 0, tostring(env._errors[1]))
for _, combat in ipairs({ false, true }) do
	local e, kit, options = O.New()
	kit.Motion.SetLevel(combat and "full" or "reduced")
	e.SetCombat(combat)
	kit.Options.Open("General")
	local frame = options.Window.Frame()
	assert(frame:IsShown() and frame:GetAlpha() == 1 and not frame.rise:IsPlaying(), "combat and Calm open the window whole with no rise")
	frame:Close()
	assert(not frame:IsShown(), "and close it at once")
end
print("options calm motion ok")
