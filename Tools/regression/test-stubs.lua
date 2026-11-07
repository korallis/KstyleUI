-- test-stubs.lua: the stub WoW environment behaves as later tests expect.
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local function raises(fn, message)
	local ok, err = pcall(fn)
	assert(not ok, "expected an error containing: " .. message)
	assert(tostring(err):find(message, 1, true), "wrong error: " .. tostring(err))
end

-- The plan's contract.
local env = Stubs.NewEnv({ width = 3840, height = 2160 })
local f = env.CreateFrame("Frame", "TestFrame", env.UIParent)
f:SetSize(10, 20)
assert(f._calls[1].method == "SetSize" and f._calls[1].args[2] == 20)
assert(select(2, env.GetPhysicalScreenSize()) == 2160)
local ran = false
env.C_Timer.After(0, function() ran = true end)
assert(not ran); env.RunTimers(); assert(ran)
assert(env.issecretvalue(env.Secret(5)) and not env.issecretvalue(5))
f:RegisterEvent("PLAYER_LOGIN")
local got
f:SetScript("OnEvent", function(_, e) got = e end)
env.FireEvent("PLAYER_LOGIN"); assert(got == "PLAYER_LOGIN")

-- Frames keep simple state and resolve globals, parents and scales.
assert(env.TestFrame == f and f:GetName() == "TestFrame" and f:GetObjectType() == "Frame")
assert(f:GetWidth() == 10 and f:GetHeight() == 20 and f:GetParent() == env.UIParent)
f:SetScale(2)
assert(f:GetEffectiveScale() == 2 * env.UIParent:GetEffectiveScale())
assert(f:IsShown()); f:Hide(); assert(not f:IsShown())
f:SetAlpha(0.5); assert(f:GetAlpha() == 0.5)
assert(env.CreateFrame("Frame"):GetAlpha() == 1)
local tex = f:CreateTexture(nil, "ARTWORK")
assert(tex:GetObjectType() == "Texture" and tex:GetParent() == f)
f:SetPoint("CENTER", env.UIParent, "CENTER", 1, 2)
assert(f:GetNumPoints() == 1 and select(5, f:GetPoint(1)) == 2)
f:ClearAllPoints(); assert(f:GetNumPoints() == 0)

-- Frames answer only the widget methods Forever documents. Any other key reads as nil, as in the game,
-- so "if not f.Title then" works and a call to a method Forever lacks fails the test.
assert(f.Title == nil and f.CloseButton == nil, "a field that is not a widget method must read as nil")
assert(f.SetBackdrop == nil, "SetBackdrop comes from BackdropTemplate, not the widget API")
raises(function() f:SetBackdrop({}) end, "SetBackdrop")
f.Title = f:CreateFontString(nil, "OVERLAY")
assert(f.Title:GetObjectType() == "FontString" and f.Title:GetParent() == f)
local before = #f._calls
f:SetAlphaFromBoolean(true)
assert(f._calls[before + 1].method == "SetAlphaFromBoolean", "documented methods without stub logic still record")

