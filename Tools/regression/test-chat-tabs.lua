-- test-chat-tabs.lua: one tab design everywhere (KSTY-60 item 28): the settings window's live preview paints its tabs with the live chat's own tab look, in every tab style, and the gallery shows the default, the mock-up's gilt underline.
local C = dofile("Tools/regression/chat_env.lua")

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function same(a, b, what)
	local ar, ag, ab, aa = a:GetVertexColor()
	local br, bg, bb, ba = b:GetVertexColor()
	assert(near(ar, br) and near(ag, bg) and near(ab, bb) and near(aa or 1, ba or 1), what .. ": " .. table.concat({ tostring(ar), tostring(ag), tostring(ab) }, ",") .. " against " .. table.concat({ tostring(br), tostring(bg), tostring(bb) }, ","))
end

local function sameText(a, b, what)
	local ar, ag, ab = a:GetTextColor()
	local br, bg, bb = b:GetTextColor()
	assert(near(ar, br) and near(ag, bg) and near(ab, bb), what .. ": " .. table.concat({ tostring(ar), tostring(ag), tostring(ab) }, ",") .. " against " .. table.concat({ tostring(br), tostring(bg), tostring(bb) }, ","))
end

local env, K, ns = C.New()
C.Enable(env, K)
env.RunTimers()
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(320, 240)
local preview = K.Options.Preview("Chat")(parent)
local live, other = env.ChatFrame1Tab, env.ChatFrame2Tab
local parts = K.Skin.Parts(live)

assert(K.Store.Module("Chat").tabStyle == "underline", "the default is the mock-up's underline")
for _, style in ipairs({ "underline", "plain", "filled", "minimal" }) do
	K.Options.Write("Chat", "tabStyle", style)
	preview:Refresh()
	env.FCFTab_UpdateColors(live, true)
	env.FCFTab_UpdateColors(other, false)
	sameText(preview.tabs[1], live.Text, style .. ": the selected tab's text matches the live tab")
	sameText(preview.tabs[2], other.Text, style .. ": an unselected tab's text matches the live tab")
	assert(preview.underline:IsShown() == parts.underline:IsShown(), style .. ": the underline shows in both or in neither")
	assert(preview.glow:IsShown() == parts.chatGlow:IsShown(), style .. ": and so does its glow")
	if parts.underline:IsShown() then
		same(preview.underline, parts.underline, style .. ": the underline is the live one's gilt")
	end
	local tile = parts.backdrop
	assert(preview.fill:IsShown() == (tile ~= nil and tile:IsShown()), style .. ": the filled tile shows in both or in neither")
end

K.Options.Write("Chat", "tabStyle", "underline")
preview:Refresh()
local gr, gg, gb = K.Widgets.LumenColor("gilt")
local ur, ug, ub = preview.underline:GetVertexColor()
assert(near(ur, gr) and near(ug, gg) and near(ub, gb), "the preview's selected tab is underlined in gilt, never the class accent")
same(preview.divider, ns.Panel.Glass().divider, "the rule under the preview's tabs is the panel's")

local gallery = assert(io.open("Tools/render/scenes/gallery_chat.lua", "rb"))
local source = gallery:read("*a")
gallery:close()
assert(not source:find("tabStyle", 1, true), "the chat gallery draws the shipped tab style, not a forced one")

assert(#env._errors == 0, tostring(env._errors[1]))
print("chat tabs ok")
