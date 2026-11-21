-- test-profiles-spec-cooldowns.lua: Include cooldowns per specialization: off by default, a string carries each specialization's cooldown rules, the import gives a specialization with different rules its own copy of the profile and points the rest at the imported one, the recipient's toggle and older strings leave assignments alone.
local O = dofile("Tools/regression/options_env.lua")
local FURY, ARMS = { enabled = true, essential = { size = 40 } }, { enabled = true, essential = { size = 52 } }
local env, K, ns = O.New({ saved = { version = 42, profiles = { Default = { Cooldowns = FURY }, Other = { Cooldowns = ARMS } } } })
local Store, Profiles, Spec, Codec = K.Store, K.Profiles, K.Specialization, K.Codec
local function envelope(text) return Codec.Deserialize(Codec.DecodeBase64(text:sub(6))) end

-- Off by default: the Share page's toggle starts off, and an export without it stays a whole profile string.
local toggle = assert(O.Find(ns.Pages.Find(ns.Pages.List(), "Profiles").Items(), function(item) return item.label == "Include cooldowns per specialization" end))
assert(toggle.get() == false, "the toggle starts off")
local plain = assert(Profiles.Export("everything", true, {}))
assert(plain:sub(1, 6) == "KSUI1:", "an export without the toggle is unchanged")

-- No specialization has a profile yet: the export says so.
local text, why = Profiles.Export("everything", true, { cooldowns = true })
assert(text == nil and why == "No specialization has a profile assigned yet.", "nothing to share is explained, got " .. tostring(why))

-- Switched on: every specialization's rules travel with the profile.
Spec.Assign("role:TANK", "Default")
Spec.Assign("role:HEALER", "Other")
Spec.Assign("role:DAMAGER", "Default")
text = assert(Profiles.Export("everything", true, { cooldowns = true }))
local data = envelope(text)
assert(text:sub(1, 5) == "KSS1:" and data.scope == "everything", "the string is an envelope for the whole profile")
for _, key in ipairs({ "role:TANK", "role:HEALER", "role:DAMAGER" }) do
	assert(Store.Decode(data.cooldowns[key]), key .. " carries its rules")
end
assert(Store.Decode(data.cooldowns["role:HEALER"]).settings.Cooldowns.essential.size == 52, "the healer string carries Other's rules")
local scoped = envelope(assert(Profiles.Export({ Appearance = true }, false, { cooldowns = true })))
assert(scoped.scope == "modules" and scoped.cooldowns["role:HEALER"], "a selected-modules string carries them too")

toggle.set(true)
assert(envelope(assert(ns.Pages.ExportProfile())).cooldowns, "the Share page's toggle exports them")
toggle.set(false)
-- The recipient's toggle off: the import reviews and applies the profile and leaves assignments alone.
Spec.Assign("role:HEALER", "Default")
local preview = assert(Profiles.Preview(text, "everything", true, {}))
assert(not preview.summary:find("Cooldowns per specialization", 1, true), "the review leaves them out")
assert(Store.Import(preview.text, "Kept", {}))
assert(Spec.Profile("role:HEALER") == "Default" and not Store.Data().profiles["Kept (Healer)"], "assignments stay")

-- On: the review lists them; the healer gets its own copy with its rules, the others the imported profile.
preview = assert(Profiles.Preview(text, "everything", true, { cooldowns = true }))
assert(preview.summary:find("Cooldowns per specialization", 1, true), "the review lists the per-specialization rules")
assert(Store.Import(preview.text, "Shared", { cooldowns = true }))
assert(Spec.Profile("role:TANK") == "Shared" and Spec.Profile("role:DAMAGER") == "Shared", "same rules point at the imported profile")
assert(Spec.Profile("role:HEALER") == "Shared (Healer)", "different rules get their own copy, got " .. tostring(Spec.Profile("role:HEALER")))
assert(Store.Data().profiles["Shared (Healer)"].Cooldowns.essential.size == 52, "with the healer's rules")
assert(Store.Data().profiles["Shared"].Cooldowns.essential.size == 40, "the imported profile keeps the shared one's rules")

-- A second import never overwrites the first copy; a direct import without review takes them too.
assert(Store.Import(text, "Shared", { cooldowns = true }))
assert(Store.Data().profiles["Shared (Healer)"].Cooldowns.essential.size == 52 and Spec.Profile("role:HEALER"):find("^Shared %(2%) %(Healer"), "a later import makes its own copy, got " .. tostring(Spec.Profile("role:HEALER")))

-- An older string, or one with a damaged part, imports as before.
assert(Store.Import(plain, "Older", { cooldowns = true }) and Spec.Profile("role:HEALER"):find("^Shared"), "an older string changes no assignment")
data.cooldowns["role:HEALER"] = 7
local damaged = "KSS1:" .. Codec.EncodeBase64(Codec.Serialize(data))
assert(Store.Import(damaged, "Damaged", { cooldowns = true }) and Spec.Profile("role:HEALER"):find("^Shared"), "a damaged part is ignored")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-profiles-spec-cooldowns: ok")