-- Only registered frames get events, and unit events honour their unit filter.
local units = {}
local u = env.CreateFrame("Frame")
u:RegisterUnitEvent("UNIT_HEALTH", "player")
u:SetScript("OnEvent", function(_, _, unit) units[#units + 1] = unit end)
env.FireEvent("UNIT_HEALTH", "target"); env.FireEvent("UNIT_HEALTH", "player")
assert(#units == 1 and units[1] == "player")
u:UnregisterEvent("UNIT_HEALTH"); env.FireEvent("UNIT_HEALTH", "player"); assert(#units == 1)

-- Combat state follows SetCombat and fires the regen events.
assert(env.InCombatLockdown() == false)
local regen, lockedInHandler
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:SetScript("OnEvent", function(_, e) regen, lockedInHandler = e, env.InCombatLockdown() end)
env.SetCombat(true)
assert(env.InCombatLockdown() == true and regen == "PLAYER_REGEN_DISABLED")
assert(lockedInHandler == false, "PLAYER_REGEN_DISABLED fires before lockdown starts")
env._combat = false
assert(env.InCombatLockdown() == false, "InCombatLockdown reads env._combat")

-- hooksecurefunc runs the hook after the original, for globals and for methods.
local order = {}
env.Original = function(x) order[#order + 1] = "orig" .. x end
env.hooksecurefunc("Original", function(x) order[#order + 1] = "hook" .. x end)
env.Original(1)
assert(order[1] == "orig1" and order[2] == "hook1")
env.hooksecurefunc(f, "Show", function() order[#order + 1] = "shown" end)
f:Show(); assert(f:IsShown() and order[3] == "shown")

-- A secret value raises on comparison, arithmetic and length, and passes through widget setters.
local s, s2 = env.Secret(5), env.Secret(6)
raises(function() return s < s2 end, "attempt to compare a secret value")
raises(function() return s <= s2 end, "attempt to compare a secret value")
raises(function() return s == s2 end, "attempt to compare a secret value")
raises(function() return s + 1 end, "attempt to perform arithmetic on a secret value")
raises(function() return 1 - s end, "attempt to perform arithmetic on a secret value")
raises(function() return s * 2 end, "attempt to perform arithmetic on a secret value")
raises(function() return s / 2 end, "attempt to perform arithmetic on a secret value")
raises(function() return s % 2 end, "attempt to perform arithmetic on a secret value")
raises(function() return s ^ 2 end, "attempt to perform arithmetic on a secret value")
raises(function() return -s end, "attempt to perform arithmetic on a secret value")
raises(function() return #s end, "attempt to perform arithmetic on a secret value")
raises(function() return s < 5 end, "attempt to compare")
raises(function() return s.field end, "attempt to index a secret value")
raises(function() s.field = 1 end, "attempt to index a secret value")
local bar = env.CreateFrame("StatusBar")
bar:SetValue(s)
assert(env.Reveal(bar:GetValue()) == 5)

-- As in the game, type() sees through a secret, and concatenation makes a new secret string.
assert(env.type(s) == "number" and env.type(env.Secret("Hogger")) == "string")
assert(env.type(5) == "number" and env.type(f) == "table" and env.type(nil) == "nil")
local label = "HP " .. s .. "%"
assert(env.issecretvalue(label) and env.Reveal(label) == "HP 5%")

-- Frame levels start one above the parent, and a frame lists the frames and regions made on it.
local parent = env.CreateFrame("Frame", nil, env.UIParent)
assert(env.UIParent:GetFrameLevel() == 0 and parent:GetFrameLevel() == 1, "a frame starts one level above its parent")
parent:SetFrameLevel(7)
local kid = env.CreateFrame("Button", nil, parent)
assert(kid:GetFrameLevel() == 8, "a child starts one level above its parent")
local made = parent:CreateTexture(nil, "ARTWORK")
local text = parent:CreateFontString(nil, "OVERLAY")
local regions = { parent:GetRegions() }
assert(#regions == 2 and regions[1] == made and regions[2] == text, "GetRegions lists the textures and font strings made on the frame")
local kids = { parent:GetChildren() }
assert(#kids == 1 and kids[1] == kid, "GetChildren lists the frames made with the frame as parent")
assert(made:GetObjectType() == "Texture" and made:GetParent() == parent)

-- Buttons are enabled until Disable, and Enable and Disable run the frame's scripts.
local seen = {}
kid:SetScript("OnDisable", function() seen[#seen + 1] = "off" end)
kid:SetScript("OnEnable", function() seen[#seen + 1] = "on" end)
assert(kid:IsEnabled() == true)
kid:Disable(); assert(kid:IsEnabled() == false and seen[1] == "off")
kid:SetEnabled(true); assert(kid:IsEnabled() == true and seen[2] == "on")
kid:Enable(); assert(#seen == 2, "enabling an enabled button runs no script")

-- A status bar's fill is a texture region, as in the game.
local sb = env.CreateFrame("StatusBar")
sb:SetStatusBarTexture("Interface\\Bar")
local fillTexture = sb:GetStatusBarTexture()
assert(type(fillTexture) == "table" and fillTexture:GetObjectType() == "Texture" and fillTexture:GetTexture() == "Interface\\Bar")
sb:SetStatusBarTexture("Interface\\Other")
assert(sb:GetStatusBarTexture() == fillTexture, "the same region keeps the new texture")

-- Environments do not share state, and builtins come from _G.
local other = Stubs.NewEnv()
assert(other.TestFrame == nil and select(2, other.GetPhysicalScreenSize()) == 1080)
assert(other.InCombatLockdown() == false and other.print == print)

print("stubs ok")
