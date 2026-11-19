-- test-layout-groups.lua: shared group visibility, including secure combat transitions, sparse defaults and queued edits.
local O = dofile("Tools/regression/options_env.lua")
local rules = { "party", "raid", "solo", "noParty", "noRaid", "noSolo" }
local drivers = {
    party = "[group:raid] hide; [group:party] show; hide", raid = "[group:raid] show; hide", solo = "[group] hide; show",
    noParty = "[group:raid] show; [group:party] hide; show", noRaid = "[group:raid] hide; show", noSolo = "[group] show; hide",
}
local function expected(rule, group)
    if rule == "party" then return group == "party" end
    if rule == "raid" then return group == "raid" end
    if rule == "solo" then return group == "solo" end
    if rule == "noParty" then return group ~= "party" end
    if rule == "noRaid" then return group ~= "raid" end
    return group ~= "solo"
end
for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
    local env, K, ns = O.New({ width = screen[1], height = screen[2] })
    local Layout = K.Layout
    local function rosterListeners()
        local count = 0
        for _, frame in ipairs(env._frames) do
            if frame:IsEventRegistered("GROUP_ROSTER_UPDATE") then count = count + 1 end
        end
        return count
    end
    local baselineListeners = rosterListeners()
    local frames = {}
    for i, template in ipairs({ false, "SecureHandlerStateTemplate" }) do
        local frame = env.CreateFrame("Frame", nil, K.Scale.Root(), template or nil)
        if template then frame.IsProtected = function() return true end end
        frame:SetSize(180, 40)
        frames[i] = frame
        Layout.Register(frame, "Group." .. i, { anchor = "CENTER", x = i * 200, y = 40 }, { label = "Group " .. i })
        assert(Layout.Get("Group." .. i).shown == "always" and not env.Driver(frame, "visibility"))
        assert(K.Store.Layout()["Group." .. i] == nil, "default registration writes no saved setting or place")
        if i == 2 then
            for _, method in ipairs({ "Show", "Hide", "SetPoint", "SetAttribute" }) do
                local original = frame[method]
                frame[method] = function(self, ...)
                    assert(not env._combat or env._secure, method .. " must run through the secure driver in combat")
                    return original(self, ...)
                end
            end
        end
    end
    for _, name in ipairs({ "RegisterStateDriver", "UnregisterStateDriver" }) do
        local original = env[name]
        env[name] = function(...)
            assert(not env._combat, name .. " must wait for Combat.Queue")
            return original(...)
        end
    end
    local function group(value)
        env._group = value
        if value == "raid" then
            assert(env.SecureCmdOptionParse("[group:party] match; no") == "match", "group:party also matches a raid; party-only drivers must exclude raids first")
        end
        env.FireEvent("GROUP_ROSTER_UPDATE")
        env.RunStateDrivers()
    end
    assert(Layout.Set("Group.2", "shown", "party"))
    assert(rosterListeners() == baselineListeners, "secure group rules rely on the driver only")
    assert(Layout.Set("Group.2", "shown", nil))
    for _, rule in ipairs(rules) do
        assert(Layout.Rules.IsRule(rule) and Layout.Rules.NeedsGroup(rule))
        for i, frame in ipairs(frames) do
            assert(Layout.Set("Group." .. i, "shown", rule))
            assert(env.Driver(frame, "visibility") == (i == 2 and drivers[rule] or nil))
        end
        assert(rosterListeners() == baselineListeners + 1, "ordinary group rules share one roster listener")
        for _, combat in ipairs({ false, true }) do
            env.SetCombat(combat)
            for _, mode in ipairs({ "solo", "party", "raid", "party", "solo" }) do
                group(mode)
                for _, frame in ipairs(frames) do
                    assert(frame:IsShown() == expected(rule, mode), rule .. " in " .. mode)
                end
                if not expected(rule, mode) then
                    frames[1]:Show()
                    frames[1]:GetScript("OnShow")(frames[1])
                    assert(not frames[1]:IsShown(), "module Show cannot override the rule")
                end
            end
        end
        local old = env.Driver(frames[2], "visibility")
        assert(Layout.Set("Group.2", "shown", "never"))
        assert(env.Driver(frames[2], "visibility") == old, "a combat edit keeps the installed driver")
        env.SetCombat(false)
        assert(env.Driver(frames[2], "visibility") == "hide" and not frames[2]:IsShown())
        for i, frame in ipairs(frames) do
            assert(Layout.Set("Group." .. i, "shown", nil))
            assert(frame:IsShown() and not env.Driver(frame, "visibility"), "reset removes the rule and restores visibility")
            assert(K.Store.Layout()["Group." .. i] == nil, "reset leaves no saved record")
        end
    end
    assert(rosterListeners() == baselineListeners, "reset releases the roster event")
    local parse = env.SecureCmdOptionParse
    env.SecureCmdOptionParse = function() return env.Secret("party") end
    assert(Layout.Set("Group.1", "shown", "party"))
    assert(frames[1]:IsShown(), "a secret macro result keeps the element accessible")
    env.SecureCmdOptionParse = nil
    env.FireEvent("GROUP_ROSTER_UPDATE")
    assert(frames[1]:IsShown(), "a missing parser keeps the element accessible")
    env.SecureCmdOptionParse = parse
    assert(Layout.Set("Group.1", "shown", nil))
    assert(K.Options.Open("Elements"))
    local row = O.Find(ns.Window.State().items, function(item) return item.element == "Group.1" and item.label == "Shown" end)
    assert(row and row.get() == "always")
    for _, rule in ipairs(rules) do
        assert(O.Find(row.options, function(choice) return choice.value == rule end), "shared dropdown offers " .. rule)
        row.set(rule)
        assert(Layout.Get("Group.1").shown == rule)
    end
    row.set("never")
    assert(not frames[1]:IsShown())
    row.set("always")
    assert(frames[1]:IsShown() and K.Store.Layout()["Group.1"] == nil)
    assert(#env._errors == 0, table.concat(env._errors, "\n"))
end
print("layout group visibility ok at all four screen sizes")
