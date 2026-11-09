-- test-actionbars-lumen.lua: the Lumen socket on the action buttons: a quiet rim at rest, the keybind at the top left,
-- a centred cooldown timer, a gilt proc rim with a breathing glow inside the socket, a red out-of-range tint, a cool
-- desaturated tint without resource, quiet empty sockets that fade further in combat, and bar 1 as one floating row.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W

local function new(opts)
	local env, K, ns = AB.New(opts)
	AB.Enable(env, K)
	return env, K, ns
end

local function rim(b)
	return b.chrome.rim[5]
end

local function textRGB(fs, r, g, b)
	local cr, cg, cb = fs:GetTextColor()
	return W.Near(cr, r) and W.Near(cg, g) and W.Near(cb, b)
end

local function color(K, name)
	local r, g, b, a = K.Tokens.Color(name)
	return r, g, b, a
end

-- The Lumen tokens the sockets use come from one table, so S1's names replace the fallbacks in one place.
do
	local _, K, ns = new()
	local T = assert(ns.Socket and ns.Socket.TOKENS, "Socket.lua names its Lumen tokens in one table")
	for _, role in ipairs({ "gilt", "quietRim", "cool" }) do
		assert(type(T[role]) == "string" and K.Tokens.Color(T[role]) ~= nil, "the " .. role .. " token resolves")
	end
end

-- At rest a socket wears a quiet rim, not the accent; gold is kept for the proc. Hover lifts the rim toward white.
do
	local env, K, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1 })
	local b = AB.Button(ns, "bar1", 1)
	assert(K.Options.Read("ActionBars", "accent") == "quiet", "the quiet rim is the default accent")
	local qr, qg, qb, qa = color(K, ns.Socket.TOKENS.quietRim)
	assert(W.SameColor(rim(b), qr, qg, qb, qa), "the resting rim is the quiet rim")
	K.Widgets.Hover(b, true)
	W.Settle(env)
	local _, _, _, ha = rim(b):GetVertexColor()
	assert(ha > qa, "hover lifts the rim, got alpha " .. tostring(ha))
	K.Widgets.Hover(b, false)
	W.Settle(env)
	K.Options.Write("ActionBars", "accent", "class")
	local cr, cg, cb = K.Widgets.IconRim(K.Theme.ClassColor(K.Theme.Class()))
	assert(W.SameRGB(rim(b), cr, cg, cb), "the class accent is still a choice")
	assert(#env._errors == 0, AB.Errors(env))
end

-- The keybind sits at the top left and the count at the bottom right, inside the socket.
do
	local env, _, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1, count = "3" })
	local b = AB.Button(ns, "bar1", 1)
	local hp = b.hotkey._points[1]
	assert(hp and hp[1] == "TOPLEFT" and hp[2] == b and hp[3] == "TOPLEFT" and hp[4] > 0 and hp[5] < 0, "the keybind is inset at the top left")
	assert(W.LastCall(b.hotkey, "SetJustifyH")[1] == "LEFT", "the keybind reads from the left")
	local cp = b.count._points[1]
	assert(cp and cp[1] == "BOTTOMRIGHT" and cp[3] == "BOTTOMRIGHT", "the count sits at the bottom right")
	b:Restyle()
	assert(b.hotkey._points[1][1] == "TOPLEFT", "a restyle keeps the keybind at the top left")
	assert(#env._errors == 0, AB.Errors(env))
end

-- A cooldown is a radial darkening with its timer in the middle of the socket.
do
	local env, _, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1, cooldown = { name = "cd" } })
	local b = AB.Button(ns, "bar1", 1)
	assert(b.cooldown._state.DrawSwipe == nil or b.cooldown._state.DrawSwipe[1] ~= false, "the swipe darkens the icon")
	local p = assert(b.countdown, "the cooldown has a countdown")._points[1]
	assert(p[1] == "CENTER" and p[2] == b.icon and p[3] == "CENTER", "the timer is centred on the icon")
	assert(W.LastCall(b.countdown, "SetJustifyH")[1] == "CENTER", "and centred in its line")
	assert(#env._errors == 0, AB.Errors(env))
end

-- A proc: a gilt rim and a soft glow inside the socket whose alpha breathes at 0.7 seconds; nothing past the socket.
do
	local env, K, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.proc, "the button procs")
	local gr, gg, gb = color(K, ns.Socket.TOKENS.gilt)
	assert(W.SameRGB(rim(b), gr, gg, gb), "the proc rim is gilt")
	local glow = assert(b.lumenGlow, "the proc shows the socket's own glow")
	assert(glow:IsShown(), "the glow shows")
	assert(b.procGlow == nil, "the kit's glow, with its halo past the button, is not used")
	local inside = glow._points[1]
	assert(inside and inside[2] == b.icon, "the glow is laid over the icon, inside the socket")
	assert(#glow.texture._masks > 0, "the glow is masked to the icon's shape")
	local breath = glow.breath
	assert(breath and breath:IsPlaying(), "the glow breathes")
	assert(W.LastCall(breath, "SetLooping")[1] == "BOUNCE", "in and out")
	local alpha = breath._anims[1]
	assert(W.Near(W.LastCall(alpha, "SetDuration")[1], 0.7), "at 0.7 seconds a breath")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 100)
	assert(not b.proc and not breath:IsPlaying(), "the hide event stops the breath")
	W.Settle(env)
	assert(not glow:IsShown() or glow:GetAlpha() == 0, "and the glow goes")
	local qr, qg, qb, qa = color(K, ns.Socket.TOKENS.quietRim)
	assert(W.SameColor(rim(b), qr, qg, qb, qa), "the rim returns to quiet")
	assert(#env._errors == 0, AB.Errors(env))
end

-- With reduced motion the proc glow holds still instead of breathing.
do
	local env, K, ns = new()
	K.Motion.SetReducedMotion(true)
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b.lumenGlow:IsShown() and not b.lumenGlow.breath:IsPlaying(), "a still glow under reduced motion")
	K.Motion.SetReducedMotion(false)
	assert(#env._errors == 0, AB.Errors(env))
end

-- Out of range tints the icon and the keybind red; back in range both return.
do
	local env, K, ns = new({
		setup = function(e)
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end,
	})
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, false, true)
	local range = K.Options.Read("ActionBars", "rangeColor")
	assert(W.Near(b.tint[1], range.r) and W.Near(b.tint[2], range.g), "the icon takes the range tint")
	assert(textRGB(b.hotkey, range.r, range.g, range.b), "the keybind turns red too")
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, true, true)
	assert(textRGB(b.hotkey, color(K, "textEmphasis")), "back in range the keybind is white again")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Not enough resource: a cool, desaturated, dimmer icon.
