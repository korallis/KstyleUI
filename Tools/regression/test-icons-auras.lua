-- test-icons-auras.lua: every aura icon KstyleUI owns (the buff panel, frame auras, group debuffs, nameplate debuffs, their sample tiles) and the Cooldown Manager's restyled viewer icons go through the Icons service: a known file ID shows the set's art, an unknown or secret one keeps the game's icon with no error, and a set change follows.
local W = dofile("Tools/regression/widget_env.lua")

local KNOWN, OTHER, UNKNOWN = 132333, 136224, 999999
local B_PATH = "Interface\\AddOns\\KstyleUI_IconsColour\\Icons\\"
local A_PATH = "Interface\\AddOns\\KstyleUI_Icons\\Icons\\"
local DATA = {
	KstyleUI_IconsColour = { set = "B", icons = { [KNOWN] = B_PATH .. KNOWN .. ".png", [OTHER] = B_PATH .. OTHER .. ".png" } },
	KstyleUI_Icons = { set = "A", icons = { [KNOWN] = A_PATH .. KNOWN .. ".png" } },
}

-- AddOns(env) gives an environment the two data addons, as test-icons.lua does.
local function AddOns(env)
	env._loaded = {}
	env.C_AddOns = {
		LoadAddOn = function(name)
			env.KstyleUIIconData, env._loaded[name] = W.CoreEnv.DeepCopy(DATA[name]), true
			return true
		end,
		IsAddOnLoaded = function(name)
			return env._loaded[name] == true
		end,
	}
end

local function On(K)
	K.Options.Write("Icons", "set", "B")
	K.Options.Write("Icons", "enabled", true)
end

local function Shown(texture)
	local call = W.LastCall(texture, "SetTexture")
	return call and call[1]
end

local function Count(texture)
	return #W.Calls(texture, "SetTexture")
end

