-- test-options-specialization.lua: the Profiles page exposes the default-on toggle and every spec or fallback role assignment.
local O = dofile("Tools/regression/options_env.lua")
local function page(ns)
	local profile = assert(ns.Pages.Find(ns.Pages.List(), "Profiles"))
	return ns.Model.PageItems(profile)
end
local function item(items, label)
	return assert(O.Find(items, function(row) return row.label == label end), label)
end

local env, K, ns = O.New({ setup = function(e)
	e.GetNumSpecializations = function() return 2 end
	e.C_SpecializationInfo = {
		GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function(index)
			return index, index == 1 and "Arms" or "Protection", nil, nil, "DAMAGER"
		end,
	}
end })
K.Store.CreateProfile("Raid")
local items = page(ns)
local toggle = item(items, "Use a profile per specialization")
assert(toggle.get() == true and type(toggle.help) == "string")
assert(item(items, "Arms").get() == "Default" and item(items, "Protection").get() == "Default")
item(items, "Protection").set("Raid")
assert(item(items, "Protection").get() == "Raid" and K.Store.ProfileName() == "Default")
toggle.set(false)
assert(ns.Model.IsDisabled(item(items, "Arms")), "off disables spec pickers")
toggle.set(true)
assert(not ns.Model.IsDisabled(item(items, "Arms")))
item(items, "Arms").set("Raid")
assert(K.Store.ProfileName() == "Raid", "choosing this spec's profile switches immediately outside combat")
assert(K.ErrorCount() == 0 and #env._errors == 0)

local _, F, fallback = O.New()
local roles = page(fallback)
for _, label in ipairs({ "Tank", "Healer", "Damage" }) do
	assert(item(roles, label).get() == F.Store.ProfileName(), "missing specs expose assigned-role rows")
end
print("specialization options ok")