do
	local env, K, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 1, usable = false, noMana = true } })
	assert(W.LastCall(b.icon, "SetDesaturated")[1] == true, "the icon is desaturated")
	local r, g, bl = b.icon:GetVertexColor()
	assert(bl > r and bl < 1, "the tint is cool and dimmed, got " .. r .. ", " .. g .. ", " .. bl)
	local power = K.Options.Read("ActionBars", "powerColor")
	assert(W.Near(power.b, select(3, color(K, ns.Socket.TOKENS.cool))), "the default power colour is the cool token")
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 1, usable = true, noMana = false } })
	assert(W.LastCall(b.icon, "SetDesaturated")[1] == false, "with resource the colour returns")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Out of range, losing and regaining resource still repaints: the range tint does not hide the resource state.
do
	local env, _, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1 })
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, false, true)
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 1, usable = false, noMana = true } })
	assert(W.LastCall(b.icon, "SetDesaturated")[1] == true, "losing resource out of range desaturates")
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 1, usable = true, noMana = false } })
	assert(W.LastCall(b.icon, "SetDesaturated")[1] == false, "regaining it out of range restores the colour")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Empty sockets rest at 35%, recede to 12% in combat, and still light on hover and while an action is dragged.
do
	local env, K, ns = new()
	local b = AB.Button(ns, "bar1", 7)
	assert(W.Near(b:GetAlpha(), 0.35), "an empty socket rests at 35%, got " .. tostring(b:GetAlpha()))
	env.SetCombat(true)
	assert(W.Near(b:GetAlpha(), 0.12), "in combat it fades to 12%, got " .. tostring(b:GetAlpha()))
	assert(#env._blocked == 0, "only alpha changes in combat: " .. table.concat(env._blocked, ", "))
	K.Widgets.Hover(b, true)
	W.Settle(env)
	assert(b:GetAlpha() == 1, "hovering still lights it in full")
	K.Widgets.Hover(b, false)
	W.Settle(env)
	env.FireEvent("ACTIONBAR_SHOWGRID")
	assert(b:GetAlpha() == 1, "dragging an action shows it in full")
	env.FireEvent("ACTIONBAR_HIDEGRID")
	env.SetCombat(false)
	assert(W.Near(b:GetAlpha(), 0.35), "after combat it rests at 35% again")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Bar 1 is one row of twelve sockets with no strip behind them: the sockets float, as the Lumen hands do.
do
	local _, K, ns = new()
	local cfg = K.Options.Read("ActionBars", "bar1")
	assert(cfg.buttons == 12 and cfg.rows == 1 and cfg.size == 38, "bar 1 is one row of twelve 38-unit sockets")
	for _, def in ipairs(ns.BARS) do
		assert(K.Options.Read("ActionBars", def.key).backing == false, def.key .. " has no backing strip by default")
	end
	assert(not ns.bars.bar1.backing:IsShown(), "bar 1's strip is hidden")
end

-- The preview shows the same socket: the proc in gilt with its glow, the keybind at the top left.
do
	local env, K, ns = new()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(500, 60)
	local frame = K.Options.Preview("ActionBars")(parent)
	local proc = frame.buttons[1]
	local gr, gg, gb = color(K, ns.Socket.TOKENS.gilt)
	assert(proc.proc and W.SameRGB(rim(proc), gr, gg, gb) and proc.lumenGlow:IsShown(), "the preview's proc is gilt with its glow")
	assert(proc.hotkey._points[1][1] == "TOPLEFT", "the preview's keybind is at the top left")
	assert(#env._errors == 0, AB.Errors(env))
end

print("action bar lumen sockets ok")
