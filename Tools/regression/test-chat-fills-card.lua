-- test-chat-fills-card.lua: ChatFrame1 fills the chat card's inner rect, and stays there after Blizzard resizes it, after a resolution change and when the player resizes the card.
local C = dofile("Tools/regression/chat_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 3840, 1080 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local TAB_ROW, TAB_TEXT_RISE, BUTTON = 34, 14, 20

local function rect(env, K, frame)
	return assert(Geometry.ScaledRect(frame, env.UIParent, K.Scale.Root()))
end

-- Check(env, K, ns, label) fails when an edge of ChatFrame1 is more than one physical pixel from the card's inner edge: the
-- card's padding on the left, right and bottom, the tab row on top, and the edit box's strip when the player keeps it shown.
local function Check(env, K, ns, label)
	local chat = env.ChatFrame1
	local card = rect(env, K, ns.Panel.Holder())
	local pad = ns.Panel.Glass().chrome:Inset("gapMedium")
	local k = chat:GetEffectiveScale() / K.Scale.Root():GetEffectiveScale()
	local want = {
		left = card.left + pad,
		right = card.right - pad,
		top = card.top - math.max(TAB_ROW, TAB_TEXT_RISE * k + BUTTON / 2),
		bottom = card.bottom + pad,
	}
	if K.Store.Module("Chat").editBox == "always" then
		want.bottom = want.bottom + (2 + 32) * k - math.max(0, (32 * k - 22) / 2)
	end
	local got = rect(env, K, chat)
	local pixel = K.Scale.Pixel(1)
	for edge, value in pairs(want) do
		assert(math.abs(got[edge] - value) <= pixel + 1e-6, string.format("%s: ChatFrame1's %s edge is %.2f units from the card's inner %s edge (one pixel is %.2f)", label, edge, got[edge] - value, edge, pixel))
	end
	local bar = rect(env, K, chat.ScrollBar)
	assert(math.abs(bar.right - want.right) <= pixel + 1e-6, label .. ": the scroll bar ends on the card's inner right edge")
	local box = rect(env, K, chat.editBox)
	assert(math.abs(box.left + 5 * k - want.left) <= pixel + 1e-6 and math.abs(box.right - 8 * k - want.right) <= pixel + 1e-6, label .. ": the edit box shares the window's side edges")
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
end

-- Blizzard's own resizing runs after KstyleUI's: Edit Mode's UpdateSystem (the saved 430 by 120 window, one anchor) and
-- FloatingChatFrame_Update's FCF_RestorePositionAndDimensions for every window. The next frame brings the window back.
local function Blizzard(env)
	env.EditModeUpdateSystem()
	for _, frame in ipairs({ env.ChatFrame1, env.ChatFrame2, env.ChatFrame3 }) do
		env.FCF_RestorePositionAndDimensions(frame)
	end
end

for _, scale in ipairs({ 768 / 1080, 1 }) do
	for _, screen in ipairs(SCREENS) do
		local env, K, ns = C.New({ width = screen[1], height = screen[2], uiScale = scale })
		C.Enable(env, K)
		local label = string.format("%dx%d at UI scale %.3f", screen[1], screen[2], scale)
		Check(env, K, ns, label .. " after login")
		assert(env.ChatFrame1:GetNumPoints() == 2, label .. ": two anchors on the card")

		Blizzard(env)
		env.RunTimers()
		Check(env, K, ns, label .. " after Blizzard resized it")

		for _, other in ipairs({ { 1920, 1080 }, screen }) do
			env.GetPhysicalScreenSize = function() return other[1], other[2] end
			env.UIParent:SetSize(768 * other[1] / other[2] / scale, 768 / scale)
			env.FireEvent("DISPLAY_SIZE_CHANGED")
			Blizzard(env)
			env.RunTimers()
			Check(env, K, ns, label .. " after a change to " .. other[1] .. "x" .. other[2])
		end

		for _, size in ipairs({ 0.6, 16 / 19, 1.25 }) do
			K.Scale.SetUserScale(size)
			Blizzard(env)
			env.RunTimers()
			Check(env, K, ns, label .. string.format(" at size %.3f", size))
		end

		K.Layout.Set("chat.main", "width", 300)
		K.Layout.Set("chat.main", "height", 240)
		env.RunTimers()
		local card = rect(env, K, ns.Panel.Holder())
		assert(math.abs(card.right - card.left - 300) < 1 and math.abs(card.top - card.bottom - 240) < 1, label .. ": the card follows the player's size")
		Check(env, K, ns, label .. " after the player resized the card")

		K.Options.Write("Chat", "editBox", "always")
		Blizzard(env)
		env.RunTimers()
		Check(env, K, ns, label .. " with the edit box always shown")
	end
end

-- The edit box opens inside the card over every docked window's last lines, and Blizzard's own anchors come back when the module turns off.
do
	local env, K = C.New()
	C.Enable(env, K)
	for _, frame in ipairs({ env.ChatFrame1, env.ChatFrame2 }) do
		local p, rel, relp, x, y = frame.editBox:GetPoint(1)
		assert(p == "TOPLEFT" and rel == frame and relp == "BOTTOMLEFT" and x == -5 and y > 0, frame:GetName() .. "'s box opens over the window's foot, got " .. tostring(y))
	end
	K.Modules.Disable("Chat")
	env.RunTimers()
	for _, frame in ipairs({ env.ChatFrame1, env.ChatFrame2 }) do
		local p, rel, relp, x, y = frame.editBox:GetPoint(1)
		local p2, rel2, relp2, x2, y2 = frame.editBox:GetPoint(2)
		assert(p == "TOPLEFT" and rel == frame and relp == "BOTTOMLEFT" and x == -5 and y == -2, frame:GetName() .. "'s box is under the window again")
		assert(p2 == "RIGHT" and rel2 == frame.ScrollBar and relp2 == "RIGHT" and x2 == 8 and y2 == 0, frame:GetName() .. "'s box ends 8 past the scroll bar again")
	end
end

print("chat fills card ok")
