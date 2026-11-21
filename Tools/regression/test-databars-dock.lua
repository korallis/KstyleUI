-- test-databars-dock.lua: the inline secure menu, queued dock transitions, slab caption anchors, the docked bar's forged plate and glyph segments, and the dock-only hub exemption.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W
local Scene = dofile("Tools/render/scene.lua")
local atlas = assert(io.open("Tools/media/make_databar_glyphs.py", "rb"))
local CELLS, cell = {}, 0
local source = atlas:read("*a")
atlas:close()
for name in source:match("NAMES = (%b[])"):gmatch('"(%w+)"') do CELLS[name], cell = cell, cell + 1 end
CELLS.prof1, CELLS.prof2 = CELLS.profession, CELLS.profession
local COLUMNS, ROWS = source:match("COLUMNS, ROWS = (%d+), (%d+)")
COLUMNS, ROWS = tonumber(COLUMNS), tonumber(ROWS)
local function hasCell(texture, id)
	local col, row, l, r, t, b = CELLS[id] % COLUMNS, math.floor(CELLS[id] / COLUMNS), texture:GetTexCoord()
	return texture:GetTexture() == "Interface\\AddOns\\KstyleUI_DataBars\\Media\\Glyphs.png" and l == col / COLUMNS and r == (col + 1) / COLUMNS and t == row / ROWS and b == (row + 1) / ROWS
end

local function near(a, b, what)
	assert(math.abs(a - b) < 0.01, (what or "dock geometry") .. ": " .. tostring(a) .. " differs from " .. tostring(b))
end

