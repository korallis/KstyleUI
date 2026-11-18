-- test-motion-proc-input.lua: F3/F5/F7 motion boundaries and the previous-behaviour switches.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W
local mode = arg and arg[1]

if not mode or mode == "input" then
    local env, K, ns = AB.New()
    AB.Enable(env, K)
    local b = AB.Button(ns, "bar1", 1)
    W.Enter(b)
    W.Leave(b)
    assert(b.hoverIn:IsPlaying() and b.hoverLayer:IsShown(), "F5: chain hover-out after hover-in instead of hiding during the rise")
    b.hoverIn:Stop()
    b.hoverIn:GetScript("OnFinished")(b.hoverIn)
    assert(b.hoverOut:IsPlaying(), "F5: the completed hover-in starts hover-out")
    assert(W.Near(b.hoverOut._anims[1]:GetDuration(), 0.1), "F5: hover-out takes 100 ms")
    assert(b.hoverOut._anims[1]:GetSmoothing() == "IN", "F5: hover-out eases IN")
    W.Down(b)
    assert(b.heldLayer:IsShown() and b.heldLayer:GetAlpha() == 0.6, "F5: holding the button keeps a 0.6 rim")
    W.Up(b)
    assert(b.heldRelease:IsPlaying(), "F5: releasing fades the held rim")
    assert(W.Near(b.statePressSpread, K.Widgets.Snap(b, 4)), "F5: the press halo spreads four units")
    local tween, durations = K.Motion.Tween, {}
    K.Motion.Tween = function(_, _, _, _, duration) durations[#durations + 1] = duration end
    local control = K.Widgets.Button(K.Scale.Root(), { text = "Press" })
    K.Widgets.Press(control, true)
    K.Widgets.Press(control, false)
    K.Motion.Tween = tween
    assert(durations[1] == K.Tokens.Duration("pressIn") and durations[2] == K.Tokens.Duration("pressOut"), "F5: Widgets.Press uses pressIn and pressOut")
    K.Options.Write("ActionBars", "inputContinuity", false)
    W.Enter(b); W.Leave(b)
    assert(not b.hoverLayer:IsShown(), "F5: disabling continuity restores the immediate early hover exit")
    assert(W.Near(b.statePressSpread, K.Widgets.Snap(b, 6)), "F5: disabling continuity restores the six-unit press halo")
    K.Options.Write("HudStyle", "style", "medallions")
    env.RunTimers()
    K.Options.Write("ActionBars", "inputContinuity", true)
    W.Enter(b)
    assert(b.medHover:IsShown(), "F5: the slab retains its own hover")
    for _, rim in ipairs(b.hoverRim or {}) do
        assert(not rim:IsShown(), "F5: the slab suppresses the Frames hover rim")
    end
    assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

if not mode or mode == "proc" then
    local env, K, ns = AB.New({ class = "WARLOCK" })
    AB.Enable(env, K)
    AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
    local b = AB.Button(ns, "bar1", 1)
    ns.Button.SetProc(b, true)
    assert(b.lumenGlow.enter:IsPlaying(), "F3: proc glow enters over procIn")
    assert(W.Near(b.lumenGlow.enter._anims[1]:GetDuration(), K.Tokens.Duration("procIn")), "F3: proc entry reads its token")
    assert(W.Near(b.lumenGlow.breath._anims[1]:GetDuration(), K.Tokens.Duration("glowBreath")), "F3: proc breath reads glowBreath")
    assert(W.Near(select(4, b.lumenGlow.texture:GetVertexColor()), 0.25), "F3: proc wash is 0.25")
    assert(W.Near(b.stateProcSpread, K.Widgets.Snap(b, 5.6)), "F3: proc halo spreads 5.6 units")
    ns.Button.SetProc(b, false)
    assert(b.lumenGlow.leave:IsPlaying() and b.lumenGlow:IsShown(), "F3: proc glow leaves instead of snapping off")
    b:FlashReady()
    assert(b.readyAttack:GetDuration() == 0.06 and b.readyFade:GetDuration() == 0.18, "F3: ready attacks in 60 ms and decays in 180 ms")
    assert(W.LastCall(b.readyWash, "SetColorTexture")[4] == 0.45, "F3: the steel ready wash peaks at 0.45")
    b.lumenGlow.leave:Finish()
    b.lumenGlow.leave:GetScript("OnFinished")()
    assert(not b.lumenGlow:IsShown() and not b.lumenGlow.breath:IsPlaying(), "F3: the hidden proc stops breathing")
    K.Options.Write("HudStyle", "style", "medallions")
    env.RunTimers()
    ns.Button.SetProc(b, true)
    local start = b.medProcStart.anim
    env._game.procs[100] = true
    start:Stop()
    env.FireEvent("PLAYER_ENTERING_WORLD")
    assert(not start:IsPlaying(), "F3: entering the world does not replay an existing proc's start")
    K.Options.Write("Medallions", "motion", "calm")
    assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
    local l, r, t, bottom = b.medProc:GetTexCoord()
    local rows, columns = K.Tokens.Flipbook("medProcWarlock")
    assert(l == 0 and r == 1 / columns and t == 0 and bottom == 1 / rows, "F3: Calm holds the first sprite cell: " .. tostring(r) .. "," .. tostring(bottom))
    assert(K.Effects.PRIORITY.levelUp < K.Effects.PRIORITY.proc, "F3: level-up outranks proc")
    env._game.procs[100] = false
    ns.Button.SetProc(b, false)
    K.Options.Write("ActionBars", "procTransitions", false)
    ns.Button.SetProc(b, true)
    ns.Button.SetProc(b, false)
    assert(not b.medProc:IsShown(), "F3: disabling transitions restores the immediate proc exit")
    b:FlashReady()
    assert(W.Near(b.medReady:GetWidth(), K.Widgets.Snap(b.medReady, b:GetWidth() / 0.7)), "F3: disabling transitions restores the previous ready footprint")
    K.Options.Write("ActionBars", "procTransitions", true)
    b:FlashReady()
    assert(b.medReady:GetWidth() <= b:GetWidth() * 1.15 and b.medReady:GetWidth() >= b:GetWidth(), "F3: the polished ready flash is at most 1.15 times the slot")
    assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

if not mode or mode == "model" then
    local env, K, ns = AB.New()
    AB.Enable(env, K)
    K.Options.Write("HudStyle", "style", "medallions")
    env.RunTimers()
    env.FireEvent("PLAYER_ENTERING_WORLD")
    local warmed = 0
    for _, f in ipairs(env._frames) do
        if f:GetObjectType() == "ModelScene" and f.actor and f.actor._state.ModelByFileID then warmed = warmed + 1 end
    end
    assert(warmed > 0, "F7: PLAYER_ENTERING_WORLD prewarms the hub models")
    local hub = ns.Slab.hub
    env.GetTime = function() return env._time end
    env._time = 100
    assert(ns.SlabEffects.Proc(hub) == "model", "F7: the first hub model plays")
    local active
    for _, f in ipairs(env._frames) do
        if f:GetObjectType() == "ModelScene" and f.busy then active = f end
    end
    assert(active:GetParent() == hub:GetParent() and active:GetFrameLevel() < hub:GetFrameLevel(), "F7: the model draws under the hub bezel")
    local twins = 0
    assert(ns.SlabEffects.LevelUp(hub, function() twins = twins + 1 end) == "2d", "F7: models are limited to one per 2.5 s")
    assert(twins == 1 and active.preempt:IsPlaying(), "F7: the old model fades and the level-up motif always plays")
    assert(active.preempt._anims[1]:GetDuration() == 0.15, "F7: pre-emption takes 150 ms")
    active.preempt:Finish()
    active.preempt:GetScript("OnFinished")()
    assert(not active:IsShown(), "F7: the outgoing model is released after its fade")
    env.RunTimers()
    env._time = 103
    assert(ns.SlabEffects.LevelUp(hub, function() twins = twins + 1 end) == "model" and twins == 2, "F7: the next model is admitted after the interval with its 2D motif")
    K.Options.Write("ActionBars", "bezelModels", false)
    env.RunTimers()
    assert(ns.SlabEffects.Proc(hub) == "model", "F7: disabling bezel models restores unrestricted models")
    assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
print("motion proc/input " .. (mode or "all") .. " ok")
