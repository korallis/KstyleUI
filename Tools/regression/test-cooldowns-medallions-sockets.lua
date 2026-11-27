-- test-cooldowns-medallions-sockets.lua: under Medallions the mirror's cooldown rows are round crest medals on a short rail, a proc a looping gilt aura round one, native tracked buffs keep the slab frame, and each returns to its earlier look on demand.
local C = dofile("Tools/regression/cooldowns_env.lua")
local env, K, ns = C.New({ setup = C.Game })
C.Enable(env, K)
env.RunTimers()
local icon = ns.Mirror.Row("essential").icons[1]
env._cdm.cooldown[1001] = { active = true, gcd = false }
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(icon.realCooldown == nil, "mirror styling must not write the shared button's cooldown state")
assert(math.abs(icon.icon:GetVertexColor() - 0.65) < 1e-6, "quieter real cooldowns keep mirror icons readable")
K.Options.Write("Cooldowns", "quietCooldown", false)
assert(math.abs(icon.icon:GetVertexColor() - 1) < 1e-6, "quiet cooldown off restores the mirror's earlier icon brightness")
K.Options.Write("Cooldowns", "quietCooldown", true)
assert(icon.medIconFrame and icon.medIconFrame:IsShown() and not icon.chrome.visible, "Medallions mirror uses a single painted frame")
-- The cooldown rows are short rails of round medals in the crest's metal (KSTY-97: crest first, rails for the rest).
assert(icon.medIconFrame:GetTexture() == K.Tokens.Texture("medRing") and icon.medIconWell:GetTexture() == K.Tokens.Texture("dot"), "a cooldown is a round medal in the crest's bezel")
assert(icon.mask:GetTexture() == K.Tokens.Texture("dot") and C.W.LastCall(icon.cooldown, "SetSwipeTexture")[1] == K.Tokens.Texture("dot"), "its icon and sweep are round")
local rail = ns.Mirror.Row("essential")
assert(rail.count > 1 and rail.rails and rail.rails[1][1]:IsShown(), "the row's medals stand on a rail")
local _, _, _, left = rail.rails[1][1]:GetPoint(1)
local _, _, _, x = rail.icons[1]:GetPoint(1)
assert(math.abs(left - (x + rail.icons[1].opts.size / 2)) < 1, "the rail starts at the first medal's centre, to the pixel")
ns.Style.SetProc(icon, true)
-- A proc is an animated spell effect, never an icon (the captain's direction for everything a player tracks).
local aura = icon.medIconProc
assert(aura and aura.moving:IsShown() and aura.moving:GetTexture() == K.Tokens.Texture("procAura") and aura.loop:IsPlaying(), "a proc loops a gilt aura round the medal")
assert(not (icon.procHalo and icon.procHalo.holder:IsShown()), "and no square halo")
K.Motion.SetLevel("reduced")
assert(not aura.loop:IsPlaying() and aura.still:IsShown() and not aura.moving:IsShown(), "calm motion holds the aura still")
K.Motion.SetLevel("full")
assert(aura.loop:IsPlaying() and aura.moving:IsShown(), "and full motion plays it again")
ns.Style.SetProc(icon, false)
assert(not aura.moving:IsShown() and not aura.still:IsShown() and not aura.loop:IsPlaying(), "the aura goes with the proc")
local buff = env._viewers.BuffIconCooldownViewer._items[1]
local backdrop = K.Skin.Parts(buff).backdrop
assert(backdrop.medIconFrame:IsShown(), "automatic tracked buffs use the same frame on the native viewer")
K.Options.Write("Cooldowns", "medallionsIcons", false)
assert(not icon.medIconFrame:IsShown() and icon.chrome.visible, "off restores the mirror's original chrome")
assert(icon.mask:GetTexture() == K.Tokens.Texture("iconMask") and not rail.rails[1][1]:IsShown(), "and its square icon, with no rail")
assert(not backdrop.medIconFrame:IsShown() and backdrop.chrome.visible, "off restores native tracked buff chrome")
local formatter = C.W.LastCall(icon.cooldown, "SetCountdownFormatter")[1]
assert(formatter:FormatNumber(4) == "4" and formatter:FormatNumber(120) == "2m" and formatter:FormatNumber(6000) == "2h", "shorten a three-digit minute countdown to hours")
for _, case in ipairs({ { 5999, "2h" }, { 3599, "60m" }, { 3600, "1h" }, { 32400, "9h" }, { 60000, "9h" }, { 360000, "9h" }, { 1e12, "9h" } }) do
	assert(formatter:FormatNumber(case[1]) == case[2], "cap hour labels at 9h so long countdowns stay within two characters")
	assert(env.issecretvalue(formatter:FormatNumber(env.Secret(case[1]))), "keep long countdowns secret in the engine formatter")
end
assert(env.issecretvalue(formatter:FormatNumber(env.Secret(4))), "secret countdowns remain secret through the engine formatter")
K.Options.Write("Cooldowns", "readableCountdown", false)
local row = ns.Row.New(env.UIParent, "utility", ns.Settings.current.utility)
local utility = row:Icon(1)
assert(C.W.LastCall(utility.cooldown, "SetCountdownFormatter")[1]:Format(4) == "4s", "off restores the previous seconds suffix")
assert(#env._errors == 0, tostring(env._errors[1]))

do
	-- A hunter's rail medal shows the spell's Blender aura in place of its icon (the aura plan: the round game icons on
	-- the rails are replaced by auras class by class); a spell with no aura keeps its icon.
	local sample = C.Sample()
	sample[101].spellID = 19263
	local henv, HK, hns = C.New({ setup = C.Game, cooldowns = sample })
	C.Enable(henv, HK)
	henv.RunTimers()
	local deter, plain = hns.Mirror.Row("essential").icons[1], hns.Mirror.Row("essential").icons[2]
	local face = deter.medFace
	assert(face and face.moving:GetTexture() == HK.Tokens.Texture("auraSigilDeflect") and face.cover:IsShown(), "Deterrence's medal covers its icon with the Deflect aura")
	assert(face.moving:IsShown() and face.loop:IsPlaying() and not face.still:IsShown(), "at full motion the aura loops")
	local flip = face.loop._anims[1]
	assert(flip._type == "FlipBook" and flip:GetFlipBookRows() == 4 and flip:GetFlipBookColumns() == 4 and flip:GetFlipBookFrames() == 16 and flip:GetDuration() == 1.44, "playing the sheet's 4x4 grid of 16 frames over 1.44 s")
	assert(not plain.medFace, "a spell with no aura keeps its icon and makes nothing")
	HK.Motion.SetLevel("reduced")
	assert(not face.loop:IsPlaying() and face.still:IsShown() and not face.moving:IsShown(), "calm motion holds the aura still")
	HK.Motion.SetLevel("full")
	assert(face.loop:IsPlaying(), "and full motion plays it again")
	HK.Options.Write("Cooldowns", "medallionsIcons", false)
	assert(not face.cover:IsShown() and not face.still:IsShown() and not face.moving:IsShown() and not face.loop:IsPlaying(), "off brings the square icon back with no aura")
	HK.Options.Write("Cooldowns", "medallionsIcons", true)
	assert(face.loop:IsPlaying() and face.cover:IsShown(), "on again burns it again")
	assert(#henv._errors == 0, tostring(henv._errors[1]))
end
print("ok cooldown Medallions sockets: mirror, native tracked buffs and previous choices")
