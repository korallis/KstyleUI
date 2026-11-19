-- layout_shown.lua: the shared Shown dropdown and its real ordinary/secure panels in a party, raid or solo.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
return Common.Run(function()
    local mode = os.getenv("RENDER_GROUP") or "party"
    assert(mode == "party" or mode == "raid" or mode == "solo")
    local env, K, ns = O.New(Common.ScreenOpts({ saved = Gallery.Saved({}), setup = Gallery.Setup }))
    env._group = mode
    local labels = { party = "In a party only", raid = "In a raid only", solo = "When solo only", noParty = "Not in a party", noRaid = "Not in a raid", noSolo = "In a group only" }
    for i, rule in ipairs({ "party", "raid", "solo", "noParty", "noRaid", "noSolo" }) do
        local panel = K.Widgets.Panel(K.Scale.Root(), { width = 240, height = 54, shape = "panel" })
        local title = K.Widgets.Text(panel, "body", "text")
        title:SetPoint("CENTER", panel, "CENTER")
        title:SetText(labels[rule])
        if i <= 3 then panel.IsProtected = function() return true end end
        K.Layout.Register(panel, "Shown." .. rule, { anchor = "BOTTOM", x = ((i - 1) % 3 - 1) * 260, y = i <= 3 and 110 or 40 }, { label = "Group visibility: " .. labels[rule], fields = { "shown" } })
        assert(K.Layout.Set("Shown." .. rule, "shown", rule))
    end
    assert(K.Options.Open("Elements"))
    assert(K.Layout.Update("Options.Window", { anchor = "TOP", x = 0, y = -24, scale = 0.9 }))
    local search = ns.Window.Parts().search
    search:SetText("Group visibility")
    search:GetScript("OnTextChanged")(search, true)
    env.FireEvent("GROUP_ROSTER_UPDATE")
    env.SetCombat(true)
    O.W.Settle(env)
    local err = Common.Errors(env, K)
    assert(not err, tostring(err))
    local scene = Gallery.Build(env)
    scene.log[#scene.log + 1] = "Shown rules in " .. mode .. ": three secure positive rules and three ordinary negations, in combat"
    return scene
end)
