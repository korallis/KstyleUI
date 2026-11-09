-- test-widgets-iconbutton-extras.lua: the icon button's silent clicks, icon tint, own accent colour and charge cooldown.
local W = dofile("Tools/regression/widget_env.lua")

local function iconButton(opts)
	local env, K = W.New()
	env._sounds = {}
	env.SOUNDKIT = { U_CHAT_SCROLL_BUTTON = 7 }
	env.PlaySound = function(id)
		env._sounds[#env._sounds + 1] = id
	end
	return env, K, K.Widgets.IconButton(K.Scale.Root(), opts or {})
end

-- A silent icon button plays no click sound, so a key bound to an action button does not click on every press.
do
	local env, _, button = iconButton({})
	W.Click(button)
	assert(#env._sounds == 1, "a plain icon button clicks")
	local quietEnv, _, quiet = iconButton({ silent = true })
	W.Click(quiet)
	assert(#quietEnv._sounds == 0, "a silent icon button plays no sound")
	assert(#quietEnv._errors == 0)
end

-- SetTint multiplies the icon's shade, so range and power colours survive hover, press and the unusable state.
do
	local env, K, button = iconButton({})
	button:SetTint(1, 0.5, 0.25)
	assert(W.SameColor(button.icon, 1, 0.5, 0.25), "the tint reaches the icon")
	W.Enter(button)
	W.Settle(env)
	assert(W.SameColor(button.icon, 1, 0.5, 0.25), "hover keeps the tint")
	button:SetUsable(false)
	local r, g, b = button.icon:GetVertexColor()
	assert(W.Near(g / r, 0.5) and W.Near(b / r, 0.25) and r < 1, "an unusable icon is darker and keeps the tint's hue")
	button:SetUsable(true)
	button:SetTint()
	assert(W.SameColor(button.icon, 1, 1, 1), "no arguments return the icon to white")
	button:SetTint(1, env.Secret(0.5), 1)
	button:SetTint(1, 1, env.Secret(0.5))
	assert(W.SameColor(button.icon, 1, 1, 1), "a secret channel is refused and the icon stays white")
	W.Leave(button)
	W.Settle(env)
	assert(K.Widgets.IconButton ~= nil and #env._errors == 0)
end

-- SetAccent gives one button its own accent: the hairline, the hover glow and the proc glow follow it.
do
	local env, K, button = iconButton({})
	button:SetAccent(0.2, 0.4, 0.6)
	local wr, wg, wb = K.Tokens.Color("textHover")
	local rr, rg, rb = K.Widgets.Mix(0.2, 0.4, 0.6, 1, wr, wg, wb, 1, 0.15)
	assert(W.SameColor(button.chrome.rim[5], rr, rg, rb, 1), "the resting hairline uses the own accent, lifted 15% toward white")
	W.Enter(button)
	W.Settle(env)
	local hr, hg, hb = button.chrome.rim[5]:GetVertexColor()
	assert(hr > rr and hg > rg and hb > rb and hb > hr, "hover brightens the own accent")
	assert(W.SameRGB(button.hoverGlow.slice[5], 0.2, 0.4, 0.6), "the hover glow takes the own accent")
	button:SetProc(true)
	local lr, lg, lb = K.Tokens.Color("giltLit")
	assert(W.SameRGB(button.procGlow.slice[5], lr, lg, lb), "a proc glows gold whatever the button's own accent: gold is Lumen's proc colour")
	assert(W.SameRGB(button.chrome.rim[5], lr, lg, lb), "and lights the rim gold")
	W.Leave(button)
	W.Settle(env)
	K.Callbacks.Fire("ThemeChanged")
	assert(W.SameRGB(button.chrome.rim[5], lr, lg, lb) and W.SameRGB(button.procGlow.slice[5], lr, lg, lb), "a theme change keeps the proc gold")
	button:SetProc(false)
	assert(W.SameColor(button.chrome.rim[5], rr, rg, rb, 1), "when the proc ends the own accent rim returns")
	button:SetAccent()
	local r, g, b = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.15)
	assert(W.SameColor(button.chrome.rim[5], r, g, b, 1), "no arguments return to the theme accent")
	assert(#env._errors == 0)
end

-- A charge cooldown is a second Cooldown that draws only its edge, made on first use from a duration object.
do
	local env, _, button = iconButton({})
	assert(button.chargeCooldown == nil, "no charge cooldown until one is needed")
	button:ClearChargeCooldown()
	local object = {}
	assert(button:SetChargeCooldownFromDuration(object) == true)
	local cd = button.chargeCooldown
	assert(cd and cd:GetObjectType() == "Cooldown" and cd._template == "CooldownFrameTemplate")
	assert(W.LastCall(cd, "SetCooldownFromDurationObject")[1] == object, "the duration object goes to the engine")
	assert(W.LastCall(cd, "SetDrawSwipe")[1] == false and W.LastCall(cd, "SetDrawEdge")[1] == true, "only the edge is drawn")
	assert(W.LastCall(cd, "SetHideCountdownNumbers")[1] == true, "the recharge shows no numbers")
	button:ClearChargeCooldown()
	assert(#W.Calls(cd, "Clear") == 1)
	assert(#env._errors == 0)
end

-- iconInset draws a smaller icon centred in a larger button, for a glyph on a round plate.
do
	local env, _, button = iconButton({ size = 30, iconInset = 7 })
	local _, _, _, x, y = button.icon:GetPoint(1)
	assert(W.Near(x, 7) and W.Near(y, -7), "the icon starts the inset in from the button's top left corner, got " .. tostring(x) .. ", " .. tostring(y))
	local _, _, _, x2, y2 = button.icon:GetPoint(2)
	assert(W.Near(x2, -7) and W.Near(y2, 7), "and ends the inset in from the bottom right corner")
	assert(#env._errors == 0)
end

print("icon button extras ok")
