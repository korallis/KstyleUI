-- test-api-dynamic-names.lua: secret-capable native names and unit tokens never become lookup keys in skin, tooltip and nameplate fallbacks.
local S = dofile("Tools/regression/skins_env.lua")
local T = dofile("Tools/regression/tooltips_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local C = dofile("Tools/regression/chat_env.lua")

local function GuardGlobals(env)
	local meta = getmetatable(env)
	local original = meta.__index
	local secret = env.issecretvalue
	meta.__index = function(object, key)
		assert(not secret(key), "a secret value became a global lookup key")
		if type(original) == "function" then
			return original(object, key)
		end
		return original[key]
	end
end

local function Name(_, frame, value)
	frame.GetName = function() return value end
	return frame
end

for _, path in ipairs({ "KstyleUI_Skins/PartB/Mail.lua", "KstyleUI_Chat/Copy.lua" }) do
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a")
	file:close()
	for _, getter in ipairs({ "GetName", "GetText" }) do
		assert(not source:match(getter .. "%(%)[%s]+or[%s]+"), path .. " boolean-tests a secret-capable getter before its guard")
	end
end

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	GuardGlobals(env)
	local secret = env.Secret("RestrictedFrame")
	local frame = Name(env, env.CreateFrame("Frame", nil, env.UIParent), secret)
	frame.numTabs = 2
	local before = K.ErrorCount()
	assert(K.Skin.Tabs(frame) == 0, "the shared tab fallback skips a secret name")
	assert(#ns.PartBKit.WindowTabs(frame) == 0, "the part B tab fallback skips a secret name")
	local item = Name(env, env.CreateFrame("Button", nil, env.UIParent), secret)
	item.icon = item:CreateTexture(nil, "ARTWORK")
	assert(ns.PartC.Item(item), "an item with a secret name still uses its direct icon")
	local publicItem = env.CreateFrame("Button", "PublicLootItem", env.UIParent)
	local icon = publicItem:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	env.PublicLootItemIconTexture = icon
	assert(ns.PartC.Item(publicItem) and icon:GetAlpha() == 1, "a public named item icon is retained")
	assert(K.ErrorCount() == before, "name fallback checks do not need caught errors")
	local tab1 = env.CreateFrame("Button", "PlainWindowTab1", env.UIParent)
	local tab2 = env.CreateFrame("Button", "PlainWindowTab2", env.UIParent)
	local plain = env.CreateFrame("Frame", "PlainWindow", env.UIParent)
	plain.numTabs = 2
	local tabs = ns.PartBKit.WindowTabs(plain)
	assert(tabs[1] == tab1 and tabs[2] == tab2, "public numbered tab names still resolve")
	assert(K.Skin.Tabs(plain) == 2, "the shared skin still resolves both public numbered tabs")
end

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	GuardGlobals(env)
	env.CreateFrame("Frame", "CharacterFrame", env.UIParent)
	local slot = Name(env, env.CreateFrame("Button", "CharacterHeadSlot", env.CharacterFrame), env.Secret("RestrictedSlot"))
	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	local before = K.ErrorCount()
	ns.Skins.Get("character").Apply()
	assert(K.ErrorCount() == before, "the character slot fallback does not index a secret name")
	local publicSlot = env.CreateFrame("Button", "CharacterMainHandSlot", env.CharacterFrame)
	local icon = publicSlot:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	env.CharacterMainHandSlotIconTexture = icon
	ns.Skins.Get("character").Apply()
	assert(icon:GetAlpha() == 1, "a public named character-slot icon is retained")
end

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	GuardGlobals(env)
	env.CreateFrame("Frame", "MailFrame", env.UIParent)
	env.CreateFrame("Frame", "InboxFrame", env.MailFrame)
	local row = env.CreateFrame("Frame", "MailItem1", env.InboxFrame)
	row.Button = Name(env, env.CreateFrame("Button", nil, row), env.Secret("RestrictedMail"))
	row.Button.icon = row.Button:CreateTexture(nil, "ARTWORK")
	local before = K.ErrorCount()
	assert(ns.Skins.Get("mail").Apply(), "mail remains usable without a name-based COD region")
	assert(K.ErrorCount() == before, "the mail fallback does not index a secret name")
	local publicRow = env.CreateFrame("Frame", "MailItem2", env.InboxFrame)
	publicRow.Button = env.CreateFrame("Button", "MailItem2Button", publicRow)
	local cod = publicRow.Button:CreateTexture(nil, "ARTWORK")
	cod:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	env.MailItem2ButtonCODBackground = cod
	ns.Skins.Get("mail").Apply()
	assert(cod:GetAlpha() == 1, "a public named COD region is retained")
end

do
	local env, _, ns = T.New()
	GuardGlobals(env)
	local tip = Name(env, env.GameTooltip, env.Secret("RestrictedTooltip"))
	tip.GetLeftLine, tip.GetRightLine = false, false
	assert(ns.Style.Line(tip, "left", 1) == nil, "the tooltip fallback skips a secret name")
	Name(env, tip, "GameTooltip")
	local line = tip:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	env.GameTooltipTextLeft1 = line
	assert(ns.Style.Line(tip, "left", 1) == line, "a public tooltip name still resolves its line")
end

do
	local env, K, ns = C.New()
	C.Enable(env, K)
	GuardGlobals(env)
	Name(env, env.ChatFrame1, env.Secret("RestrictedChat"))
	local before = K.ErrorCount()
	assert(ns.Copy.Open(env.ChatFrame1), "chat copy tolerates a restricted source name")
	Name(env, env.ChatFrame1, "ChatFrame1")
	env.ChatFrame1Tab.GetText = function() return env.Secret("RestrictedTab") end
	assert(ns.Copy.Open(env.ChatFrame1), "chat copy tolerates a restricted tab label")
	assert(K.ErrorCount() == before and #env._errors == 0, "copy-title reads do not need caught errors")
end

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = assert(ns.Plates.Get("nameplate1"))
	local name, units = debug.getupvalue(ns.Plates.Get, 1)
	assert(name == "byUnit" and type(units) == "table", "the fixture guards the dispatch lookup table")
	setmetatable(units, { __index = function(_, key)
		assert(not env.issecretvalue(key), "a secret unit became a table key")
		assert(type(key) == "string", "a non-string unit reached the lookup")
	end })
	local original, refreshed = plate.UpdateHealth, 0
	plate.UpdateHealth = function(self, ...)
		refreshed = refreshed + 1
		return original(self, ...)
	end
	local before = K.ErrorCount()
	env.FireEvent("UNIT_HEALTH", env.Secret("nameplate1"))
	env.FireEvent("UNIT_SPELLCAST_START", env.Secret("nameplate1"), env.Secret("cast"), env.Secret(1))
	env.FireEvent("UNIT_HEALTH", 42)
	env.FireEvent("UNIT_HEALTH", false)
	env.FireEvent("UNIT_HEALTH", {})
	env.FireEvent("UNIT_HEALTH")
	assert(K.ErrorCount() == before and #env._errors == 0, "invalid unit tokens are rejected without caught errors")
	assert(refreshed == 0, "restricted or malformed unit tokens do not refresh a plate")
	env.FireEvent("UNIT_HEALTH", "missing")
	env.FireEvent("UNIT_HEALTH", "nameplate1")
	assert(refreshed == 1, "a public attached unit still reaches its handler")
end

print("dynamic native names and units ok")
