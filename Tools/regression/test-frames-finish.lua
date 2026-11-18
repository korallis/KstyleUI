-- test-frames-finish.lua: the Frames tray on the 491-unit centre column and the spell name inside both cast bars, each with an Options switch that brings back the old look.
local AB = dofile("Tools/regression/actionbars_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function offset(region)
	local _, _, _, x, y = region:GetPoint(1)
	return x, y
end

do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local Widgets, Layouts = K.Widgets, K.Setup.Layouts
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	local header = bar1.header
	local px = K.Scale.Pixel(1) / Widgets.ScaleFactor(header)
	local grid = Layouts.Grid("actionbars.bar1")
	local function row(bar)
		local last = bar.buttons[12]
		return offset(last) + last:GetWidth() - offset(bar.buttons[1])
	end
	assert(K.HudStyle.Current() == "frames" and ns.Config("trayColumn") == true, "the tray sits on the centre column by default")
	assert(near(row(bar1), 491, px) and near(row(bar2), 491, px), "G6: twelve buttons span the 491-unit column, got " .. row(bar1))
	local tall = Widgets.Snap(header, grid.size)
	assert(near(bar1.holder:GetHeight(), tall) and near(bar2.holder:GetHeight(), tall), "each row keeps its place, so the layout and the fit do not move")
	local _, top1 = offset(bar1.buttons[1])
	local _, top2 = offset(bar2.buttons[1])
	assert(near(top1, 0) and near(top2, -(tall - bar2.buttons[1]:GetHeight())), "bar 1's buttons rise to its top and bar 2's drop to its bottom, so the rows stay one gap apart")
	local _, anchor = ns.Tray.card:GetPoint(1)
	assert(anchor == bar2.buttons[1], "the tray card wraps the buttons, not the taller rows")
	K.Options.Write("ActionBars", "trayColumn", false)
	local wide = Widgets.Snap(header, 11 * (grid.size + grid.spacing)) + Widgets.Snap(header, grid.size)
	assert(near(bar1.holder:GetWidth(), wide) and near(bar2.holder:GetWidth(), wide), "off: the rows are the KSTY-44 tray's again")
	_, top2 = offset(bar2.buttons[1])
	assert(near(top2, 0) and near(bar2.buttons[1]:GetHeight(), tall), "off: the old buttons fill their rows")
	_, anchor = ns.Tray.card:GetPoint(1)
	assert(anchor == bar2.holder, "off: the card wraps the rows as before")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = U.New()
	local CastBars = ns.CastBars
	local player = CastBars.Get("player")[1]
	env._time = 2.2
	env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 188196)
	assert(player.mode == "inside", "H1: the Frames player cast writes its spell inside the bar, got " .. tostring(player.mode))
	local point, relative = player.text:GetPoint(1)
	assert(point == "LEFT" and relative == player.bar, "the spell name rides the bar")
	assert(near(player.bar.opts.height, 14), "the bar is 14 units tall")
	local function inked(cb, r, g, b)
		local ink, want = W.LastCall(cb.text, "SetTextColor"), { K.Widgets.InkFor(r, g, b) }
		return near(ink[1], want[1]) and near(ink[2], want[2]) and near(ink[3], want[3]) and select(3, cb.text:GetFont()) == want[5]
	end
	assert(inked(player, player.pr, player.pg, player.pb), "with Readable text on bars, the name takes the ink for the gilt under it")
	env._units.player.cast = nil
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 188196)
	assert(player.inkEmpty and inked(player, K.Tokens.Color("buttonFill")), "an interrupted cast empties the bar, so the name takes light outlined ink")
	K.Options.Write("Appearance", "readableBars", false)
	env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-3", 188196)
	local light = { K.Tokens.Color("textEmphasis") }
	local ink = W.LastCall(player.text, "SetTextColor")
	assert(near(ink[1], light[1]) and select(3, player.text:GetFont()) == "OUTLINE", "Readable text on bars off: light ink with a thin outline")
	K.Options.Write("Appearance", "readableBars", true)
	U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2,
		cast = { name = "Shadow Bolt", texture = 136197, start = 1000, finish = 3800, spellID = 686 } })
	env._time = 3
	env.SetTarget(true)
	local target = CastBars.Inline("target")[1]
	local reserved = ns.Frames.Get("target").views[1].geometry.cast
	assert(target.mode == "inside" and near(target.bar.opts.height, 14), "H1: the target's cast holds its name inside a 14-unit bar")
	K.Options.Write("UnitFrames", "player.castbarInside", false)
	K.Options.Write("UnitFrames", "target.castbarInside", false)
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 188196)
	env.SetTarget(true)
	point, relative = player.text:GetPoint(1)
	assert(player.mode == "above" and point == "BOTTOMLEFT" and relative == player.frame, "off: the player's label stands above the bar again")
	assert(target.mode == "below", "off: the target's label sits under its bar again")
	local cast = ns.Frames.Get("target").views[1].geometry.cast
	assert(near(cast.y, reserved.y) and cast.h > reserved.h, "the bar keeps its place either way; on, it gives up the label's row")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("frames finish ok")
