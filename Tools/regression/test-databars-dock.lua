-- test-databars-dock.lua: the inline secure menu, queued dock transitions, slab caption anchors and the dock-only hub exemption.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local function near(a, b)
	assert(math.abs(a - b) < 0.01, tostring(a) .. " differs from " .. tostring(b))
end

local secure = { SetParent = true, ClearAllPoints = true, SetPoint = true, SetAllPoints = true, SetSize = true, SetWidth = true, SetHeight = true, SetAttribute = true, Show = true, Hide = true, SetShown = true }
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = D.Menus, game = { honor = 240, honorMax = 400, battlefield = true } })
	local view, Menus = ns.Strip.view, ns.Menus
	local micro, bags = Menus.Content("micro"), Menus.Content("bags")
	local function settle() env.RunTimers() W.Settle(env) end
	settle()
	assert(micro:GetParent() == view.frame and bags:GetParent() == Menus.Holder("bags"))
	assert(not Menus.Glass("micro"):IsShown() and not Menus.Holder("micro"):IsShown())
	assert(micro:GetAlpha() == 1, "the top menu is always visible")
	K.Options.Write("DataBars", "strip.enabled", false)
	settle()
	assert(micro:GetParent() == Menus.Holder("micro"), "turning off the bar restores the standalone menu")
	K.Options.Write("DataBars", "strip.enabled", true)
	settle()
	assert(micro:GetParent() == view.frame)
	for _, button in ipairs(Menus.Shown("micro")) do
		near(button:GetWidth(), K.Widgets.Snap(button, 15))
		near(button:GetHeight(), K.Widgets.Snap(button, 15))
		local target = button:GetAttribute("clickbutton")
		assert(target and env[target:GetName()] == target, "the secure proxy still targets Blizzard's button")
		if target ~= env.MainMenuMicroButton then assert(button:GetAttribute("type") == "click") end
	end
	local frames = { view.frame, micro, Menus.Holder("micro") }
	for _, button in ipairs(Menus.All("micro")) do frames[#frames + 1] = button end
	for _, frame in ipairs(frames) do rawset(frame, "IsProtected", function() return true, true end) end
	local function changeInCombat(placement, parent, key)
		local marks = {}
		for i, frame in ipairs(frames) do marks[i] = #frame._calls end
		env.SetCombat(true)
		K.Options.Write("DataBars", key or "strip.placement", placement)
		assert(micro:GetParent() == parent, "the dock stays put during combat")
		for i, frame in ipairs(frames) do
			for j = marks[i] + 1, #frame._calls do assert(not secure[frame._calls[j].method], "protected " .. frame._calls[j].method .. " in combat") end
		end
		env.SetCombat(false)
		settle()
	end
	changeInCombat("rail", view.frame)
	assert(micro:GetParent() == Menus.Holder("micro") and micro:GetAlpha() == 0)
	changeInCombat("top", Menus.Holder("micro"))
	assert(micro:GetParent() == view.frame and micro:GetAlpha() == 1)
	changeInCombat(false, view.frame, "strip.enabled")
	assert(micro:GetParent() == Menus.Holder("micro"))
	K.Options.Write("DataBars", "strip.enabled", true)
	settle()
	K.Options.Write("HudStyle", "style", "orbs")
	settle()
	assert(micro:GetParent() == view.frame)
	K.Options.Write("HudStyle", "style", "medallions")
	settle()
	local xp = ns.Bars.views.xp
	assert(view.slab == xp and not view.topBar and not view.chrome.visible)
	assert(micro:GetParent() == Menus.Holder("micro") and micro:GetAlpha() == 0)
	assert(bags:GetParent() == Menus.Holder("bags"))
	assert(select(2, view.frame:GetPoint()) == xp.holder)
	assert(select(2, view.zones.right:GetPoint()) == xp.text)
	assert(select(2, view.zones.left:GetPoint()) == select(2, view.zones.centre:GetPoint()))
	assert(select(2, view.items.time.button:GetPoint()) == view.zones.left and not view.items.time.dot:IsShown(), "the centre clock joins the left instrument line and clears the crest")
	near(view.frame:GetWidth(), xp.holder:GetWidth())
	local docked = K.Setup.Layouts.Positions("DPS", "medallions", K.Scale.Aspect())
	local dockBottom = {}
	for _, key in ipairs({ "databars.rep", "databars.honor" }) do dockBottom[key] = select(2, K.Layout.Rect(key)) end
	for _, item in pairs(view.items) do
		if item.button:IsShown() then
			assert(item.value:GetFont() == (K.Tokens.Font("caps")))
			local color = W.LastCall(item.value, "SetTextColor")
			local r, g, b = K.Tokens.Color("medTextMuted")
			near(color[1], r) near(color[2], g) near(color[3], b)
		end
	end
	changeInCombat("rail", Menus.Holder("micro"))
	assert(not view.slab and not view.topBar)
	local rail = K.Setup.Layouts.Positions("DPS", "medallions", K.Scale.Aspect())
	for _, key in ipairs({ "databars.rep", "databars.honor" }) do
		near(docked[key].y, rail[key].y - 15)
		local _, bottom = K.Layout.Rect(key)
		assert(math.abs(bottom - dockBottom[key] - 15) <= K.Scale.Pixel(1), "the edge clamp must preserve the dock's fifteen-unit caption band")
	end
	changeInCombat("dock", Menus.Holder("micro"))
	assert(view.slab == xp)
	K.Layout.Update("databars.xp", { shown = "never" })
	ns.Strip.Refresh()
	assert(view.slab == xp and view.frame:IsVisible(), "the dock remains when experience is disabled")
	K.Options.Write("DataBars", "strip.enabled", false)
	assert(not view.frame:IsShown() and micro:GetParent() == Menus.Holder("micro"))
	local off = K.Setup.Layouts.Positions("DPS", "medallions", K.Scale.Aspect())
	for _, key in ipairs({ "databars.rep", "databars.honor" }) do near(off[key].y, rail[key].y) end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K = D.New({ fit = true })
	local Layouts, Scale = K.Setup.Layouts, K.Scale
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		for _, arrangement in ipairs({ "centred", "spread" }) do
			K.Options.Write("Layout", "arrangement", arrangement)
			local width, height = Scale.CanvasWidth(screen[1], screen[2]), screen[2]
			for _, name in ipairs(Layouts.Names()) do
				local on = Layouts.Enabled(name)
				on["meters.damage"], on["meters.threat"] = name ~= "Tank", name == "Tank"
				local cap, fits = Layouts.ScaleLimit(width, height, name, on, "medallions")
				local scale = Scale.Auto(height, cap, fits)
				assert(fits(scale), name .. " dock must fit " .. screen[1] .. " " .. arrangement)
				local positions = Layouts.Positions(name, "medallions", Scale.AspectClass(width, height))
				assert(Layouts.Fits(name, width, height, scale, on, positions, "medallions"))
				local moved = positions["databars.strip"]
				moved.x, moved.y = 0, positions["actionbars.bar1"].y + 40
				assert(not Layouts.Fits(name, width, height, scale, on, positions, "medallions"), "a moved readout must not gain the dock's hub exemption")
			end
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("databars dock ok: secure inline menu, queued transitions, instrument lines and dock-only hub exemption at four sizes")
