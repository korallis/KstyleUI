-- test-options-notes.lua: About > What's new lists the Highlights of the newest three versions in CHANGELOG.md, word for word.
local f = assert(io.open("CHANGELOG.md", "rb"))
local text = f:read("*a"):gsub("\r\n", "\n")
f:close()

local starts, at = {}, text:find("\n## ", 1, true)
while at do
	starts[#starts + 1] = at
	at = text:find("\n## ", at + 1, true)
end
local want = {}
for i = 1, math.min(3, #starts) do
	local section = text:sub(starts[i] + 4, (starts[i + 1] or #text + 1) - 1) .. "\n\n"
	local lines = {}
	for line in (section:match("\nHighlights:\n\n(.-)\n\n") or ""):gmatch("%- ([^\n]+)") do lines[#lines + 1] = line end
	want[#want + 1] = { section:match("^([^\n]+)"), lines }
end
assert(#want == 3, "CHANGELOG.md lists fewer than three versions")

local ns = {}
assert(loadfile("KstyleUI_Options/Notes.lua"))("KstyleUI_Options", ns)

local function Block()
	local out = {}
	for _, note in ipairs(want) do
		out[#out + 1] = string.format("\t{ %q, {", note[1])
		for _, line in ipairs(note[2]) do out[#out + 1] = string.format("\t\t%q,", line) end
		out[#out + 1] = "\t} },"
	end
	return table.concat(out, "\n")
end

local same = #ns.NOTES == #want
for i, note in ipairs(want) do
	local got = ns.NOTES[i]
	same = same and got and got[1] == note[1] and #got[2] == #note[2] and #note[2] > 0
	for j, line in ipairs(note[2]) do same = same and got[2][j] == line end
end
assert(same, "KstyleUI_Options/Notes.lua is behind CHANGELOG.md. Replace the entries in ns.NOTES with these, then run python3 Tools/dev/crlf.py (escape any non-ASCII letter as \\ddd):\n" .. Block())
print("options notes ok: " .. want[1][1])
