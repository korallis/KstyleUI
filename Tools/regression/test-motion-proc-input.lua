-- test-motion-proc-input.lua: F3/F5/F7 motion boundaries and the previous-behaviour switches.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W
local mode = arg and arg[1]

if not mode or mode == "refresh" then
    local env, K, ns = AB.New({ class = "WARLOCK" })
    AB.Enable(env, K)
    env.RunTimers()
    AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
    env._game.procs[100] = true
    env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
    local b, hub = AB.Button(ns, "bar1", 1), ns.Slab.hub
    for _, polished in ipairs({ false, true }) do
        K.Options.Write("ActionBars", "procTransitions", polished)
        b.medProcStart.anim:Stop()
        hub.crest.pulse:Stop()
        hub.glyphs.flash:Stop()
        local proc, calls = ns.SlabEffects.Proc, 0
        ns.SlabEffects.Proc = function(...) calls = calls + 1; return proc(...) end
        K.Options.Write("ActionBars", "quietCooldown", not ns.Config("quietCooldown"))
        assert(not b.medProcStart.anim:IsPlaying() and not hub.crest.pulse:IsPlaying() and not hub.glyphs.flash:IsPlaying() and calls == 0, "F3: unrelated settings must not replay the proc start, hub pulse or model")
        K.Options.Write("Medallions", "motion", "calm")
        assert(not b.medProc.anim:IsPlaying(), "F3: effect-level changes still stop the proc loop")
        K.Options.Write("Medallions", "motion", "full")
        assert(b.medProc.anim:IsPlaying(), "F3: Full resumes the proc loop")
        assert(not b.medProcStart.anim:IsPlaying() and not hub.crest.pulse:IsPlaying() and not hub.glyphs.flash:IsPlaying() and calls == 0, "F3: effect-level changes must refresh the loop without replaying one-shot effects")
        ns.SlabEffects.Proc = proc
    end
    K.Options.Write("Medallions", "motion", "calm")
    K.Options.Write("ActionBars", "procTransitions", false)
    local left, right, top, bottom = b.medProc:GetTexCoord()
    assert(left == 0 and right == 0.25 and top == 0 and bottom == 0.25, "a stationary warlock proc holds one 4x4 cell even without transitions")
    K.Options.Write("ActionBars", "procTransitions", true)
    K.Options.Write("Medallions", "motion", "off")
    ns.Button.SetProc(b, false)
    assert(not b.medProcFrame.leave:IsPlaying() and not b.medProc:IsShown(), "Motion Off clears a proc without an exit fade")
    ns.Button.SetProc(b, true)
    assert(b.medProc:IsVisible() and not b.medProcFrame.enter:IsPlaying() and not b.medProc.anim:IsPlaying(), "Motion Off shows a steady proc immediately")
    assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

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
    assert(W.Near(b.statePressSpread, K.Widgets.Snap(b, 4)), "F5: the press halo spreads four units")
    local tween, durations = K.Motion.Tween, {}
    K.Motion.Tween = function(_, _, _, _, duration) durations[#durations + 1] = duration end
    local control = K.Widgets.Button(K.Scale.Root(), { text = "Press" })
    K.Widgets.Press(control, true)
    K.Widgets.Press(control, false)
    K.Motion.Tween = tween
    assert(durations[1] == K.Tokens.Duration("pressIn") and durations[2] == K.Tokens.Duration("pressOut"), "F5: Widgets.Press uses pressIn and pressOut")
    K.Options.Write("ActionBars", "inputContinuity", false)
    K.Motion.Tween = function(_, _, _, _, duration) durations[#durations + 1] = duration end
    K.Widgets.Press(control, false)
    K.Motion.Tween = tween
    assert(durations[3] == K.Tokens.Duration("hover"), "F5: disabling continuity restores Widgets.Press timing too")
    W.Enter(b); W.Leave(b)
    assert(not b.hoverLayer:IsShown(), "F5: disabling continuity restores the immediate early hover exit")
    assert(W.Near(b.statePressSpread, K.Widgets.Snap(b, 6)), "F5: disabling continuity restores the six-unit press halo")
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
    assert(W.Near(b.stateProcSpread, K.Widgets.Snap(b, 5.6)), "F3: proc halo spreads 5.6 units")
    ns.Button.SetProc(b, false)
    b:FlashReady()
    assert(b.readyAttack:GetDuration() == 0.06 and b.readyFade:GetDuration() == 0.18, "F3: ready attacks in 60 ms and decays in 180 ms")
    assert(b.readyAttack:GetToAlpha() == 0.45 and b.readyFade:GetFromAlpha() == 0.45, "F3: the steel ready wash peaks at 0.45")
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
