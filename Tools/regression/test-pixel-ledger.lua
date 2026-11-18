-- test-pixel-ledger.lua: generated pixel counts keep their standard headers; durable ticket notes belong in the regression guide and commit history.
local file = assert(io.open("Tools/regression/pixel_allow.tsv", "rb"))
local source = file:read("*a")
file:close()
local comments = 0
for line in source:gmatch("[^\r\n]+") do
	if line:sub(1, 1) == "#" then comments = comments + 1 end
end
assert(comments == 2, "pixel_allow.tsv is generated: move ticket notes to Tools/regression/README.md and use a Baseline-Growth ticket trailer")
print("pixel baseline: generated counts have no erasable ticket notes")
