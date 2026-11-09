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
local ticks = 0
local ticker = env.C_Timer.NewTicker(1, function() ticks = ticks + 1 end)
assert(ticks == 0); env.RunTickers(); env.RunTickers(); assert(ticks == 2, "RunTickers runs each live ticker once")
assert(not ticker:IsCancelled()); ticker:Cancel(); assert(ticker:IsCancelled())
env.RunTickers(); assert(ticks == 2, "a cancelled ticker never runs again")
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
f:SetIgnoreParentScale(true)
assert(f:IsIgnoringParentScale() and f:GetEffectiveScale() == 2, "a frame ignoring its parent's scale draws at its own")
f:SetIgnoreParentScale(false)
assert(not f:IsIgnoringParentScale() and f:GetEffectiveScale() == 2 * env.UIParent:GetEffectiveScale())
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

-- A region remembers the draw layer it was made in, and a texture lists its masks in order.
local layered = parent:CreateTexture(nil, "ARTWORK", nil, 3)
local l, sub = layered:GetDrawLayer()
assert(l == "ARTWORK" and sub == 3, "CreateTexture keeps its layer and sublevel")
local flat = parent:CreateTexture()
assert(flat:GetDrawLayer() == nil, "no layer given reads as nil")
layered:SetDrawLayer("OVERLAY", 1)
assert(select(1, layered:GetDrawLayer()) == "OVERLAY", "SetDrawLayer replaces it")
local mask1, mask2 = parent:CreateMaskTexture(), parent:CreateMaskTexture()
assert(layered:GetNumMaskTextures() == 0 and layered:GetMaskTexture(1) == nil)
layered:AddMaskTexture(mask1)
layered:AddMaskTexture(mask2)
assert(layered:GetNumMaskTextures() == 2 and layered:GetMaskTexture(1) == mask1 and layered:GetMaskTexture(2) == mask2)
layered:RemoveMaskTexture(mask1)
assert(layered:GetNumMaskTextures() == 1 and layered:GetMaskTexture(1) == mask2)

-- Macro options, as SecureCmdOptionParse reads them.
do
	local e = Stubs.NewEnv()
	assert(e.SecureCmdOptionParse("[combat] show; hide") == "hide")
	e._combat = true
	assert(e.SecureCmdOptionParse("[combat] show; hide") == "show")
	assert(e.SecureCmdOptionParse("[nocombat] a; b") == "b")
	assert(e.SecureCmdOptionParse("[@target,exists] show; hide") == "hide")
	e._target = true
	assert(e.SecureCmdOptionParse("[target=target,exists] show; hide") == "show")
	assert(e.SecureCmdOptionParse("[noexists] a; [combat] b; c") == "b", "the first clause that holds wins")
	assert(e.SecureCmdOptionParse("[nocombat] a") == nil, "no clause holds and no default: nil")
	assert(e.SecureCmdOptionParse("[nocombat][exists] a; b") == "a", "any of several groups may hold")
end

