-- test-taint-fixtures.lua: the taint scan finds each kind of risk and accepts the guarded forms.
local Scan = dofile("Tools/regression/taint_scan.lua")
local names = Scan.BlizzardNames(dofile("Tools/data/forever_globals.lua").read)

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function findings(source)
	local out = {}
	for _, f in ipairs(Scan(source, names)) do
		out[#out + 1] = f.line .. " " .. f.kind .. " " .. f.call
	end
	return table.concat(out, "\n")
end

local function expect(source, want)
	local got = findings(source)
	assert(got == want, "\nsource:\n" .. source .. "\ngot:\n" .. got .. "\nwant:\n" .. want)
end

-- The fixtures: bad.lua has one of each kind, and good.lua has none.
local bad = Scan(read("Tools/regression/fixtures/taint/bad.lua"), names)
local kinds = {}
for _, f in ipairs(bad) do
	kinds[f.kind] = (kinds[f.kind] or 0) + 1
end
for _, k in ipairs({ "frame-call", "field-write", "game-table-write", "protected-unguarded", "setparent-unguarded", "aura-unguarded" }) do
	assert(kinds[k], "bad.lua: no " .. k .. " finding")
end
expect(
	read("Tools/regression/fixtures/taint/bad.lua"),
	table.concat({
		"3 frame-call PlayerFrame:SetScript",
		"4 field-write TargetFrame.unit",
		"5 game-table-write UISpecialFrames[?]",
		"6 protected-unguarded SetBinding",
		"8 setparent-unguarded bar:SetParent",
		"9 aura-unguarded C_UnitAuras.GetAuraDataByIndex",
	}, "\n")
)
expect(read("Tools/regression/fixtures/taint/good.lua"), "")

-- Blizzard names are Forever's globals without KstyleUI's own.
local set = Scan.BlizzardNames({ "PlayerFrame", "KstyleUI_Old", "KstyleUI" })
assert(set.PlayerFrame and not set.KstyleUI_Old and not set.KstyleUI, "KstyleUI names are not Blizzard names")

-- Blizzard frames reached through _G, a child frame, a local alias or an upvalue cache.
expect('_G.PlayerFrame:Hide()\n_G["TargetFrame"]:SetScript("OnShow", nil)', "1 frame-call PlayerFrame:Hide\n2 frame-call TargetFrame:SetScript")
expect(
	"local hb = PlayerFrame.healthbar\nhb:SetScript('OnShow', nil)\nhb.x = 1",
	"2 frame-call PlayerFrame.healthbar:SetScript\n3 field-write PlayerFrame.healthbar.x"
)
expect("local UIParent = UIParent\nUIParent:SetScale(1)", "2 frame-call UIParent:SetScale")
expect("local a, b = PlayerFrame, TargetFrame\nb:Hide()", "2 frame-call TargetFrame:Hide")
expect("_G[name]:SetScript('OnShow', nil)", "1 frame-call _G[?]:SetScript")

-- Dot-syntax method calls, also through an alias of the method.
expect(
	"PlayerFrame.SetScript(PlayerFrame, 'OnShow', nil)\nlocal SP = TargetFrame.SetParent\nSP(TargetFrame, UIParent)\nself.icon.SetParent(self.icon, y)",
	table.concat({
		"1 frame-call PlayerFrame:SetScript",
		"3 frame-call TargetFrame:SetParent",
		"3 setparent-unguarded TargetFrame:SetParent",
		"4 setparent-unguarded self.icon:SetParent",
	}, "\n")
)

-- An assignment in a nested block or function may not run, so it never clears an alias.
expect("local f = PlayerFrame\nlocal function reset() f = nil end\nf:SetScript('OnShow', nil)", "3 frame-call PlayerFrame:SetScript")
expect("local f = PlayerFrame\nif x then f = nil end\nf:Hide()", "3 frame-call PlayerFrame:Hide")
expect("local f\nif x then f = PlayerFrame end\nf:Hide()", "3 frame-call PlayerFrame:Hide")

-- A local that hides a Blizzard name, a reassigned alias and an alias out of scope are not Blizzard.
expect("local PlayerFrame = CreateFrame('Frame')\nPlayerFrame:Hide()", "")
expect("local f = PlayerFrame\nf = CreateFrame('Frame')\nf:Hide()", "")
expect("do local f = PlayerFrame end\nlocal function g(f) f:Hide() end", "")
expect("local function OnClick(self, button) button:Hide() end", "")
expect("local function OnClick(self, button) local icon = button.icon\nicon:Hide() end", "")
expect("local function SetBinding() end\nSetBinding('F')\nlocal C_UnitAuras = {}\nC_UnitAuras.X()", "")

-- Function statements write a field or a global.
expect("function PlayerFrame:OnEvent() end\nfunction ToggleBackpack() end", "1 field-write PlayerFrame.OnEvent\n2 game-table-write ToggleBackpack")

-- Game tables: no writes, and only KstyleUI's own keys in StaticPopupDialogs and SlashCmdList.
expect(
	"tinsert(UISpecialFrames, 'X')\ntable.insert(UIPanelWindows, 1)\nUIPanelWindows.X = {}\nhash_SlashCmdList['/X'] = nil",
	table.concat({
		"1 game-table-write tinsert(UISpecialFrames)",
		"2 game-table-write table.insert(UIPanelWindows)",
		"3 game-table-write UIPanelWindows.X",
		'4 game-table-write hash_SlashCmdList["/X"]',
	}, "\n")
)
expect(
	"StaticPopupDialogs.CONFIRM = {}\nStaticPopupDialogs[key] = {}\nStaticPopupDialogs.KSTYLEUI_X.text = 'ok'\nSlashCmdList.OTHER = f\nStaticPopupDialogs = {}",
	table.concat({
		"1 game-table-write StaticPopupDialogs.CONFIRM",
		"2 game-table-write StaticPopupDialogs[?]",
		"4 game-table-write SlashCmdList.OTHER",
		"5 game-table-write StaticPopupDialogs",
	}, "\n")
)

-- A table function writes into its first argument, with the same key rules.
expect(
	"table.insert(StaticPopupDialogs.KSTYLEUI_X.buttons, {})\ntinsert(StaticPopupDialogs, {})\nwipe(PlayerFrame.list)\ntinsert(self.list, 1)",
	"2 game-table-write tinsert(StaticPopupDialogs)\n3 field-write wipe(PlayerFrame.list)"
)

-- Protected calls need InCombatLockdown or Combat.Queue in the 40 lines before them.
local filler = string.rep("do end\n", 39)
expect("if InCombatLockdown() then return end\n" .. filler .. "SetBinding('F')", "")
expect("if InCombatLockdown() then return end\n" .. filler .. "do end\nSetBinding('F')", "42 protected-unguarded SetBinding")
expect("SetBinding('F') if InCombatLockdown() then end", "1 protected-unguarded SetBinding")
expect(
	"local Bind = SetBinding\nBind('F')\nC_Macro.RunMacroText('/x')\nlocal C = C_Container\nC.UseContainerItem(0, 1)",
	"2 protected-unguarded SetBinding\n3 protected-unguarded C_Macro.RunMacroText\n5 protected-unguarded C_Container.UseContainerItem"
)

-- SetParent on any frame needs an Edit Mode check or a Safe helper in the 40 lines before it.
expect("KstyleUI.Safe.HideBlizzard(x)\nself.icon:SetParent(y)", "")
expect("self.icon:SetParent(y)\nCreateFrame('Frame'):SetParent(y)", "1 setparent-unguarded self.icon:SetParent\n2 setparent-unguarded ?:SetParent")
expect("PlayerFrame:SetParent(y)", "1 frame-call PlayerFrame:SetParent\n1 setparent-unguarded PlayerFrame:SetParent")

-- Aura reads need a secret guard somewhere in the file, also through an alias.
expect("local a = C_UnitAuras.GetAuraDataByIndex('player', 1)\nlocal ok = issecretvalue(a)", "")
expect("local A = C_UnitAuras\nlocal a = A.GetPlayerAuraBySpellID(1)", "2 aura-unguarded C_UnitAuras.GetPlayerAuraBySpellID")

-- Strings, comments and KstyleUI's own globals are not findings.
expect("local s = 'PlayerFrame:Hide()'\n--[[ PlayerFrame:Hide() ]]", "")
expect("KstyleUI = {}\nKstyleUI.Frame:Hide()\nKstyleUI.Frame.x = 1", "")

print("taint fixtures ok")