local function NoErrors(env, K, where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

-- Drive(env, K, icon, label, secret) sets the icon as the engine or the module would and checks each rule.
-- secret(on) switches aura secrecy on or off in the environment, as a pull does before combat lockdown.
local function Drive(env, K, icon, label, secret)
	icon:SetTexture(KNOWN)
	assert(Shown(icon) == B_PATH .. KNOWN .. ".png", label .. ": a known file ID shows set B's art")
	assert(W.SameRGB(icon, 1, 1, 1), label .. ": set B is not tinted")
	icon:SetTexture(UNKNOWN)
	assert(Shown(icon) == UNKNOWN, label .. ": a file ID the set lacks keeps the game's icon")
	icon:SetTexture(KNOWN)
	assert(Shown(icon) == B_PATH .. KNOWN .. ".png", label .. ": the art comes back with a known file ID")

	-- The engine wraps every aura icon as a secret. The service neither compares it nor sets the texture again.
	local wrapped = env.Secret(OTHER)
	secret(true)
	env.SetCombat(true)
	local before = Count(icon)
	icon:SetTexture(wrapped)
	assert(Count(icon) == before + 1, label .. ": a secret file ID leaves the texture as the engine set it")
	assert(Shown(icon) == wrapped, label .. ": the game's icon stays for a secret file ID")
	assert(W.SameRGB(icon, 1, 1, 1), label .. ": and its colour")
	icon:SetTexture(wrapped)
	assert(Count(icon) == before + 2, label .. ": a second secret file ID is as cheap")
	env.SetCombat(false)
	secret(false)
	NoErrors(env, K, label .. " in combat")

	icon:SetTexture(KNOWN)
	assert(Shown(icon) == B_PATH .. KNOWN .. ".png", label .. ": the art comes back after combat")
	K.Options.Write("Icons", "set", "A")
	assert(Shown(icon) == A_PATH .. KNOWN .. ".png", label .. ": a set change redraws the icon in the new set")
	K.Options.Write("Icons", "set", "B")
	assert(Shown(icon) == B_PATH .. KNOWN .. ".png", label .. ": and back")
	K.Options.Write("Icons", "enabled", false)
	assert(Shown(icon) == KNOWN, label .. ": custom icons off gives the game's icon back")
	K.Options.Write("Icons", "enabled", true)
	assert(Shown(icon) == B_PATH .. KNOWN .. ".png", label .. ": and on again shows the art")
	NoErrors(env, K, label)
end

local function Switch(env, key)
	return function(on)
		env[key] = on
	end
end

-- The buff panel: KstyleUI_Auras ----------------------------------------------------------------------

do
	local A = dofile("Tools/regression/auras_env.lua")
	local env, K = A.New({ setup = AddOns })
	On(K)
	K.Modules.Enable("Auras")
	env.RunTimers()
	local _, group = A.Container(env, "HELPFUL")
	assert(group and group.frames[1], "the buff container has buttons")
	Drive(env, K, group.frames[1]._aura.icon, "buff panel", Switch(env, "_aurasSecret"))
	local _, debuffs = A.Container(env, "HARMFUL")
	Drive(env, K, debuffs.frames[2]._aura.icon, "debuff panel", Switch(env, "_aurasSecret"))
end

-- Frame auras: KstyleUI_UnitFrames ---------------------------------------------------------------------

do
	local U = dofile("Tools/regression/unitframes_env.lua")
	local env, K, ns = U.New({ setup = AddOns })
	On(K)
	local focus = ns.Frames.Get("focus").views[1]
	local button = focus.auras.container._groups.debuffs.buttons[1]
	Drive(env, K, button._aura.SetIcon[1], "frame auras", Switch(env, "_restricted"))
end

-- Group debuffs and the preview's sample tiles: KstyleUI_GroupFrames -------------------------------------

do
	local G = dofile("Tools/regression/group_env.lua")
	local env, K, ns = G.New({ setup = AddOns })
	On(K)
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR" }, { name = "Sylaen", class = "DRUID" } })
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	local content
	local i = 1
	while ns.Headers.party._attributes["child" .. i] do
		local button = ns.Headers.party._attributes["child" .. i]
		if button._attributes.unit == "party1" and button._shown then
			content = ns.Button.Content(button)
		end
		i = i + 1
	end
	assert(content and content.auras, "party1 has a debuff container")
	Drive(env, K, content.auras._groups.debuffs.frames[1]._aura.icon, "group debuffs", Switch(env, "_aurasSecret"))

	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview("GroupFrames")(parent)
	preview:Refresh()
	local sample = preview.partyFrames[1].sampleAuras[1]
	assert(sample and sample.art, "the preview's sample frame draws sample debuffs")
	sample.art:SetTexture(KNOWN)
	assert(Shown(sample.art) == B_PATH .. KNOWN .. ".png", "a sample debuff tile goes through the service")
	NoErrors(env, K, "group samples")
end

-- Nameplate debuffs and the sample plate's tiles: KstyleUI_Nameplates --------------------------------------

do
	local N = dofile("Tools/regression/nameplates_env.lua")
	local env, K, ns = N.New({ setup = AddOns })
	On(K)
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	Drive(env, K, plate.auras._groups.debuffs.frames[1]._aura.icon, "nameplate debuffs", Switch(env, "_aurasSecret"))

	local preview = K.Options.Preview("Nameplates")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	local sample = preview.plates[1].sampleAuras[1]
	assert(sample and sample.icon, "the sample plate draws sample debuffs")
	sample.icon:SetTexture(KNOWN)
	assert(Shown(sample.icon) == B_PATH .. KNOWN .. ".png", "a sample debuff tile on a plate goes through the service")
	NoErrors(env, K, "nameplate samples")
end

-- The Cooldown Manager's restyled viewers: Blizzard's icons, watched without a write onto Blizzard's frames --

do
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local env, K, ns = C.New({
		setup = function(env)
			C.Game(env)
			AddOns(env)
		end,
	})
	On(K)
	-- Set A already on, with icons that show its art before the reskin runs: the strip keeps the icon itself.
	K.Options.Write("Icons", "set", "A")
	local item = env._viewers.EssentialCooldownViewer._items[1]
	local bar = env._viewers.BuffBarCooldownViewer._items[1]
	item.Icon:SetTexture(KNOWN)
	bar.Icon.Icon:SetTexture(KNOWN)
	K.Options.Write("Cooldowns", "path", "reskin")
	C.Enable(env, K)
	assert(item.Icon:GetAlpha() == 1 and bar.Icon.Icon:GetAlpha() == 1, "an icon that showed set A's art before the reskin stays visible")
	assert(K.Icons.Highlight(item.Icon):GetAlpha() == 1 and K.Icons.Highlight(bar.Icon.Icon):GetAlpha() == 1, "and so does its highlight copy")
	assert(item.Overlay:GetAlpha() == 0, "Blizzard's overlay is still hushed")
	K.Options.Write("Icons", "set", "B")
	Drive(env, K, item.Icon, "restyled cooldown icon", function() end)
	Drive(env, K, bar.Icon.Icon, "restyled buff bar icon", function() end)
	C.Clean(env, { SetScript = true, Hide = true, SetParent = true, SetPoint = true, ClearAllPoints = true, SetSize = true, SetScale = true })

	-- Set A puts an additive highlight copy on the item, beside Blizzard's regions. The reskin keeps it out of
	-- Skin.Strip: on a refresh, when the item shows again, and when the copy appears only after a later redraw.
	local function Highlight(texture)
		local copy = K.Icons.Highlight(texture)
		assert(copy and copy:GetParent() == texture:GetParent(), "the highlight copy sits on the item")
		return copy
	end
	item = env._viewers.EssentialCooldownViewer._items[2]
	assert(item and item.Icon, "the essential viewer has a second item")
	item.Icon:SetTexture(UNKNOWN)
	K.Options.Write("Icons", "set", "A")
	assert(K.Icons.Highlight(item.Icon) == nil, "an unknown file ID has no highlight copy")
	item.Icon:SetTexture(KNOWN)
	local copy = Highlight(item.Icon)
	assert(copy:GetAlpha() == 1, "a copy made by a later redraw is not hushed")
	item:Hide()
	item:Show()
	assert(copy:GetAlpha() == 1, "the strip on show keeps the copy")
	ns.Reskin.Refresh()
	assert(copy:GetAlpha() == 1, "a refresh keeps the copy")
	item:Hide()
	item:Show()
	assert(copy:GetAlpha() == 1, "and so does the show after it")
	assert(copy:IsShown() and W.SameColor(copy, 1, 1, 1, 0.25), "the copy glows at the highlight strength")
	local barCopy = Highlight(bar.Icon.Icon)
	bar.Icon:Hide()
	bar.Icon:Show()
	ns.Reskin.Refresh()
	assert(barCopy:GetAlpha() == 1, "a buff bar icon's copy is kept too")
	K.Options.Write("Icons", "set", "B")
	assert(not copy:IsShown(), "set B hides the copy")
	NoErrors(env, K, "restyled highlights")
end

print("aura icons ok")
