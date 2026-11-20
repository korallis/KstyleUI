-- test-skins-header-pixels.lua: the shared Speedrun heading stays on its card's pixel grid without increasing the RestedXP allowances.
local Audit = dofile("Tools/regression/pixel_audit_lib.lua")
local allow = Audit.LoadAllow()
for _, screen in ipairs(Audit.SCREENS) do
	local job = { scene = "gallery_restedxp", screen = screen }
	local counts, offenders = Audit.Measure(job)
	local problems = Audit.Judge(job, counts, offenders, allow)
	assert(#problems == 0, "Anchor the Speedrun heading to its shared card, with a snapped header row: " .. table.concat(problems, "\n"))
	collectgarbage("collect")
end
print("skins header pixels: all seven screens match existing allowances")
