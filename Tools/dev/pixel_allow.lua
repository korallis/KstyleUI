-- pixel_allow.lua: measures the whole pixel-grid matrix (Tools/regression/pixel_audit_lib.lua) and writes Tools/regression/pixel_allow.tsv, the regions each module file may still leave off the grid.
local Audit = dofile("Tools/regression/pixel_audit_lib.lua")

local rows, total, judgedAll = {}, 0, 0
for _, job in ipairs(Audit.Jobs()) do
	local counts, offenders, judged = Audit.Measure(job)
	total, judgedAll = total + #offenders, judgedAll + judged
	for file, count in pairs(counts) do
		rows[#rows + 1] = string.format("%s\t%s\t%d", Audit.Key(job), file, count)
	end
end
table.sort(rows)
local f = assert(io.open(Audit.ALLOW, "w"))
f:write("# scene\tscreen\tfile\tregions off the whole-pixel grid. Counts may only fall: each owner adopts Widgets.Point, Widgets.Fill and\n")
f:write("# Widgets.Size (docs/core-visuals.md) and reruns lua5.1 Tools/dev/pixel_allow.lua. Written by that script; do not edit by hand.\n")
for _, row in ipairs(rows) do
	f:write(row, "\n")
end
f:close()
print(string.format("%d regions judged, %d off the grid, %d lines in %s", judgedAll, total, #rows, Audit.ALLOW))
