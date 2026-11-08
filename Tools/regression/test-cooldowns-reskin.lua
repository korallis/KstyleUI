-- test-cooldowns-reskin.lua: the reskin path restyles Blizzard's Cooldown Manager items in place with the Skin helpers, and a failing mirror switches to it.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local FORBIDDEN = { SetScript = true, Hide = true, SetParent = true, SetPoint = true, ClearAllPoints = true, SetSize = true, SetScale = true }

local function Clean(env)
	C.Clean(env, FORBIDDEN)
end

local function Alpha(texture)
	return texture:GetAlpha()
end

local env, K, ns = C.New({ setup = C.Game })
K.Options.Write("Cooldowns", "path", "reskin")
C.Enable(env, K)

-- Icon items: the overlay art is hushed, the icon and out-of-range shade stay, a chamfered tile sits behind.
local essential = env._viewers.EssentialCooldownViewer
local item = essential._items[1]
assert(Alpha(item.Icon) == 1, "the icon stays")
assert(Alpha(item.Overlay) == 0, "Blizzard's icon overlay is hushed")
assert(K.Skin.IsSkinned(item, "Backdrop"), "the item has a KstyleUI backdrop")
assert(W.LastCall(item.Icon, "SetTexCoord"), "the icon is cropped")
local font = W.LastCall(item.Cooldown:GetCountdownFontString(), "SetFont")
assert(font and font[2] == ns.Settings.current.essential.timerSize, "the countdown takes the timer size")
assert(W.LastCall(item.ChargeCount.Current, "SetFont"), "the charge count is restyled")

-- The restyled icon has the action buttons' dark body and rim: buttonFill, and the accent lifted 15% toward white.
local backdrop = K.Skin.Parts(item).backdrop
assert(backdrop.chrome.fillName == "buttonFill", "a restyled icon has the dark button body, got " .. tostring(backdrop.chrome.fillName))
local ar, ag, ab = ns.Settings.Accent()
local wr, wg, wb = K.Tokens.Color("textHover")
local rr, rg, rb = K.Widgets.Mix(ar, ag, ab, 1, wr, wg, wb, 1, 0.15)
local edge = backdrop.chrome.edge
assert(W.Near(edge[1], rr) and W.Near(edge[2], rg) and W.Near(edge[3], rb) and W.Near(edge[4], 1), "the rim is the accent lifted 15% toward white")

-- The rim comes from the shared icon chrome (Widgets.IconChrome), the helper every square icon button uses.
assert(type(backdrop.chrome.SetRimAccent) == "function" and backdrop.chrome.rimAccent == true, "the restyled icon's chrome is the shared icon chrome, resting on IconRim")
local formatter = W.LastCall(item.Cooldown, "SetCountdownFormatter")
assert(formatter and type(formatter[1]) == "table" and formatter[1]:Format(4) == "4s", "the restyled icon's countdown reads 4s")

-- Bar items: the bar takes the texture and colour from the settings; its background and pip are hushed.
local bars = env._viewers.BuffBarCooldownViewer
local bar = bars._items[1]
assert(W.LastCall(bar.Bar, "SetStatusBarTexture")[1] == ns.Settings.current.bars.texture, "the bar takes the texture setting")
local r, g, b = K.Theme.ClassColor(K.Theme.Class())
local color = W.LastCall(bar.Bar, "SetStatusBarColor")
assert(color[1] == r and color[2] == g and color[3] == b, "the bar takes the class colour")
assert(W.Near(color[4], 0.15), "the fill is subtle over the glass: alpha " .. tostring(color[4]))
assert(K.Skin.Parts(bar.Bar).backdrop.chrome.fillName == "surface", "a restyled bar is a glass tile")
assert(K.Skin.Parts(bar.Icon).backdrop.chrome.fillName == "buttonFill", "a restyled bar's icon sits on a dark tile")
assert(Alpha(bar.Bar.BarBG) == 0 and Alpha(bar.Bar.Pip) == 0, "the bar's background and pip are hushed")
assert(W.LastCall(bar.Bar.Name, "SetFont"), "the bar name is restyled")

-- A newly acquired item is skinned too.
local fresh = C.Item(env, essential, 7)
essential:OnAcquireItemFrame(fresh)
assert(K.Skin.IsSkinned(fresh, "Backdrop"), "an item acquired later is skinned")

-- A settings change restyles the skinned items.
K.Options.Write("Cooldowns", "bars.colorSource", "custom")
K.Options.Write("Cooldowns", "bars.color", { r = 0, g = 1, b = 0 })
color = W.LastCall(bar.Bar, "SetStatusBarColor")
assert(color[1] == 0 and color[2] == 1 and color[3] == 0, "a custom bar colour applies to the restyled bars")

Clean(env)
assert(essential:GetAlpha() == 1, "the reskin path never fades Blizzard's viewer")

-- Automatic: the tracked buff viewers are restyled while the cooldown rows mirror.
do
	local env3, K3 = C.New({ setup = C.Game })
	C.Enable(env3, K3)
	local buffItem = env3._viewers.BuffIconCooldownViewer._items[1]
	assert(K3.Skin.IsSkinned(buffItem, "Backdrop"), "the buff icon viewer is restyled on the automatic path")
	assert(W.LastCall(buffItem.Applications.Applications, "SetFont"), "buff stack counts take the count font")
	assert(K3.Skin.IsSkinned(env3._viewers.BuffBarCooldownViewer._items[1].Bar, "Backdrop"), "the buff bars are restyled")
	assert(not K3.Skin.IsSkinned(env3._viewers.EssentialCooldownViewer._items[1], "Backdrop"), "the mirrored essential viewer is left alone")
	C.Clean(env3, FORBIDDEN)
end

-- A mirror that fails in combat switches to the reskin at once.
do
	local env2, K2, ns2 = C.New({ setup = C.Game })
	C.Enable(env2, K2)
	assert(ns2.Path.Get("essential") == "mirror", "the mirror runs first")
	env2.SetCombat(true)
	env2._cdm.durationError = "secret arguments are not allowed"
	env2.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(ns2.Path.Get("essential") == "reskin", "the failed row switches to the reskin")
	local viewer = env2._viewers.EssentialCooldownViewer
	assert(viewer:GetAlpha() == 1, "Blizzard's viewer shows again")
	assert(K2.Skin.IsSkinned(viewer._items[1], "Backdrop"), "and is restyled")
	assert(not ns2.Mirror.Row("essential").content:IsShown(), "the KstyleUI row hides")
	Clean(env2)
end

print("cooldowns reskin ok")
