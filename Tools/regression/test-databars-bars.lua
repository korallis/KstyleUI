-- test-databars-bars.lua: KstyleUI_DataBars' experience, reputation and honour bars against the stub game: lifecycle, Layout, values, text, settings, preview and Blizzard's faded bars.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local KEYS = { xp = "databars.xp", rep = "databars.rep", honor = "databars.honor" }

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function eq(got, want, what)
	assert(got == want, string.format("%s: expected %s, got %s", what, tostring(want), tostring(got)))
end

local function element(K, key)
	for _, el in ipairs(K.Layout.Elements()) do
		if el.key == key then
			return el
		end
	end
end

local function sameColor(bar, r, g, b)
	local cr, cg, cb = bar:GetStatusBarColor()
	return near(cr, r) and near(cg, g) and near(cb, b)
end

local function view(ns, id)
	return assert(ns.Bars.views[id], "the " .. id .. " bar was built")
end

local function noErrors(env, K)
	assert(#env._errors == 0, "errors were raised: " .. tostring(env._errors[1]))
	eq(K.ErrorCount(), 0, "errors caught by KstyleUI.Call")
end

-- Off by default: nothing is built, registered or faded --------------------------------------------

do
	local env, K, ns = D.New({ enable = false })
	eq(K.Modules.IsEnabled("DataBars"), false, "DataBars is off in code")
	eq(K.Modules.IsRunning("DataBars"), false, "and does not run")
	assert(next(ns.Bars.views) == nil, "no bar is built while the module is off")
	for _, key in pairs(KEYS) do
		eq(element(K, key), nil, key .. " is not registered while off")
	end
	eq(env.StatusTrackingBarManager:GetAlpha(), 1, "Blizzard's bars are left alone while off")
	noErrors(env, K)
end

-- On: each bar registers with Layout under its element key ------------------------------------------

do
	local env, K, ns = D.New()
	eq(K.Modules.IsRunning("DataBars"), true, "DataBars runs once switched on")
	for id, key in pairs(KEYS) do
		local el = assert(element(K, key), key .. " registers with Layout")
		eq(el.module, "DataBars", key .. " belongs to the module")
		eq(el.label, K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
		eq(el.opts.resizable, true, key .. " is resizable")
		local default, got = K.Setup.Layouts.Default(key), K.Layout.Get(key)
		eq(got.anchor, default.anchor, key .. " anchor")
		eq(got.x, default.x, key .. " x")
		eq(got.y, default.y, key .. " y")
		local footprint = K.Setup.Layouts.Element(key)
		eq(got.width, footprint.width, key .. " starts at its footprint's width")
		eq(got.height, footprint.height, key .. " starts at its footprint's height")
		eq(view(ns, id).holder:IsShown(), true, key .. " is shown")
	end
	noErrors(env, K)
end

-- Experience: fill, rested overlay, ticks, hover text and tooltip --------------------------------------

do
	local env, K, ns, game = D.New()
	W.Settle(env)
	local xp = view(ns, "xp")
	eq(xp.content:IsShown(), true, "the experience bar shows below the cap")
	local low, high = xp.fill:GetMinMaxValues()
	eq(low .. "/" .. high, "0/50000", "the fill spans the level")
	eq(xp.fill:GetValue(), 12345, "the fill shows current XP")
	eq(xp.track:GetValue(), 20345, "the rested overlay reaches current plus rested XP")
	local shownTicks = 0
	for _, tick in ipairs(xp.ticks) do
		if tick:IsShown() then
			shownTicks = shownTicks + 1
		end
	end
	eq(shownTicks, 0, "no ticks by default: the mockup's experience line is unbroken")
	K.Options.Write("DataBars", "xp.segments", 10)
	shownTicks = 0
	for _, tick in ipairs(xp.ticks) do
		if tick:IsShown() then
			shownTicks = shownTicks + 1
		end
	end
	eq(shownTicks, 9, "ten segments draw nine ticks")
	K.Options.Write("DataBars", "xp.segments", 0)

	eq(xp.text:IsShown(), true, "the experience caption shows without the pointer, as the Lumen XP line's does")
	eq(xp.text:GetText(), "Level 38 \194\183 24% \194\183 rested 16%", "the default caption is the level, the percent and the rested share")
	local cp, crel, crelp = xp.text:GetPoint(1)
	eq(cp .. ">" .. tostring(crel == xp.holder) .. ">" .. crelp, "TOP>true>BOTTOM", "the caption is centred under the line")
	eq(xp.plate:IsShown(), false, "a caption under the line needs no plate")
	local mr, mg, mb = K.Tokens.Color(ns.Bars.TOKENS.muted)
	local tr, tg, tb = xp.text:GetTextColor()
	assert(near(tr, mr) and near(tg, mg) and near(tb, mb), "the caption is muted text")
	-- The fill is a gilt filament: a gradient from dim gilt to lit gilt over the fill; the rested reach is cool.
	local gradient = xp.fill:GetStatusBarTexture()._state.Gradient
	assert(gradient and gradient[1] == "HORIZONTAL", "the fill carries a horizontal gradient")
	local dim, lit = gradient[2], gradient[3]
	local dr, dg, db = ns.Bars.GiltStops()
	assert(near(dim.r, dr) and near(dim.g, dg) and near(dim.b, db), "it starts in dim gilt")
	assert(lit.r > dim.r and lit.g > dim.g and lit.b > dim.b, "and ends in lit gilt")
	local rested = K.Options.Read("DataBars", "xp.restedColor")
	local cr, cg, cb = K.Tokens.Color(ns.Bars.TOKENS.cool)
	assert(near(rested.r, cr) and near(rested.g, cg) and near(rested.b, cb), "the rested segment is the cool token")
	-- A player who chose a label on the line keeps #151's plate.
	K.Options.Write("DataBars", "xp.textPosition", "CENTER")
	K.Options.Write("DataBars", "xp.text", "shortPercent")
	eq(xp.text:GetText(), "XP 24%", "the short name and the percent")
	local er, eg, eb = K.Tokens.Color("textEmphasis")
	tr, tg, tb = xp.text:GetTextColor()
	assert(near(tr, er) and near(tg, eg) and near(tb, eb), "a label on the line reads in full white")
	W.Enter(xp.holder)
	eq(xp.text:IsShown(), true, "hovering keeps the caption")
	local _, labelSize = xp.text:GetFont()
	eq(labelSize, 12 * K.Theme.FontScale(), "the label reads at 12, the mockup's XP 32% cap height")
	local point = xp.text:GetPoint(1)
	eq(point, "CENTER", "the label is centred on the bar")
	-- The label sits in a small glass plate on the line, as the mockup's XP 32% sits in a gap in its line: the
	-- 12-point label on a 4-unit line collided with the fill in ingame-18.
	local plate = assert(xp.plate, "the bar has a plate for its label")
	eq(plate:IsShown(), true, "the plate shows under a label on the line")
	local pp, prel, prelp = plate:GetPoint(1)
	eq(pp .. ">" .. tostring(prel == xp.text) .. ">" .. prelp, "CENTER>true>CENTER", "the plate is centred on the label")
	local gap = K.Tokens.Size("gapMedium")
	local textWidth = K.Widgets.TextWidth(xp.text, #xp.text:GetText() * labelSize * 0.5)
	assert(math.abs(plate:GetWidth() - (textWidth + 2 * gap)) <= 1, "the plate leaves a medium gap each side of the label: " .. plate:GetWidth() .. " for " .. textWidth)
	assert(plate:GetHeight() >= labelSize and plate:GetHeight() > xp.holder:GetHeight(), "the plate is taller than the label and the line")
	assert(xp.text:GetParent():GetFrameLevel() > plate:GetFrameLevel(), "the label draws over its plate")
	local tip = K.Widgets.Tooltip()
	eq(tip:IsShown(), true, "hovering shows the KstyleUI tooltip")
	eq(tip:IsOwned(xp.holder), true, "the tooltip belongs to the bar")
	local lines = {}
	for _, line in ipairs(tip.used) do
		lines[#lines + 1] = line.left:GetText()
	end
	local all = (table.concat(lines, "|"):gsub("\226\128\137", ""))
	assert(all:find("EXPERIENCE", 1, true), "the tooltip names the bar in the kit's capitals: " .. all)
	assert(all:find("Level 38", 1, true), "the tooltip gives the level: " .. all)
	assert(all:find("Rested", 1, true), "the tooltip gives rested XP: " .. all)
	W.Leave(xp.holder)
	eq(xp.text:IsShown(), true, "leaving keeps the caption")

	game.xp = 20000
	local styled = #W.Calls(xp.fill, "SetOrientation") + #W.Calls(xp.fill, "SetStatusBarTexture") + #W.Calls(xp.text, "SetFont")
	env.FireEvent("PLAYER_XP_UPDATE", "player")
	eq(#W.Calls(xp.fill, "SetOrientation") + #W.Calls(xp.fill, "SetStatusBarTexture") + #W.Calls(xp.text, "SetFont"), styled,
		"an XP gain updates the values without restyling the bar")
	W.Tick(env, 0.05)
	local mid = xp.fill:GetValue()
	assert(mid > 12345 and mid < 20000, "a gain eases toward the new value, got " .. tostring(mid))
	W.Settle(env)
	eq(xp.fill:GetValue(), 20000, "the gain ends on the new value")

	game.level, game.xp, game.xpMax = 39, 100, 60000
	env.FireEvent("PLAYER_LEVEL_UP", 39)
	eq(select(2, xp.fill:GetMinMaxValues()), 60000, "a new level gets the new range")
	eq(xp.fill:GetValue(), 100, "and jumps to the new value at once")

	game.level = 60
	env.FireEvent("PLAYER_LEVEL_UP", 60)
	eq(xp.content:IsShown(), false, "the experience bar hides at the level cap")
	eq(xp.holder:IsShown(), true, "its element stays for Layout Mode")
	noErrors(env, K)
end

do
	local env, K, ns, game = D.New()
	game.xp = env.Secret(100)
	env.FireEvent("PLAYER_XP_UPDATE", "player")
	eq(view(ns, "xp").content:IsShown(), false, "a secret value hides the bar instead of failing")
	noErrors(env, K)
end

-- Reputation: reaction colour and the faction's name ---------------------------------------------------

do
	local env, K, ns, game = D.New()
	W.Settle(env)
	local rep = view(ns, "rep")
	eq(rep.content:IsShown(), true, "a watched faction shows")
	eq(select(2, rep.fill:GetMinMaxValues()), 6000, "the reaction's span")
	eq(rep.fill:GetValue(), 1500, "standing within the reaction")
	assert(sameColor(rep.fill, K.Tokens.Color("friendly")), "a friendly faction fills in the friendly colour")
	W.Enter(rep.holder)
	eq(rep.text:GetText(), "Stormwind 25%", "the default text is the faction and percent")
	W.Leave(rep.holder)
	game.faction.reaction, game.faction.currentReactionThreshold, game.faction.nextReactionThreshold = 2, -6000, -3000
	game.faction.currentStanding = -4500
	env.FireEvent("UPDATE_FACTION")
	assert(sameColor(rep.fill, K.Tokens.Color("hostile")), "a hostile faction turns the hostile colour")
	game.faction = false
	env.FireEvent("UPDATE_FACTION")
	eq(rep.content:IsShown(), false, "no watched faction hides the bar")
	noErrors(env, K)
end

-- Honour: shown in PvP by default, or always ---------------------------------------------------------

do
	local env, K, ns, game = D.New()
	local honor = view(ns, "honor")
	eq(honor.content:IsShown(), false, "honour waits for PvP by default")
	game.battlefield = true
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	W.Settle(env)
	eq(honor.content:IsShown(), true, "a battleground shows honour")
	eq(honor.fill:GetValue(), 400, "rank points")
	eq(select(2, honor.fill:GetMinMaxValues()), 1000, "rank threshold")
	game.battlefield = false
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	eq(honor.content:IsShown(), false, "leaving PvP hides honour")
	game.worldPvP = true
	env.FireEvent("ZONE_CHANGED")
	eq(honor.content:IsShown(), true, "entering a world PvP subzone shows honour")
	game.worldPvP = false
	env.FireEvent("ZONE_CHANGED")
	eq(honor.content:IsShown(), false, "leaving it hides honour")
	K.Options.Write("DataBars", "honor.show", "always")
	eq(honor.content:IsShown(), true, "the always setting shows honour outside PvP")
	noErrors(env, K)
end

-- An upright bar chosen while the module is off gets its upright size when it starts --------------

do
	local env, K = D.New({ enable = false })
	K.Options.Write("DataBars", "rep.orientation", "VERTICAL")
	K.Modules.Enable("DataBars")
	local size = K.Layout.Get("databars.rep")
	eq(size.width .. "x" .. size.height, "5x162", "the orientation is reconciled on enable: the 162 by 5 Lumen line, upright")
	noErrors(env, K)
end

-- Settings: colour source, texture, orientation, ticks, border, rested, text and font -----------------

do
	local env, K, ns = D.New()
	W.Settle(env)
	local xp = view(ns, "xp")
	local Options = K.Options

	eq(Options.Read("DataBars", "xp.colorSource"), "gilt", "the experience bar is a gilt filament by default")
	Options.Write("DataBars", "xp.colorSource", "class")
	assert(sameColor(xp.fill, K.Theme.Accent()), "the class colour is still a choice")
	local white = xp.fill:GetStatusBarTexture()._state.Gradient
	assert(white and near(white[2].r, 1) and near(white[3].b, 1), "and leaves no gilt gradient on the fill")
	Options.Write("DataBars", "xp.color", { r = 1, g = 0, b = 0 })
	Options.Write("DataBars", "xp.colorSource", "custom")
	assert(sameColor(xp.fill, 1, 0, 0), "a custom colour fills the bar")
	Options.Write("DataBars", "xp.colorSource", "class")
	assert(sameColor(xp.fill, K.Theme.Accent()), "back to the class colour")

	local flat = K.Tokens.MediaList("statusbar")[3].path
	Options.Write("DataBars", "xp.texture", flat)
	eq(xp.fill:GetStatusBarTexture():GetTexture(), flat, "the fill uses the chosen texture")
	eq(xp.track:GetStatusBarTexture():GetTexture(), flat, "so does the rested overlay")

	Options.Write("DataBars", "xp.segments", 4)
	local shown = 0
	for _, tick in ipairs(xp.ticks) do
		shown = shown + (tick:IsShown() and 1 or 0)
	end
	eq(shown, 3, "four segments draw three ticks")
	Options.Write("DataBars", "xp.segments", 0)
	shown = 0
	for _, tick in ipairs(xp.ticks) do
		shown = shown + (tick:IsShown() and 1 or 0)
	end
	eq(shown, 0, "no segments draw no ticks")

	Options.Write("DataBars", "xp.border", false)
	eq(xp.track.borderFrame:IsShown(), false, "the frame around the bar can be turned off")

	Options.Write("DataBars", "xp.rested", false)
	eq(xp.track:GetValue(), 0, "the rested overlay can be turned off")

	Options.Write("DataBars", "xp.reverse", true)
	eq(xp.fill:GetReverseFill(), true, "the fill can run the other way")

	Options.Write("DataBars", "xp.orientation", "VERTICAL")
	eq(xp.fill:GetOrientation(), "VERTICAL", "the bar can stand upright")
	local size = K.Layout.Get("databars.xp")
	eq(size.width .. "x" .. size.height, "4x489", "an upright bar swaps its width and height: the Lumen XP line is 489 by 4")
	Options.Write("DataBars", "xp.orientation", "HORIZONTAL")
	size = K.Layout.Get("databars.xp")
	eq(size.width .. "x" .. size.height, "489x4", "and swaps back")

	Options.Write("DataBars", "xp.textHover", true)
	eq(xp.text:IsShown(), false, "with the hover setting the text waits for the pointer")
	Options.Write("DataBars", "xp.text", "percent")
	Options.Write("DataBars", "xp.textHover", false)
	eq(xp.text:IsShown(), true, "the text can always show")
	eq(xp.text:GetText(), "24%", "in the chosen format")
	Options.Write("DataBars", "xp.text", "none")
	eq(xp.text:IsShown(), false, "no text hides it")
	eq(xp.plate:IsShown(), false, "and its plate")
	Options.Write("DataBars", "xp.text", "remaining")

	local face = K.Tokens.MediaList("font")[3].path
	Options.Write("DataBars", "xp.font", face)
	Options.Write("DataBars", "xp.fontSize", 14)
	Options.Write("DataBars", "xp.outline", "THICKOUTLINE")
	local path, fontSize, flags = xp.text:GetFont()
	eq(path, face, "the chosen font")
	eq(fontSize, 14 * K.Theme.FontScale(), "the chosen size, times the interface text size")
	eq(flags, "THICKOUTLINE", "the chosen outline")
	Options.Write("DataBars", "xp.font", "default")
	path = xp.text:GetFont()
	eq(path, (K.Tokens.Font("body")), "the default font follows the interface font")

	Options.Write("DataBars", "xp.textPosition", "TOP")
	local point, relative, relativePoint = xp.text:GetPoint(1)
	eq(point .. ">" .. relativePoint, "BOTTOM>TOP", "text above the bar")
	eq(relative, xp.holder, "anchored to the bar")
	eq(xp.plate:IsShown(), false, "text off the line needs no plate")
	noErrors(env, K)
end

-- Every setting is declared for the settings window -------------------------------------------------

do
	local env, K = D.New({ enable = false })
	local defaults = K.Store.Defaults("DataBars")
	local function walk(node, prefix)
		for key, value in pairs(node) do
			local path = prefix and (prefix .. "." .. key) or key
			local isColor = type(value) == "table" and value.r ~= nil
			if type(value) == "table" and not isColor then
				walk(value, path)
			elseif path ~= "enabled" then
				assert(K.Options.Row("DataBars", path), path .. " has a row in the settings window")
			end
		end
	end
	walk(defaults)
	noErrors(env, K)
end

-- The preview builds sample bars that follow the settings --------------------------------------------

do
	local env, K, ns = D.New()
	local build = assert(K.Options.Preview("DataBars"), "DataBars gives the settings window a preview")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(248, 400)
	local frame = build(parent)
	assert(type(frame) == "table" and type(frame.Refresh) == "function", "the preview is a frame with Refresh")
	local sample = assert(frame.bars and frame.bars.xp, "the preview shows an experience bar")
	K.Options.Write("DataBars", "xp.color", { r = 0, g = 0, b = 1 })
	K.Options.Write("DataBars", "xp.colorSource", "custom")
	frame:Refresh()
	assert(sameColor(sample.fill, 0, 0, 1), "the preview follows the settings")
	-- Each caption sits above its own bar and clear of the bar before it, so no caption hides under a bar.
	local captionSize = K.Tokens.Size("caption")
	local previousBottom
	for _, def in ipairs(ns.Bars.DEFS) do
		local caption, shown = frame.captions[def.id], frame.bars[def.id]
		local captionTop = -select(5, caption:GetPoint(1))
		local barTop = -select(5, shown.holder:GetPoint(1))
		assert(captionTop + captionSize <= barTop, def.id .. ": the caption sits above its bar, got caption " .. captionTop .. " and bar " .. barTop)
		if previousBottom then
			assert(captionTop >= previousBottom, def.id .. ": the caption sits below the bar before it, got caption " .. captionTop .. " and bar bottom " .. previousBottom)
		end
		previousBottom = barTop + shown.holder:GetHeight()
	end
	local stripCaptionTop = -select(5, frame.captions.strip:GetPoint(1))
	assert(stripCaptionTop >= previousBottom and stripCaptionTop + captionSize <= frame.strip.top, "the strip's caption sits between the last bar and the strip")
	noErrors(env, K)
end

-- Blizzard's bars fade with alpha and lose the mouse; nothing is hidden or moved ----------------------

local FORBIDDEN = { Hide = true, SetParent = true, SetScript = true, ClearAllPoints = true, SetPoint = true, SetShown = true }

local function blizzardFrames(env)
	local manager = env.StatusTrackingBarManager
	local frames = { manager }
	for _, container in ipairs(manager.barContainers) do
		frames[#frames + 1] = container
		for _, bar in ipairs(container.bars) do
			frames[#frames + 1] = bar
			if bar.ExhaustionTick then
				frames[#frames + 1] = bar.ExhaustionTick
			end
		end
	end
	return frames
end

do
	local env, K = D.New()
	local manager = env.StatusTrackingBarManager
	eq(manager:GetAlpha(), 0, "Blizzard's status bars fade out")
	for _, frame in ipairs(blizzardFrames(env)) do
		if frame ~= manager and frame ~= manager.barContainers[1] and frame ~= manager.barContainers[2] then
			eq(W.LastCall(frame, "EnableMouse")[1], false, "a faded Blizzard bar stops taking the mouse")
		end
	end
	K.Modules.Disable("DataBars")
	eq(manager:GetAlpha(), 1, "turning the module off brings them back")
	for _, frame in ipairs(blizzardFrames(env)) do
		if frame ~= manager and frame ~= manager.barContainers[1] and frame ~= manager.barContainers[2] then
			eq(W.LastCall(frame, "EnableMouse")[1], true, "and gives back the mouse")
		end
	end
	K.Modules.Enable("DataBars")
	eq(manager:GetAlpha(), 0, "on again, faded again")
	K.Options.Write("DataBars", "fadeBlizzard", false)
	eq(manager:GetAlpha(), 1, "the player can keep Blizzard's bars")
	for _, frame in ipairs(blizzardFrames(env)) do
		for _, call in ipairs(frame._calls) do
			assert(not FORBIDDEN[call.method], "DataBars called " .. call.method .. " on a Blizzard status bar frame")
		end
	end
	noErrors(env, K)
end

do
	local env, K = D.New({ blizzard = false })
	eq(K.Modules.IsRunning("DataBars"), true, "a client without Blizzard's status bars still runs the module")
	noErrors(env, K)
end

-- Off and on again: frames hide and come back; settings follow a profile change -------------------

do
	local env, K, ns = D.New()
	local count = #K.Layout.Elements()
	K.Modules.Disable("DataBars")
	for id in pairs(KEYS) do
		eq(view(ns, id).holder:IsShown(), false, id .. " hides while the module is off")
	end
	K.Modules.Enable("DataBars")
	for id in pairs(KEYS) do
		eq(view(ns, id).holder:IsShown(), true, id .. " comes back")
	end
	eq(#K.Layout.Elements(), count, "enabling again does not register the elements twice")

	K.Options.Write("DataBars", "xp.color", { r = 1, g = 0, b = 0 })
	K.Options.Write("DataBars", "xp.colorSource", "custom")
	K.Store.SetProfile("Second")
	K.Modules.Enable("DataBars")
	local fill = view(ns, "xp").fill
	local dr = ns.Bars.GiltStops()
	assert(sameColor(fill, K.Tokens.Color("white")) and near(fill:GetStatusBarTexture()._state.Gradient[2].r, dr), "a fresh profile repaints with its own settings: the default gilt filament")
	noErrors(env, K)
end

print("databars bars ok")
