-- test-cooldowns-medallions-sockets.lua: mirror and native tracked buffs share the slab frame and return to their earlier look on demand.
local C = dofile("Tools/regression/cooldowns_env.lua")
local env, K, ns = C.New({ setup = C.Game })
C.Enable(env, K)
K.Options.Write("HudStyle", "style", "medallions")
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
assert(icon.medIconFrame:GetTexture() == K.Tokens.Texture("medSlot") and icon.medIconWell:GetTexture() == K.Tokens.Texture("medSlotSocket"), "reuse the slab's frame and well")
local buff = env._viewers.BuffIconCooldownViewer._items[1]
local backdrop = K.Skin.Parts(buff).backdrop
assert(backdrop.medIconFrame:IsShown(), "automatic tracked buffs use the same frame on the native viewer")
K.Options.Write("Cooldowns", "medallionsIcons", false)
assert(not icon.medIconFrame:IsShown() and icon.chrome.visible, "off restores the mirror's original chrome")
assert(not backdrop.medIconFrame:IsShown() and backdrop.chrome.visible, "off restores native tracked buff chrome")
local formatter = C.W.LastCall(icon.cooldown, "SetCountdownFormatter")[1]
assert(formatter:FormatNumber(4) == "4" and formatter:FormatNumber(120) == "2m" and formatter:FormatNumber(6000) == "100m", "one engine formatter supplies bare seconds and minutes")
assert(env.issecretvalue(formatter:FormatNumber(env.Secret(4))), "secret countdowns remain secret through the engine formatter")
K.Options.Write("Cooldowns", "readableCountdown", false)
local row = ns.Row.New(env.UIParent, "utility", ns.Settings.current.utility)
local utility = row:Icon(1)
assert(C.W.LastCall(utility.cooldown, "SetCountdownFormatter")[1]:Format(4) == "4s", "off restores the previous seconds suffix")
assert(#env._errors == 0, tostring(env._errors[1]))
print("ok cooldown Medallions sockets: mirror, native tracked buffs and previous choices")
