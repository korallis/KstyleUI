-- test-widgets-slot.lua: the shared action slot: an opaque well and lit rim at rest, the key at the top left, a centred number over a sweep with a lit edge, and the press flash, hover lift, proc glow and ready flash played by animation groups, never by Lua each frame.
local W = dofile("Tools/regression/widget_env.lua")

local function slot(opts)
	local env, K = W.New({
		setup = function(e)
			function e.CreateColor(r, g, b, a)
				return { r = r, g = g, b = b, a = a }
			end
		end,
	})
	return env, K, K.Widgets.Slot(K.Scale.Root(), opts or {})
end

local function noTween(env)
	for _, frame in ipairs(env._frames) do
		if frame:GetScript("OnUpdate") then
			return false
		end
	end
	return true
end

local function fades(group)
	local out = {}
	for i, a in ipairs(group._anims) do
		out[i] = {
			from = W.LastCall(a, "SetFromAlpha")[1],
			to = W.LastCall(a, "SetToAlpha")[1],
			duration = W.LastCall(a, "SetDuration")[1],
			delay = (W.LastCall(a, "SetStartDelay") or { 0 })[1],
		}
	end
	return out
end

do
	local env, K, b = slot({ size = 36 })
	local fr, fg, fb = K.Tokens.Color("slotFill")
	assert(W.SameColor(b.chrome.fill[5], fr, fg, fb, 1), "an empty slot is opaque: the fill is slotFill at full alpha")
	local wr, wg, wb = K.Tokens.Color("slotWell")
	assert(W.SameColor(b.well, wr, wg, wb, 1) and b.well:IsShown(), "a dark well sits under the icon, so an empty slot reads as a socket")
	assert(#b.well._masks > 0 and b.well._points[1][2] == b.icon, "the well fills the icon's masked shape")
	local rr, rg, rb, ra = K.Tokens.Color("slotRim")
	assert(W.SameColor(b.chrome.rim[5], rr, rg, rb, ra), "the rim is the lit slot rim")
	assert(W.SameColor(b.chrome.line[5], K.Tokens.Color("socketEdge")), "outside it, the near-black edge")
	assert(W.SameColor(b.innerLine[1], 0, 0, 0, 0.8), "and a black hairline inside, round the icon")
	assert(b.bevelTop._state.Gradient and b.bevelBottom._state.Gradient, "the icon has a bevel: lit at the top, shaded at the bottom")
	local hp = b.hotkey._points[1]
	assert(hp[1] == "TOPLEFT" and hp[2] == b and hp[4] > 0 and hp[5] < 0, "the key sits inset at the top left")
	local cp = b.countdown._points[1]
	assert(cp[1] == "CENTER" and cp[2] == b.icon and cp[3] == "CENTER", "the cooldown number is centred on the icon")
	local nr, ng, nb = K.Tokens.Color("slotNumber")
	local tr, tg, tb = b.countdown:GetTextColor()
	assert(W.Near(tr, nr) and W.Near(tg, ng) and W.Near(tb, nb), "in the warm number colour")
	assert(W.LastCall(b.cooldown, "SetDrawEdge")[1] == true, "the sweep draws its edge")
	local er, eg, eb, ea = K.Tokens.Color("slotEdge")
	local edge = W.LastCall(b.cooldown, "SetEdgeColor")
	assert(edge and W.Near(edge[1], er) and W.Near(edge[2], eg) and W.Near(edge[3], eb) and W.Near(edge[4], ea), "lit in the edge colour")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local env, K, b = slot()
	local paints = 0
	local paint = b.Paint
	b.Paint = function(self)
		paints = paints + 1
		paint(self)
	end
	W.Down(b)
	assert(b.pressLayer:IsShown() and b.press:IsPlaying(), "a press shows the flash and plays its group")
	local f = fades(b.press)
	assert(#f == 2 and f[1].from == 0 and f[1].to == 1 and W.Near(f[1].duration, K.Tokens.Duration("pressIn")), "it brightens in pressIn")
	assert(f[2].from == 1 and f[2].to == 0 and W.Near(f[2].duration, K.Tokens.Duration("pressOut")) and W.Near(f[2].delay, f[1].duration), "then settles in pressOut")
	assert(paints == 0 and b.pressT == nil and noTween(env), "with no repaint and no tween")
	b.press:Stop()
	W.Up(b)
	b:GetScript("OnClick")(b, "LeftButton", false)
	assert(not b.press:IsPlaying(), "the release does not flash again")
	b:GetScript("OnClick")(b, "LeftButton", true)
	assert(b.press:IsPlaying(), "a key press, which clicks on its way down, flashes")
	b.press:Stop()
	b:GetScript("OnClick")(b, "LeftButton", true)
	assert(not b.press:IsPlaying(), "a key held down flashes once")
	b:GetScript("OnClick")(b, "LeftButton", false)
	b.press:GetScript("OnFinished")(b.press)
	assert(not b.pressLayer:IsShown(), "the flash hides when its group ends")
	K.Motion.SetLevel("off")
	b:GetScript("OnClick")(b, "LeftButton", true)
	assert(not b.press:IsPlaying(), "with motion off a press does not flash")
	K.Motion.SetLevel("full")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local env, K, b = slot()
	b:SetProc(true)
	local glow = b.lumenGlow
	assert(glow:IsShown() and glow.breath:IsPlaying(), "a proc shows the glow and breathes")
	assert(W.LastCall(glow.breath, "SetLooping")[1] == "BOUNCE", "in and out")
	local f = fades(glow.breath)
	assert(W.Near(f[1].duration, K.Tokens.Duration("procPulse")), "at the proc pulse")
	local gr, gg, gb = K.Tokens.Color("giltLit")
	assert(W.SameRGB(glow.texture, gr, gg, gb) and W.LastCall(glow.texture, "SetBlendMode")[1] == "ADD", "a gilt light inside the icon")
	assert(W.SameRGB(b.procHalo[1], gr, gg, gb) and W.LastCall(b.procHalo[1], "SetBlendMode")[1] == "ADD", "and a gilt halo round the slot")
	assert(b.chrome.proc, "the slot's outer edge turns gilt")
	assert(noTween(env), "the breath is the client's, not a tween")
	b:SetProc(false)
	assert(not glow:IsShown() and not glow.breath:IsPlaying(), "the proc ends at once")
	K.Motion.SetReducedMotion(true)
	b:SetProc(true)
	assert(glow:IsShown() and not glow.breath:IsPlaying(), "reduced motion holds the glow still")
	K.Motion.SetReducedMotion(false)
	b:Paint()
	assert(glow.breath:IsPlaying(), "and full motion breathes again")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local env, K, b = slot()
	local f = fades(b.readyFlash)
	assert(W.Near(f[1].duration, K.Tokens.Duration("readyFlash")) and f[1].to == 0, "the ready flash fades out in readyFlash")
	local gr, gg, gb = K.Tokens.Color("giltLit")
	local c = W.LastCall(b.ready, "SetColorTexture")
	assert(W.Near(c[1], gr) and W.Near(c[2], gg) and W.Near(c[3], gb), "in gilt")
	b:SetCooldownFromDuration({})
	b.cooldown:GetScript("OnShow")(b.cooldown)
	b.cooldown:GetScript("OnCooldownDone")(b.cooldown)
	assert(b.ready:IsShown() and b.readyFlash:IsPlaying(), "a real cooldown's end flashes the slot")
	assert(noTween(env), "by an animation group")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local env, K, b = slot()
	W.Enter(b)
	assert(b.hoverLayer:IsShown() and b.hoverIn:IsPlaying() and noTween(env), "hover fades a lift in by an animation group")
	assert(W.LastCall(b.hoverIn, "SetToFinalAlpha")[1] == true, "and holds it when the fade ends")
	W.Leave(b)
	assert(not b.hoverLayer:IsShown() and not b.hoverIn:IsPlaying() and not b.hoverOut:IsPlaying(), "leaving before the lift has faded in hides it at once, so skimming a bar never pops a slot to full")
	W.Enter(b)
	b.hoverIn:Stop()
	W.Leave(b)
	assert(b.hoverOut:IsPlaying(), "a full lift fades out")
	W.Enter(b)
	b.hoverOut:GetScript("OnFinished")(b.hoverOut)
	assert(b.hoverLayer:IsShown(), "a fade-out that ends after the pointer came back leaves the lift shown")
	b.hoverIn:Stop()
	W.Leave(b)
	K.Motion.SetLevel("off")
	W.Enter(b)
	assert(b.hoverLayer:IsShown() and W.LastCall(b.hoverLayer, "SetAlpha")[1] == 1 and not b.hoverIn:IsPlaying(), "with motion off the lift shows at once, at full alpha")
	K.Motion.SetLevel("full")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

print("widgets slot ok")
