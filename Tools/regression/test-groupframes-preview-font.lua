-- test-groupframes-preview-font.lua: opening and measuring Options safely refits group samples after their size resolves (#444).
local G = dofile("Tools/regression/group_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

local env, K, group = G.New({
	setup = function(e)
		e.C_AddOns = { LoadAddOn = function(name)
			if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
			return true
		end }
	end,
})
assert(K.Options.Open("GroupFrames"))
env.RunTimers()
O.W.Settle(env)
local pane = env._addons.KstyleUI_Options.Window.Parts().preview
local preview = pane.current
assert(preview and preview.partyFrames, "open the real group preview")
local width, height = pane.holder:GetSize()
local owner = env._addons.KstyleUI_Options.Window.Frame()
local left = owner.GetLeft
local measured, measuring, reentrant, applied = false, false, 0, 0
local apply = group.Style.Apply
group.Style.Apply = function(...)
	applied = applied + 1
	if measuring then reentrant = reentrant + 1 end
	return apply(...)
end
owner.GetLeft = function(self)
	if not measured then
		measured = true
		measuring = true
		pane.holder:SetSize(280, 100)
		measuring = false
	end
	return left(self)
end
K.Widgets.CardHeader(pane.caption.gem)
assert(measured, "edge measurement resolves the preview's pending resize")
assert(reentrant == 0, "defer group preview styling out of GetLeft/header measurement")
owner.GetLeft = left
env.RunTimers()
assert(applied > 0, "refit the samples after the small pane resolves")
assert(not preview.clickCast:IsShown(), "leave room for samples when the click casting panel cannot fit")
local resized = applied
pane.holder:SetSize(width, height)
env.RunTimers()
assert(applied > resized, "the next resolved resize styles the samples again")
assert(preview.clickCast:IsShown(), "restore click casting when the pane has room")
local before = applied
local getWidth, getHeight = preview.GetWidth, preview.GetHeight
for _, invalid in ipairs({ 0, -1, 0 / 0, math.huge, -math.huge, env.Secret(280) }) do
	preview.GetWidth = function() return invalid end
	preview:Refresh()
	preview.GetWidth = getWidth
	preview.GetHeight = function() return invalid end
	preview:Refresh()
	preview.GetHeight = getHeight
end
preview.GetWidth = function() return nil end
preview:Refresh()
preview.GetWidth = getWidth
assert(applied == before, "ignore unresolved, non-finite and secret dimensions before sizing or styling")
preview:Refresh()
assert(preview.partyFrames[1].name:GetText() == "Thaldren", "the preview recovers at its resolved size")
assert(#env._errors == 0, table.concat(env._errors, "\n"))

print("groupframes preview font ok")
