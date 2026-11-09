-- test-groupframes-preview.lua: the settings window's live preview draws sample party and raid frames with the real look, follows setting changes on Refresh, and needs no unit or event.
local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local env, K = G.New()
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(300, 420)

local build = K.Options.Preview("GroupFrames")
assert(type(build) == "function", "GroupFrames gives the settings window a preview builder")
local events = 0
for _, frame in ipairs(env._frames) do
	if next(frame._events) then
		events = events + 1
	end
end
local preview = build(parent)
assert(type(preview) == "table" and preview.GetObjectType, "the builder returns a frame")
assert(type(preview.Refresh) == "function", "the preview refreshes after a setting changes")
eq(K.Modules.IsRunning("GroupFrames"), false, "the preview works with the module off")

local after = 0
for _, frame in ipairs(env._frames) do
	if next(frame._events) then
		after = after + 1
	end
end
eq(after, events, "the preview registers no events")

eq(#preview.partyFrames, 3, "three sample party frames")
eq(#preview.raidFrames, 10, "two sample raid groups")
eq(preview.partyFrames[1].name:GetText(), "Thaldren", "sample names")
K.Options.Write("GroupFrames", "party.healthText", "PERCENT")
preview:Refresh()
local formatted = preview.partyFrames[1].healthText._state.FormattedText
eq(formatted and formatted[1], "%d%%", "party samples show percent health when the number is on")
K.Options.Write("GroupFrames", "party.healthText", "NONE")
preview:Refresh()
eq(formatted and formatted[2], 92, "the sample's percent")
eq(preview.partyFrames[1]:GetWidth(), 278, "party samples use the party width")
eq(preview.raidFrames[1]:GetWidth(), 72, "raid samples use the raid width")

-- Samples show the status icons, the threat border and incoming heals.
local tank = preview.partyFrames[1]
eq(tank.role:IsShown(), true, "the sample tank shows a role icon")
eq(tank.threat:IsShown(), true, "the sample tank has aggro")
local glow = tank.threatGlow.slice[1]._state.VertexColor
local hr, hg, hb = K.Theme.ThreatColor(3)
assert(glow and glow[1] == hr and glow[2] == hg and glow[3] == hb, "in the tanking colour")
local found = false
for _, f in ipairs(preview.partyFrames) do
	found = found or (f.marker:IsShown() and f.marker._state.SpriteSheetCell ~= nil)
end
assert(found, "a sample shows a raid marker")
local healed = false
for _, f in ipairs(preview.partyFrames) do
	local v = f.heals._state.Value
	healed = healed or (v and type(v[1]) == "number" and v[1] > 0)
end
assert(healed, "a sample shows incoming heals")
eq(tank.sampleAuras[1]:IsShown(), true, "the sample tank shows debuff icons")
eq(tank.sampleAuras[3]:IsShown(), false, "only as many as it has")
eq(preview.partyFrames[2].sampleDispel:IsShown(), true, "a sample shows the dispel highlight")
eq(tank.auras, nil, "samples never make an AuraContainer")

-- A setting change shows on the next Refresh.
K.Options.Write("GroupFrames", "raid.width", 90)
K.Options.Write("GroupFrames", "party.healthText", "CURRENT_MAX")
preview:Refresh()
eq(preview.raidFrames[1]:GetWidth(), 90, "the raid width follows the setting")
formatted = preview.partyFrames[1].healthText._state.FormattedText
eq(formatted and formatted[1], "%d / %d", "the health text follows the setting")
K.Options.Write("GroupFrames", "party.portrait", false)
preview:Refresh()
eq(preview.partyFrames[1].portrait:IsShown(), false, "portraits follow the setting")

-- With no spacing, sample frames still sit edge to edge.
K.Options.Write("GroupFrames", "party.spacing", 0)
preview:Refresh()
local first, second = preview.partyFrames[1]._points[1], preview.partyFrames[2]._points[1]
eq(second[5] - first[5], -preview.partyFrames[1]:GetHeight(), "the second sample sits one frame lower with no gap")

-- The canvas scales down to fit a small pane.
parent:SetSize(100, 100)
preview:SetSize(100, 100)
preview:Refresh()
local scale = preview.canvas:GetScale()
assert(scale < 1, "the canvas scales down to fit, got " .. tostring(scale))
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

print("groupframes preview ok")
