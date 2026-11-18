-- test-render-fx-peaks.lua: every requested FX still samples a playing addon animation at its own peak, and explicit times sample its start and end.
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = dofile("Tools/render/scene.lua")
rawset(_G, "RENDER_HUD_STYLE", "Medallions")

local function find(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

for _, effect in ipairs({ "cast", "stopped", "ready", "burst" }) do
	rawset(_G, "RENDER_FX", effect)
	local module = effect == "ready" and "actionbars" or "unitframes"
	local scene, ns = Hud.Module(module, { layout = "DPS", applyPreset = true })
	local env = Hud.envs[scene]
	local texture, group
	if effect == "ready" then
		texture = ns.actionButtons[4].medReady
		group = texture.anim
	elseif effect == "burst" then
		texture = env.KstyleUI.Effects.playerMedallion.burst
		group = texture.anim
	else
		for _, frame in ipairs(env._frames) do
			if frame.wash and frame.group and frame.group:IsPlaying() then
				texture, group = frame.wash, frame.group
				break
			end
		end
	end
	assert(texture and group and group:IsPlaying(), effect .. ": keep the addon's own animation playing; remove hand-pinned envelopes")
	if effect == "cast" or effect == "stopped" then
		local holder = texture:GetParent()
		while holder and not holder.cb do
			holder = holder:GetParent()
		end
		local cb = holder and holder.cb
		assert(cb and cb.active == false and cb.landed == (effect == "cast"), effect .. ": drive the real spellcast outcome, including its fill, tint, text and flash")
		assert(Scene.BarFraction(env, cb.bar, env._time) == (effect == "cast" and 1 or 0), effect .. ": model CreateDuration/SetTimeSpan so EndTimer replaces the old running fill")
	end
	local item = find(scene, texture)
	assert(item and item.alpha > 0.99, effect .. ": default RENDER_FX must draw the rising alpha's full peak")
	assert(math.abs(env._time - group._playedAt - Scene.AnimationPeak(group)) < 1e-8, effect .. ": take peak timing from the addon's animation calls")
	local roots = { env.KstyleUI.Scale.Root() }
	assert(not find(Scene.Build(env, { roots = roots, time = group._playedAt }), texture), effect .. ": the effect starts transparent")
	assert(not find(Scene.Build(env, { roots = roots, time = group._playedAt + 2 }), texture), effect .. ": the effect ends transparent")
	Hud.envs[scene] = nil
	collectgarbage("collect")
end
rawset(_G, "RENDER_FX", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)
print("ok render FX: cast, stopped, ready and burst peaks follow addon calls")