local secure = { SetParent = true, ClearAllPoints = true, SetPoint = true, SetAllPoints = true, SetSize = true, SetWidth = true, SetHeight = true, SetAttribute = true, Show = true, Hide = true, SetShown = true }
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = D.Menus, game = { honor = 240, honorMax = 400, battlefield = true } })
	local view, Menus = ns.Strip.view, ns.Menus
	local micro, bags = Menus.Content("micro"), Menus.Content("bags")
	local function settle() env.RunTimers() W.Settle(env) end
	local artwork = K.Options.Row("DataBars", "strip.artwork")
	assert(artwork.showWhen(ns.Settings()), "artwork is available on the top bar")
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
		near(button:GetWidth(), K.Widgets.Snap(button, math.min(15, view.frame:GetHeight())))
		near(button:GetHeight(), K.Widgets.Snap(button, math.min(15, view.frame:GetHeight())))
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
	changeInCombat(false, view.frame, "strip.menus")
	assert(micro:GetParent() == Menus.Holder("micro") and micro:GetAlpha() == 0, "menu docking off restores standalone hover")
	changeInCombat("rail", Menus.Holder("micro"))
	assert(micro:GetParent() == Menus.Holder("micro") and micro:GetAlpha() == 0)
	changeInCombat("top", Menus.Holder("micro"))
	assert(micro:GetParent() == Menus.Holder("micro") and micro:GetAlpha() == 0)
	changeInCombat(true, Menus.Holder("micro"), "strip.menus")
	assert(micro:GetParent() == view.frame and micro:GetAlpha() == 1)
	changeInCombat(false, view.frame, "strip.enabled")
	assert(micro:GetParent() == Menus.Holder("micro"))
	K.Options.Write("DataBars", "strip.enabled", true)
	settle()
	K.Options.Write("HudStyle", "style", "orbs")
	settle()
	assert(micro:GetParent() == view.frame)
	K.Options.Write("DataBars", "strip.menus", false)
	settle()
	assert(micro:GetParent() == Menus.Holder("micro") and micro:GetAlpha() == 0, "Orbs honours menu docking off")
	K.Options.Write("DataBars", "strip.menus", true)
	settle()
	assert(micro:GetParent() == view.frame)
	K.Options.Write("HudStyle", "style", "medallions")
	settle()
	local xp = ns.Bars.views.xp
	assert(artwork.showWhen(ns.Settings()), "artwork applies to the docked plate")
	assert(view.slab == xp and not view.topBar and view.chrome.visible and view.chrome.materialOn, "the dock wears the forged plate")
	assert(view.frame:GetFrameStrata() == xp.holder:GetFrameStrata() and view.card:GetFrameLevel() < xp.holder:GetFrameLevel(), "the plate sits under the XP caption and the hub")
	Scene.Build(env)
	local plateLeft, _, plateWidth = Scene.Rect(env, view.card)
	local wingLeft, _, wingWidth = Scene.Rect(env, view.wingCard)
	local frameLeft, _, frameWidth = Scene.Rect(env, view.frame)
	assert(view.wing.visible and plateLeft < frameLeft, "each slab wing has a plate; the left one reaches past the XP strip's left end")
	near(wingLeft + wingWidth - (frameLeft + frameWidth), frameLeft - plateLeft, "the right plate overhangs the strip's right end as far")
	assert(plateLeft + plateWidth < wingLeft, "the plates part under the crest hub")
	local zoneShown = {}
	for _, id in ipairs(view.order) do
		local item = view.items[id]
		if item.button:IsShown() then
			assert(item.icon:IsShown() and hasCell(item.icon, id), id .. " shows its own cell in the atlas order of Tools/media/make_databar_glyphs.py")
			assert(not item.dot:IsShown(), id .. ": segments replace the dots")
			local zone = select(2, item.button:GetPoint())
			assert(item.separator:IsShown() == (zoneShown[zone] == true), id .. ": a gilt rule divides each segment from the one before it")
			zoneShown[zone] = true
			assert(item.hover:IsShown() and item.hover:GetAlpha() == 0, id .. " rests without its highlight")
			item.button.hoverT = 1
			item.button.Paint()
			assert(item.hover:GetAlpha() > 0 and item.hover:GetAlpha() < 0.5, id .. " lights a faint highlight under the pointer: texture alpha is one value, so scale SetAlpha by the highlight's opacity")
			item.button.hoverT = 0
			item.button.Paint()
		end
	end
	assert(view.xpGlyph:IsShown() == xp.text:IsVisible() and view.xpRule:IsShown() == xp.text:IsVisible() and hasCell(view.xpGlyph, "xp"), "the XP caption is the last segment")
	K.Options.Write("DataBars", "strip.artwork", "plain")
	assert(view.chrome.visible and not view.chrome.materialOn, "plain artwork turns the docked plate to glass")
	K.Options.Write("DataBars", "strip.artwork", "forged")
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
	local function sameCaption()
		Scene.Build(env)
		for _, item in pairs(view.items) do
			if item.button:IsShown() then
				for _, text in ipairs({ item.value, item.label, item.dot }) do
					local face, size, flags = text:GetFont()
					local xpFace, xpSize, xpFlags = xp.text:GetFont()
					assert(face == xpFace and size == xpSize and flags == xpFlags, "dock text must share the XP caption font")
					if text:IsShown() then
						local _, y, _, h = Scene.Rect(env, text)
						local _, xpY, _, xpH = Scene.Rect(env, xp.text)
						near(y + h, xpY + xpH, "dock text must share the XP caption baseline")
					end
				end
			end
		end
	end
	sameCaption()
	K.Options.Write("DataBars", "xp.font", (K.Tokens.Font("prose")))
	sameCaption()
	K.Options.Write("DataBars", "xp.instrumentText", false)
	sameCaption()
	K.Options.Write("DataBars", "xp.fontSize", 15)
	sameCaption()
	K.Options.Write("DataBars", "xp.font", "default")
	K.Options.Write("DataBars", "xp.instrumentText", true)
	K.Options.Write("DataBars", "strip.menus", false)
	changeInCombat("rail", Menus.Holder("micro"))
	assert(not artwork.showWhen(ns.Settings()), "the rail has no plate to dress")
	assert(not view.slab and not view.topBar and not view.wing.visible and not view.items.fps.icon:IsShown() and not view.items.fps.hover:IsShown())
	local rail = K.Setup.Layouts.Positions("DPS", "medallions", K.Scale.Aspect())
	for _, key in ipairs({ "databars.rep", "databars.honor" }) do
		near(docked[key].y, rail[key].y - 15)
		local _, bottom = K.Layout.Rect(key)
		assert(math.abs(bottom - dockBottom[key] - 15) <= K.Scale.Pixel(1), "the edge clamp must preserve the dock's fifteen-unit caption band")
	end
	changeInCombat("dock", Menus.Holder("micro"))
	assert(artwork.showWhen(ns.Settings()), "explicit dock offers the artwork too")
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