-- State drivers resolve when registered and after combat or target changes, from secure code.
do
	local e = Stubs.NewEnv()
	local frame = e.CreateFrame("Frame")
	local secureShows = {}
	local show = frame.Show
	frame.Show = function(self)
		secureShows[#secureShows + 1] = e._secure == true
		return show(self)
	end
	e.RegisterStateDriver(frame, "visibility", "[combat] show; hide")
	assert(frame:IsShown() == false and frame:GetAttribute("statehidden") == true, "a visibility driver hides at once")
	assert(e.Driver(frame, "visibility") == "[combat] show; hide")
	e.SetCombat(true)
	assert(frame:IsShown() == true and frame:GetAttribute("statehidden") == nil, "and shows in combat")
	assert(secureShows[1] == true, "from secure code")
	e.SetCombat(false)
	assert(frame:IsShown() == false)
	e.RegisterStateDriver(frame, "page", "[@target,exists] 2; 1")
	assert(frame:GetAttribute("state-page") == 1, "other states set an attribute")
	e.SetTarget(true)
	assert(frame:GetAttribute("state-page") == 2, "SetTarget rescans")
	e.UnregisterStateDriver(frame, "visibility")
	assert(e.Driver(frame, "visibility") == nil)
	e.SetCombat(true)
	assert(frame:IsShown() == false, "an unregistered driver no longer runs")
	e.RegisterStateDriver(frame, "page", "")
	assert(e.Driver(frame, "page") == nil, "empty options unregister, as in the game")
end

-- The cursor, the modifier keys, the target and IsMouseOver.
do
	local e = Stubs.NewEnv()
	e._cursor = { 12, 34 }
	local x, y = e.GetCursorPosition()
	assert(x == 12 and y == 34)
	assert(e.IsShiftKeyDown() == false and e.IsControlKeyDown() == false)
	e._modifiers.shift = true
	assert(e.IsShiftKeyDown() == true)
	assert(e.UnitExists("player") == true and e.UnitExists("target") == false)
	local heard
	local frame = e.CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:SetScript("OnEvent", function(_, event) heard = event end)
	e.SetTarget(true)
	assert(e.UnitExists("target") == true and heard == "PLAYER_TARGET_CHANGED")
	assert(frame:IsMouseOver() == false)
	frame._mouseOver = true
	assert(frame:IsMouseOver() == true)
end

-- Environments do not share state, and builtins come from _G.
local other = Stubs.NewEnv()
assert(other.TestFrame == nil and select(2, other.GetPhysicalScreenSize()) == 1080)
assert(other.InCombatLockdown() == false and other.print == print)

-- xpcall passes extra arguments to the function, as Forever's does, on Lua 5.1 too.
do
	local e = Stubs.NewEnv()
	local ok, sum = e.xpcall(function(a, b)
		return a + b
	end, error, 2, 3)
	assert(ok == true and sum == 5, "xpcall passes its extra arguments")
	local handled
	local failed, result = e.xpcall(function(value)
		error("bad " .. value, 0)
	end, function(message)
		handled = message
		return "handled"
	end, "input")
	assert(failed == false and result == "handled" and handled == "bad input", "an error goes to the handler")
end

-- Quiet mode, for the performance check: frames stop recording calls, a method lookup returns the same
-- function each time, and a repeated Set<X> reuses its stored table, so the stubs allocate nothing.
do
	local Measure = dofile("Tools/regression/measure.lua")
	local e = Stubs.NewEnv()
	local q = e.CreateFrame("Frame", nil, e.UIParent)
	q:SetAlpha(0.2)
	local recorded = #q._calls
	e.SetQuiet(true)
	assert(q.SetAlpha == q.SetAlpha and q.Show == q.Show, "a quiet lookup returns the same function")
	q:SetAlpha(0.4)
	q:SetSize(3, 4)
	assert(#q._calls == recorded, "a quiet frame records no calls")
	assert(q:GetAlpha() == 0.4 and q:GetWidth() == 3, "quiet methods still keep state")
	q:SetVertexColor(1, 0.5, 0, 0.25)
	q:SetVertexColor(0.1, 0.2, 0.3)
	local r, g, b, a = q:GetVertexColor()
	assert(r == 0.1 and g == 0.2 and b == 0.3 and a == nil, "a shorter Set<X> clears the values it no longer sets")
	local result = Measure.Run(function()
		q:SetAlpha(0.5)
		q:Show()
		q:SetVertexColor(0.3, 0.2, 0.1)
		q:GetAlpha()
	end)
	assert(result.kb == 0, "quiet stubs allocate nothing, got " .. result.kb .. " KB per call")

	-- Anchors: a quiet frame reuses its point tables, and the points read back as set.
	result = Measure.Run(function()
		q:ClearAllPoints()
		q:SetPoint("TOPLEFT", e.UIParent, "TOPLEFT", 1, 2)
		q:SetPoint("BOTTOMRIGHT", e.UIParent, "BOTTOMRIGHT", -3, 4)
		q:SetPoint("TOPLEFT", e.UIParent, "TOPLEFT", 5, 6)
	end)
	assert(result.kb == 0, "quiet anchors allocate nothing, got " .. result.kb .. " KB per call")
	local point, relative, relativePoint, x, y = q:GetPoint(1)
	assert(q:GetNumPoints() == 2 and point == "TOPLEFT" and relative == e.UIParent and relativePoint == "TOPLEFT" and x == 5 and y == 6, "a repeated anchor replaces the first")
	assert(select(5, q:GetPoint(2)) == 4, "the second anchor keeps its own values")
	q:ClearAllPoints()
	q:SetPoint("CENTER")
	assert(q:GetNumPoints() == 1 and select(2, q:GetPoint(1)) == nil, "a reused point table holds no stale values")

	-- Secrets: in quiet mode one value gives one secret, so a fake that returns a secret allocates nothing.
	assert(rawequal(e.Secret(7), e.Secret(7)) and e.Reveal(e.Secret(7)) == 7, "a quiet secret is shared per value")
	assert(e.issecretvalue(e.Secret(nil)) and e.Reveal(e.Secret(nil)) == nil, "a secret nil still works")
	result = Measure.Run(function()
		e.Secret(7)
		e.Secret(nil)
	end)
	assert(result.kb == 0, "quiet secrets allocate nothing, got " .. result.kb .. " KB per call")

	-- Timers: scheduling and running a timer reuses the timer lists.
	local runs = 0
	local tick = function()
		runs = runs + 1
	end
	result = Measure.Run(function()
		e.C_Timer.After(0, tick)
		e.RunTimers()
	end)
	assert(result.kb == 0 and runs > 0, "timers allocate nothing, got " .. result.kb .. " KB per call")

	e.SetQuiet(false)
	q:SetAlpha(0.6)
	assert(#q._calls == recorded + 1 and q:GetAlpha() == 0.6, "leaving quiet mode records calls again")
	assert(not rawequal(e.Secret(7), e.Secret(7)), "outside quiet mode each secret is new")
end

-- Fonts: as in the game, text on a FontString with no font raises "Font not set". A template,
-- SetFont or SetFontObject gives it a font. Other widgets' SetText is unaffected.
do
	local e = Stubs.NewEnv()
	local holder = e.CreateFrame("Frame", nil, e.UIParent)
	local bare = holder:CreateFontString(nil, "OVERLAY")
	raises(function() bare:SetText("N") end, "FontString:SetText(): Font not set")
	raises(function() bare:SetFormattedText("%d", 1) end, "FontString:SetFormattedText(): Font not set")
	bare:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	bare:SetText("N")
	assert(bare:GetText() == "N", "SetFont gives the text a font")

	local inherited = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	inherited:SetText("a")
	local font = e.CreateFont("TestFont")
	assert(e.TestFont == font and font:GetObjectType() == "Font", "CreateFont makes a named Font object")
	local adopted = holder:CreateFontString(nil, "OVERLAY")
	adopted:SetFontObject(font)
	adopted:SetFormattedText("%d", 2)

	local button = e.CreateFrame("Button", nil, holder)
	button:SetText("b")
	local edit = e.CreateFrame("EditBox", nil, holder)
	edit:SetText("c")

	local Measure = dofile("Tools/regression/measure.lua")
	local late = holder:CreateFontString(nil, "OVERLAY")
	e.SetQuiet(true)
	raises(function() late:SetText("x") end, "FontString:SetText(): Font not set")
	adopted:SetText("warm")
	local result = Measure.Run(function()
		adopted:SetText("y")
	end)
	assert(result.kb == 0, "quiet SetText allocates nothing, got " .. result.kb .. " KB per call")
	assert(adopted:GetText() == "y", "quiet SetText keeps the text")
	e.SetQuiet(false)
end

-- Anchoring: a protected frame (made from a Secure template) may not anchor to a region, or to a frame
-- whose anchors lead to one. SetAllPoints anchors both corners, and GetRect reads _rect or the size.
do
	local e = Stubs.NewEnv()
	local holder = e.CreateFrame("Frame", nil, e.UIParent)
	local zone = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	local hit = e.CreateFrame("Button", nil, holder)
	hit:SetAllPoints(zone)
	assert(hit:GetNumPoints() == 2 and select(2, hit:GetPoint(1)) == zone, "SetAllPoints anchors to the target")
	local secure = e.CreateFrame("Button", nil, e.UIParent, "SecureActionButtonTemplate")
	raises(function() secure:SetAllPoints(zone) end, "Cannot anchor protected frames to regions")
	raises(function() secure:SetAllPoints(hit) end, "Cannot anchor protected frames to regions")
	raises(function() secure:SetPoint("TOPLEFT", hit, "TOPLEFT") end, "Cannot anchor protected frames to regions")
	local plain = e.CreateFrame("Button", nil, holder)
	plain:SetPoint("CENTER", holder, "CENTER")
	secure:SetAllPoints(plain)
	secure:SetPoint("BOTTOMLEFT", e.UIParent, "BOTTOMLEFT", 10, 20)
	local open = e.CreateFrame("Button", nil, holder)
	open:SetAllPoints(hit)
	assert(open:GetNumPoints() == 2, "an unprotected frame may anchor anywhere")
	plain:SetSize(30, 40)
	local rl, rb, rw, rh = plain:GetRect()
	assert(rl == 0 and rb == 0 and rw == 30 and rh == 40, "GetRect falls back to the size")
	plain._rect = { 5, 6, 7, 8 }
	assert(select(4, plain:GetRect()) == 8, "GetRect reads _rect")
	assert(e.CreateFrame("Frame"):GetRect() == nil, "no size, no rect")
end

-- GetLeft, GetRight, GetTop, GetBottom and GetCenter answer in the region's own scaled units, as the game does:
-- a frame's edge times its effective scale is the screen position, so a frame at scale 2 reads half the root's
-- numbers for the same spot (Blizzard_SharedTalentFrame.lua: cursorX - self:GetLeft() * scale).
do
	local e = Stubs.NewEnv({ width = 1920, height = 1080 })
	local root = e.UIParent
	local holder = e.CreateFrame("Frame", nil, root)
	holder:SetSize(100, 50)
	holder:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 200, 100)
	assert(holder:GetLeft() == 200 and holder:GetBottom() == 100 and holder:GetRight() == 300 and holder:GetTop() == 150, "a frame at the root's scale reads root units")
	local box = e.CreateFrame("Frame", nil, holder)
	box:SetSize(100, 50)
	box:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	box:SetScale(2)
	assert(box:GetLeft() == 100 and box:GetBottom() == 50, "a frame at scale 2 on the same spot reads half the root's numbers: " .. tostring(box:GetLeft()) .. ", " .. tostring(box:GetBottom()))
	assert(box:GetRight() == 200 and box:GetTop() == 100, "and its size in its own units: " .. tostring(box:GetRight()) .. ", " .. tostring(box:GetTop()))
	local cx, cy = box:GetCenter()
	assert(cx == 150 and cy == 75, "the centre too: " .. tostring(cx) .. ", " .. tostring(cy))
	assert(box:GetLeft() * box:GetEffectiveScale() == holder:GetLeft() * holder:GetEffectiveScale(), "edge times effective scale is the screen position")
	local child = e.CreateFrame("Frame", nil, box)
	child:SetSize(10, 10)
	child:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 5, 5)
	assert(child:GetLeft() == 105 and child:GetBottom() == 55, "a child shares its parent's scale and reads in it: " .. tostring(child:GetLeft()))
	assert(child:GetRight() == 115 and child:GetTop() == 65, "its size reads in that scale too")
end

print("stubs ok")
