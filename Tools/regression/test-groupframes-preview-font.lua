-- test-groupframes-preview-font.lua: opening and measuring Options never styles group samples at an unresolved or collapsed size (#444).
local G = dofile("Tools/regression/group_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

for _, style in ipairs({ "Medallions", "Frames", "Orbs" }) do
	local env, K, group = G.New({
		setup = function(e)
			e.C_AddOns = { LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
				return true
			end }
		end,
	})
	K.Options.Write("HudStyle", "style", style:lower())
	assert(K.Options.Open("GroupFrames"))
	env.RunTimers()
	O.W.Settle(env)
	local pane = env._addons.KstyleUI_Options.Window.Parts().preview
	local preview = pane.current
	assert(preview and preview.partyFrames, "open the real group preview")
	local width, height = pane.holder:GetSize()
	local owner = env._addons.KstyleUI_Options.Window.Frame()
	local left = owner.GetLeft
	local measured, measuring, reentrant = false, false, 0
	local apply = group.Style.Apply
	group.Style.Apply = function(...)
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
	if style == "Medallions" then
		K.Widgets.CardHeader(pane.caption.gem)
	else
		owner:GetLeft()
	end
	assert(measured, "edge measurement resolves the preview's pending resize")
	assert(reentrant == 0, "defer group preview styling out of GetLeft/header measurement")
	owner.GetLeft = left
	env.RunTimers()
	pane.holder:SetSize(width, height)
	env.RunTimers()
	preview:Refresh()
	assert(preview.partyFrames[1].name:GetText() == "Thaldren", "the preview recovers at its resolved size")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

print("groupframes preview font ok")
