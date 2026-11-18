-- motion_slots.lua: the real action slots at proc, hover-out and held-press boundaries, at 1080p.
local Common = dofile("Tools/render/scenes/_common.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")

return Common.Run(function()
    local previous = os.getenv("RENDER_INPUT_FINISH") == "previous"
    local env, K = AB.New({ setup = Common.ForceScreen })
    if K.Store.Defaults("ActionBars").procTransitions ~= nil then
        K.Options.Write("ActionBars", "procTransitions", not previous)
        K.Options.Write("ActionBars", "inputContinuity", not previous)
    end
    local root = K.Scale.Root()
    local slots = {}
    for i, text in ipairs({ "Proc entry", "Proc hold", "Proc exit", "Hover exit", "Held press", "Ready" }) do
        local b = K.Widgets.Slot(root, { size = 42, inputContinuity = not previous, procTransitions = not previous })
        b:SetPoint("CENTER", root, "CENTER", (i - 3.5) * 120, 0)
        b:SetIcon(136048)
        local label = K.Widgets.FontString(root, "OVERLAY")
        K.Widgets.StyleText(label, "caption")
        label:SetPoint("TOP", b, "BOTTOM", 0, -12)
        label:SetText(text)
        slots[i] = b
    end
    env._now = 0
    slots[1]:SetProc(true)
    env._now = -0.6
    slots[2]:SetProc(true)
    env._now = 0
    slots[3]:SetProc(true)
    if slots[3].lumenGlow.enter then slots[3].lumenGlow.enter:Stop() end
    slots[3]:SetProc(false)
    AB.W.Enter(slots[4]); AB.W.Leave(slots[4])
    AB.W.Down(slots[5])
    slots[5].press:Stop()
    slots[5].pressLayer:Hide()
    slots[6]:FlashReady()
    return Common.Scene.Build(env, { time = 0.06, iconDirs = Common.IconDirs() })
end)
