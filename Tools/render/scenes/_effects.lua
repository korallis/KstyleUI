-- _effects.lua: RENDER_FX puts the Medallions effects layer into one state before a HUD module's scene is built, so its 2D effects render through the addon's own code. RENDER_FX is one of ready (a slot's steel ready flash), cap (the hub's rune ring at a capped resource), levelup (the hub's level-up burst), cast (a landed cast's steel wash and streak), stopped (an interrupted cast's red wash), vignette (the low-health vignette), burst (the class burst behind the player's medallion, its 2D still) and rest (the secondary frames resting after combat). RENDER_FX_T is the time in seconds since the effect started; unset, each effect shows at its peak. The harness models neither Scale animations nor SetOrder, so this file pins each effect's alpha and size to its own envelope at that time; the 3D models are not drawn (the stub draws no world), so every state is the 2D layer.
local FX = dofile("Tools/regression/effects_env.lua")

local Effects = {}

local PEAK = { ready = 0.075, cap = 0, levelup = 0.3, cast = 0.12, stopped = 0.12, vignette = 0, burst = 0.3, rest = 0 }

local function Clamp(x)
	return math.max(0, math.min(1, x))
end

-- Envelope(t, total, rise) -> the alpha of a flash that rises over rise * total and falls over the rest.
local function Envelope(t, total, rise)
	if t <= 0 or t >= total then
		return 0
	end
	local up = total * rise
	if t < up then
		return t / up
	end
	return 1 - (t - up) / (total - up)
end
Effects.Envelope = Envelope

function Effects.State()
	local state = rawget(_G, "RENDER_FX") or os.getenv("RENDER_FX")
	if not state or state == "" then
		return nil
	end
	assert(PEAK[state], "RENDER_FX must be one of ready, cap, levelup, cast, stopped, vignette, burst or rest")
	local t = tonumber(rawget(_G, "RENDER_FX_T") or os.getenv("RENDER_FX_T") or "")
	return state, t or PEAK[state]
end

local function Fixtures(env)
	local keep = { UnitHealthPercent = env.UnitHealthPercent, UnitPowerType = env.UnitPowerType }
	FX.Install(env)
	return keep
end

local function Medallions(K)
	return K and K.HudStyle and K.HudStyle.Current() == "medallions"
end

-- Apply(env, module, ns, notes) runs the RENDER_FX state in this module's environment, with the effect started
-- RENDER_FX_T seconds before the scene's clock (env._time); it appends what it did to notes.
function Effects.Apply(env, module, ns, notes)
	local state, t = Effects.State()
	local K = env.KstyleUI
	if not state or not Medallions(K) then
		return
	end
	local E = K.Effects
	local now = env._now
	env._now = env._time - t
	if module == "actionbars" then
		if state == "ready" then
			local b = ns.actionButtons[4]
			b.realCooldown = true
			b:FlashReady()
			b.medReady.anim:Stop()
			b.medReady:SetAlpha(Envelope(t, ns.SlabEffects.READY, 0.25))
			notes[#notes + 1] = "fx: slot 4's ready flash " .. t .. " s after its cooldown ended"
		elseif state == "cap" then
			Fixtures(env)
			env._powerType, env._powerToken, env._power = 1, "RAGE", 1
			ns.SlabEffects.UpdateCap()
			notes[#notes + 1] = "fx: the hub ring at a capped resource, its alpha the curve's answer"
		elseif state == "levelup" then
			K.Options.Write("Medallions", "motion", "calm")
			env.FireEvent("PLAYER_LEVEL_UP", 12)
			local burst = ns.Slab.hub.burst
			burst.anim:Stop()
			burst:SetAlpha(Envelope(t, 1.2, 0.2))
			notes[#notes + 1] = "fx: the hub's 2D level-up burst " .. t .. " s in (the 3D rays at Full are not drawn)"
		end
	elseif module == "unitframes" then
		if state == "vignette" then
			Fixtures(env)
			env._health = 0.08
			E.Vignette.Update()
			if E.Vignette.frame then
				E.Vignette.frame.breath:Stop()
			end
			notes[#notes + 1] = "fx: the low-health vignette at 8% health"
		elseif state == "burst" then
			local m = E.playerMedallion
			K.Options.Write("Medallions", "motion", "calm")
			if m and m:Burst("SHAMAN") then
				m.burst.anim:Stop()
				local share = 0.6 + (1.15 - 0.6) * Clamp(t / 1.2)
				local side = m.burst:GetWidth() * share
				m.burst:SetSize(side, side)
				m.burst:SetAlpha(Envelope(t, 1.2, 0.2))
				notes[#notes + 1] = "fx: the class burst behind the player's medallion " .. t .. " s in"
			else
				notes[#notes + 1] = "fx: no player medallion to burst behind"
			end
		elseif state == "cast" or state == "stopped" then
			local cb
			for _, kind in ipairs({ "player", "target" }) do
				for _, list in ipairs({ ns.CastBars.Inline(kind) or {}, ns.CastBars.Get(kind) or {} }) do
					for _, each in ipairs(list) do
						if not cb and each.frame:IsShown() then
							cb = each
						end
					end
				end
			end
			local standIn = false
			if not cb then
				local view = ns.Frames.Get("player").views[1]
				local anchor = view.slab and view.slab.fill or view.parent
				cb = ns.CastBars.NewBar(K.Scale.Root(), "player", false)
				cb.frame:ClearAllPoints()
				cb.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
				cb.frame:SetSize(260, 20)
				ns.CastBars.Layout(cb, 260, 20)
				ns.CastBars.SetName(cb, "Lightning Bolt")
				cb.bar:SetMinMaxValues(0, 1)
				cb.bar:SetValue(state == "cast" and 1 or 0.6)
				cb.frame:Show()
				standIn = true
			end
			if cb then
				ns.CastEffects.Flash(cb, state == "cast" and "giltLit" or "hostile", state == "cast" and 0.6 or 0.55)
				cb.flash.group:Stop()
				cb.flash:Show()
				cb.flash:SetAlpha(Envelope(t, 0.36, 0.17))
				local streak = cb.medStreak
				if streak then
					streak.anim:Stop()
					streak.streak:SetAlpha(Envelope(t, 0.25, 0.5))
					local width = cb.bar:GetWidth()
					local length = streak.streak:GetWidth()
					streak.streak:ClearAllPoints()
					streak.streak:SetPoint("RIGHT", streak, "LEFT", (width + length) * Clamp(t / 0.25), 0)
				end
				notes[#notes + 1] = "fx: the " .. cb.kind .. " cast bar's " .. state .. " flash " .. t .. " s in"
					.. (standIn and " (a stand-alone cast bar under the player frame: this build's Medallions player frame shows no cast bar)" or "")
			else
				notes[#notes + 1] = "fx: no cast bar is showing"
			end
		elseif state == "rest" then
			env.SetCombat(true)
			env.SetCombat(false)
			env.RunTimers()
			for _ = 1, 40 do
				K.Layout.RefreshAlpha("unitframes.focus", 0)
			end
			for _, key in ipairs(K.Layout.Rest.KEYS) do
				K.Layout.RefreshAlpha(key, 0)
			end
			notes[#notes + 1] = "fx: the secondary frames resting after combat"
		end
	end
	env._now = now
end

return Effects
