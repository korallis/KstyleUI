-- guard.lua: the render guard. After a scene builds, it lists every text the page would end in "..." and every
-- piece of content that reaches past the glass card it belongs to, so a shipped render cannot clip or spill unseen.
--
--   local Guard = dofile("Tools/render/guard.lua")
--   local findings = Guard.Check(scene)                     -- { kind, subject, card, detail, key }, sorted
--   local allow = Guard.LoadAllow()                         -- Tools/render/guard_allow.tsv
--   local fresh, allowed, stale = Guard.Sort(findings, allow, "hud_lumen_questing")
--
-- Four kinds of finding:
--   ellipsis  a text that may not wrap (WordWrap off) and is wider than its rect, measured with the same glyph
--             table and the same 0.5-pixel slack the page uses before it truncates (render.js truncateRuns);
--   outside   a drawn text or texture that belongs to a card and reaches more than SLACK units past its glass, and
--             does not sit wholly on any other glass either (a popout list hangs under the card that opened it);
--             and a card inside another card's content whose glass reaches past that card's glass (a tab column
--             hung off a window's edge), named "<key path> glass";
--   clipped   a text whose rect reaches more than SLACK units past the nearest frame that clips its children, so
--             the player reads a fragment ("ing Frostbolt"). A scroll view (a ScrollFrame, or a clipping frame that
--             takes the mouse wheel, or whose parent does) cuts its rows by design and is never a finding;
--   overlap   two texts whose glyphs cross by more than OVERLAP units on both axes, or a text whose glyphs an
--             opaque texture (effective alpha at least COVER_ALPHA) from another frame draws over, drawn after the
--             text; both inside one card, or both in one top-level element when no card holds them, named
--             "<subject> & <subject>" in byte order. A text drawn over a texture, and a texture on the text's own
--             frame, are the design. A text's glyphs are measured as the page draws them: the glyph table's width
--             set by its justification inside its rect, one line high, or its wrapped lines when it wraps.
-- A card is a frame that owns Lumen frost glass: the panel, card, window and rail shapes of Widgets.Chrome (tiles,
-- sockets and bars carry no frost). The glass is the union of the card's LumenShape slices, as drawn. A card's
-- content is everything drawn under the frame the glass clothes: the card frame itself, or, for a backdrop (a glass
-- frame with no text and no frames of its own, as Skin.Backdrop makes), its target or parent. Text whose centre
-- sits on a card's glass is that card's content too, wherever it hangs in the frame tree. Shadows, glows and gilt
-- corners bleed past the glass by design and are never content; an item the page draws through a clip rect is
-- checked as clipped. A text inside a nested card is held to the innermost card.
--
-- The rect arithmetic is Tools/regression/geometry.lua's (Geometry.Outside); the rects are the scene's own, so the
-- guard sees exactly what the page draws.
local Scene = dofile("Tools/render/scene.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local Guard = {}

Guard.SLACK = 1
Guard.OVERLAP = 2
Guard.COVER_ALPHA = 0.5
Guard.ppu = tonumber(os.getenv and os.getenv("RENDER_PPU") or nil) or 1.426
Guard.ALLOW = "Tools/render/guard_allow.tsv"
Guard.OWNERS = { R1 = true, R2 = true, R3 = true, R4a = true, R4b = true, R5 = true, R6 = true, R7 = true, S1 = true, S2 = true, S3 = true, S4 = true, S5 = true, S6 = true, design = true }
Guard.KINDS = { ellipsis = true, outside = true, clipped = true, overlap = true }

local DECOR = { "LumenShadow", "Shadow.png", "Glow.png", "LumenGilt", "Noise.png" }

local function isDecor(item)
	local file = item.file or item.path
	if type(file) ~= "string" then
		return false
	end
	for _, name in ipairs(DECOR) do
		if file:find(name, 1, true) then
			return true
		end
	end
	return false
end

local function fileOf(item)
	return type(item.file) == "string" and item.file or type(item.path) == "string" and item.path or ""
end

local function bounds(r)
	return { left = r[1], right = r[1] + r[3], top = r[2] + r[4], bottom = r[2] }
end

local function union(a, r)
	if not a then
		return { r[1], r[2], r[3], r[4] }
	end
	local x0, y0 = math.min(a[1], r[1]), math.min(a[2], r[2])
	local x1, y1 = math.max(a[1] + a[3], r[1] + r[3]), math.max(a[2] + a[4], r[2] + r[4])
	return { x0, y0, x1 - x0, y1 - y0 }
end

local function intersect(r, clip)
	if not clip then
		return r
	end
	local x0, y0 = math.max(r[1], clip[1]), math.max(r[2], clip[2])
	local x1, y1 = math.min(r[1] + r[3], clip[1] + clip[3]), math.min(r[2] + r[4], clip[2] + clip[4])
	return { x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0) }
end

-- keyPath(object) -> where the object hangs, from its nearest named ancestor: "Name.key.key" by the fields that
-- hold each frame (the first in byte order when two fields hold it, so the path never depends on pairs order), "?"
-- for a step no field names.
local function keyPath(object)
	local parts, node = {}, object
	while node do
		if node._name then
			table.insert(parts, 1, node._name)
			break
		end
		local parent, key = node._parent, nil
		if parent then
			for k, v in pairs(parent) do
				if v == node and type(k) == "string" and (key == nil or k < key) then
					key = k
				end
			end
		end
		key = key or "?"
		table.insert(parts, 1, key)
		node = parent
	end
	return table.concat(parts, ".")
end

local function subjectOf(item)
	if item.kind == "text" then
		return (Scene.PlainText(item.text):gsub("\226\128\137", ""):gsub("\n", " "))
	end
	local file = fileOf(item)
	return keyPath(item.object) .. (file ~= "" and (" " .. (file:match("([^/\\]+)$") or file)) or "")
end

local function isBackdrop(frame)
	if frame._kids and #frame._kids > 0 then
		return false
	end
	for _, region in ipairs(frame._regions or {}) do
		if region._type == "FontString" then
			return false
		end
	end
	return true
end

local function within(object, root)
	local node = object
	while node do
		if node == root then
			return true
		end
		node = node._parent
	end
	return false
end

Guard.COVER = 24

-- Clothes(backdrop, glass) -> the frame a backdrop's glass clothes: its target or parent, when the glass covers that
-- frame's rect to within COVER units on every side; nil for a backdrop on a container larger than its glass (a root
-- holder, a screen-wide parent), whose other children are not the card's content.
function Guard.Clothes(backdrop, glass)
	local frame = backdrop.target or backdrop._parent
	if not frame or frame._parent == nil or not frame._env then
		return nil
	end
	local x, y, w, h = Scene.Rect(frame._env, frame)
	if not x then
		return nil
	end
	local g = bounds(glass)
	local margin = { left = g.left - Guard.COVER, right = g.right + Guard.COVER, bottom = g.bottom - Guard.COVER, top = g.top + Guard.COVER }
	if Geometry.Outside(bounds({ x, y, w, h }), margin) > 0 then
		return nil
	end
	return frame
end

-- Cards(scene) -> the scene's cards: { frame, scope, glass = { x, y, w, h } }, smallest first. The glass is what
-- the page draws of the card's fill, inside any clip rect, and of any lens disc on the card itself (the minimap
-- card's arched top).
function Guard.Cards(scene)
	local byFrame, order = {}, {}
	local frost = {}
	for _, item in ipairs(scene.items) do
		local owner = item.object and item.object._parent
		if owner and item.kind == "texture" then
			local file = fileOf(item)
			if file:find("LumenFrost", 1, true) then
				frost[owner] = true
			elseif file:find("LumenShape", 1, true) or file:find("LensMask", 1, true) then
				if not byFrame[owner] then
					byFrame[owner] = { frame = owner }
					order[#order + 1] = owner
				end
				byFrame[owner].glass = union(byFrame[owner].glass, intersect(item.rect, item.clip))
			end
		end
	end
	local cards = {}
	for _, frame in ipairs(order) do
		if frost[frame] then
			local card = byFrame[frame]
			card.scope = frame
			if isBackdrop(frame) then
				card.scope = Guard.Clothes(frame, card.glass) or frame
			end
			cards[#cards + 1] = card
		end
	end
	table.sort(cards, function(a, b)
		return a.glass[3] * a.glass[4] < b.glass[3] * b.glass[4]
	end)
	return cards
end

local function ellipsis(item)
	if item.kind ~= "text" or item.wordWrap ~= false or (item.natural and item.natural.width) then
		return nil
	end
	local plain = Scene.PlainText(item.text)
	if plain:find("\n", 1, true) or item.rect[3] <= 0 then
		return nil
	end
	local ppu = Guard.ppu
	local need = Scene.TextWidth(plain, item.font.size, item.font.path)
	if need * ppu > item.rect[3] * ppu + 0.5 then
		return string.format("needs %.1f units, has %.1f", need, item.rect[3])
	end
	return nil
end

local function centre(r)
	return r[1] + r[3] / 2, r[2] + r[4] / 2
end

local function onGlass(x, y, g)
	return x >= g[1] and x <= g[1] + g[3] and y >= g[2] and y <= g[2] + g[4]
end

local function depth(frame)
	local n, node = 0, frame
	while node do
		n = n + 1
		node = node._parent
	end
	return n
end

-- Owner(cards, item, rect) -> the card a drawn item belongs to, or nil: of the cards whose content holds it in the
-- frame tree, the one whose content root is deepest; else, for a text, the smallest card its centre sits on. A
-- card's own chrome belongs to no card.
function Guard.Owner(cards, item, rect)
	local object = item.object
	local x, y = centre(rect)
	local tree, treeDepth, onto
	for _, card in ipairs(cards) do
		local chrome = object._parent == card.frame and fileOf(item):find("Lumen", 1, true)
		if not chrome then
			if card.scope and within(object, card.scope) then
				local d = depth(card.scope)
				if not tree or d > treeDepth then
					tree, treeDepth = card, d
				end
			elseif item.kind == "text" and not onto and onGlass(x, y, card.glass) then
				onto = card
			end
		end
	end
	return tree or onto
end

-- Excused(cards, card, rect) -> whether an item that belongs to card may sit where it does: wholly on its card's
-- glass, or wholly on the glass of a card that is not one of its card's holders (a popout list, hung in the tree
-- under the card that opened it). A holder's glass excuses nothing: a label spilled out of a panel onto the window
-- around it is still a spill.
function Guard.Excused(cards, card, rect)
	local r = bounds(rect)
	if Geometry.Outside(r, bounds(card.glass)) <= Guard.SLACK then
		return true
	end
	for _, other in ipairs(cards) do
		if other ~= card and not (other.scope and within(card.frame, other.scope)) and Geometry.Outside(r, bounds(other.glass)) <= Guard.SLACK then
			return true
		end
	end
	return false
end

-- Holder(cards, inner) -> the card whose content holds inner's frame most closely (its content root deepest),
-- whatever the two cards' sizes; nil for a card no other card holds.
function Guard.Holder(cards, inner)
	local best, bestDepth
	for _, outer in ipairs(cards) do
		if outer ~= inner and outer.scope and outer.scope ~= inner.frame and within(inner.frame, outer.scope) and not within(outer.frame, inner.frame) then
			local d = depth(outer.scope)
			if not best or d > bestDepth then
				best, bestDepth = outer, d
			end
		end
	end
	return best
end

local LINE = 1.2
local BASELINE = 0.78
local CAP = 0.72
local DESCENDER = 0.22
Guard.HIDDEN = 0.9
Guard.CROSS = 0.35

-- Ink(item) -> the rect a text's glyphs fill, as the page draws them (render.js drawText): the glyph table's
-- width set inside the rect by justifyH (the rect's width when the text wraps), and the lines' glyph boxes set by
-- justifyV, or at the side a natural-height text grows from. A natural-width text never wraps; a text with a
-- width wraps by the page's rule. Each line's glyphs run from CAP em above the baseline (BASELINE em under the
-- line's top, plus half the leading) to the baseline, or DESCENDER em below it when the text has descenders.
-- The glyphs are laid out in the text's own rect, then cut to its clip, so a clipped text's ink never moves into
-- view. The second return is one line's glyph height, which the crossing rule scales.
function Guard.Ink(item)
	local rect = item.rect
	local plain = Scene.PlainText(item.text)
	local size = item.font and item.font.size or 12
	local path = item.font and item.font.path
	local need = Scene.TextWidth(plain, size, path)
	local lines
	if item.natural and item.natural.width then
		local _, breaks = plain:gsub("\n", "")
		lines = breaks + 1
	elseif item.wordWrap ~= false and rect[3] > 0 then
		lines = Scene.WrappedLines(plain, size, path, rect[3])
	else
		local _, breaks = plain:gsub("\n", "")
		lines = breaks + 1
	end
	local lh = size * LINE
	local block = lines * lh
	local top = rect[2]
	if block < rect[4] then
		local side = item.grow or (item.natural and item.natural.height) or (item.justifyV == "MIDDLE" and "middle") or (item.justifyV == "BOTTOM" and "bottom") or "top"
		if side == "middle" then
			top = rect[2] + (rect[4] - block) / 2
		elseif side == "bottom" then
			top = rect[2] + rect[4] - block
		end
	end
	local descends = plain:find("[gjpqy,;]") ~= nil
	local glyph = (CAP + (descends and DESCENDER or 0)) * size
	-- A trailing blank line (a tooltip's name line ends in "\n ") takes room but draws no glyphs.
	local _, blank = plain:gsub("\n%s*$", "")
	local inked = math.max(1, lines - blank)
	local first = top + BASELINE * size + (lh - size) / 2 - CAP * size
	local last = top + (inked - 1) * lh + BASELINE * size + (lh - size) / 2 + (descends and DESCENDER or 0) * size
	local w = lines > 1 and rect[3] or math.min(need, rect[3])
	local x = rect[1]
	if item.justifyH == "CENTER" then
		x = rect[1] + (rect[3] - w) / 2
	elseif item.justifyH == "RIGHT" then
		x = rect[1] + rect[3] - w
	end
	local y0, y1 = math.max(first, rect[2]), math.min(last, rect[2] + rect[4])
	local ink = { x, y0, w, math.max(0, y1 - y0) }
	if item.clip then
		ink = intersect(ink, item.clip)
	end
	return ink, glyph
end

local function crossing(a, b)
	local w = math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1])
	local h = math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2])
	return w, h
end

-- Hides(item) -> whether a texture can hide a text under it: a solid colour, an icon (a file ID, or a file from an
-- Icons folder) or a kit fill slice (LumenShape), at an effective alpha of at least COVER_ALPHA. Any other art
-- (rims, outlines, bar glass, gradients) carries its own transparency the guard cannot read, so it is not judged.
function Guard.Hides(item)
	if item.kind ~= "texture" or item.masks and #item.masks > 0 then
		return false
	end
	local file = fileOf(item)
	local solid = item.color ~= nil and file == ""
	local icon = item.fileID ~= nil or file:lower():find("icons[/\\]") ~= nil
	local fill = file:find("LumenShape", 1, true) ~= nil
	if not (solid or icon or fill) then
		return false
	end
	local alpha = item.alpha or 1
	if item.color then
		alpha = alpha * (item.color[4] or 1)
	end
	if item.vertex then
		alpha = alpha * (item.vertex[4] or 1)
	end
	return alpha >= Guard.COVER_ALPHA
end

-- Top(object) -> the top-level element an object hangs in: its ancestor whose parent is a root (UIParent or an
-- unparented frame), or the object's root itself.
local function top(object)
	local node = object
	while node and node._parent and node._parent._parent do
		node = node._parent
	end
	return node
end

-- Check(scene) -> every finding in the scene, sorted by key. The scene must still carry its stub objects (call it
-- before the scene is written as JSON, or on a scene a test built).
function Guard.Check(scene)
	local findings, seen = {}, {}
	local function add(kind, item, card, detail, subject)
		subject = subject or subjectOf(item)
		local key = kind .. "|" .. subject
		if seen[key] then
			return
		end
		seen[key] = true
		findings[#findings + 1] = { kind = kind, subject = subject, card = card and keyPath(card.frame), detail = detail, key = key }
	end
	local cards = Guard.Cards(scene)
	local texts, drawn = {}, {}
	for _, inner in ipairs(cards) do
		local outer = Guard.Holder(cards, inner)
		if outer then
			local past = Geometry.Outside(bounds(inner.glass), bounds(outer.glass))
			if past > Guard.SLACK then
				local subject = keyPath(inner.frame) .. " glass"
				local key = "outside|" .. subject
				if not seen[key] then
					seen[key] = true
					findings[#findings + 1] = { kind = "outside", subject = subject, card = keyPath(outer.frame), detail = string.format("%.1f units past its card's glass", past), key = key }
				end
			end
		end
	end
	for _, item in ipairs(scene.items) do
		local why = ellipsis(item)
		if why then
			add("ellipsis", item, nil, why)
		end
		local object = item.object
		if object and not isDecor(item) and item.rect then
			local rect = intersect(item.rect, item.clip)
			if rect[3] > 0 and rect[4] > 0 then
				local card = Guard.Owner(cards, item, rect)
				if card and not Guard.Excused(cards, card, rect) then
					local past = Geometry.Outside(bounds(rect), bounds(card.glass))
					if past > Guard.SLACK then
						add("outside", item, card, string.format("%.1f units past its card's glass", past))
					end
				end
				if item.kind == "text" then
					local ink, glyph = Guard.Ink(item)
					if item.clip and not item.scroll then
						local whole = Guard.Ink({ rect = item.rect, text = item.text, font = item.font, natural = item.natural, wordWrap = item.wordWrap, grow = item.grow, justifyH = item.justifyH, justifyV = item.justifyV })
						local cut = Geometry.Outside(bounds(whole), bounds(item.clip))
						if cut > Guard.SLACK then
							add("clipped", item, card, string.format("%.1f units past the frame that clips it", cut))
						end
					end
					if ink[3] > 0 and ink[4] > 0 then
						texts[#texts + 1] = { item = item, ink = ink, glyph = glyph, group = card or top(object), card = card, at = #drawn + 1 }
					end
				elseif Guard.Hides(item) then
					-- A card's own glass belongs to no card, but hides what sits on it: it is grouped with its card.
					local own = card
					if not own then
						for _, each in ipairs(cards) do
							if each.frame == object._parent then
								own = each
								break
							end
						end
					end
					drawn[#drawn + 1] = { item = item, rect = rect, group = own or top(object) }
				end
			end
		end
	end
	-- A text under a covering texture another frame draws after it: hidden when the texture covers HIDDEN of its
	-- glyphs (a chip set over the tile it replaces), a finding when part of the text shows. Hidden texts take no part
	-- in the crossing check. Two texts cross when their glyph boxes share more than OVERLAP units across and more
	-- than CROSS of the smaller glyph height down, so a tangent kiss between lines is not a finding.
	for _, text in ipairs(texts) do
		local ink = text.ink
		local area = ink[3] * ink[4]
		local covered = {}
		for i = text.at, #drawn do
			local cover = drawn[i]
			local frame = cover.item.object._parent
			if cover.group == text.group and frame ~= text.item.object._parent then
				local w, h = crossing(ink, cover.rect)
				if w > 0 and h > 0 then
					-- A glass drawn as slices hides a text slice by slice: the slices one frame draws add up.
					covered[frame] = (covered[frame] or 0) + w * h
					if covered[frame] >= Guard.HIDDEN * area then
						text.hidden = true
						break
					elseif w > Guard.OVERLAP and h > math.max(Guard.OVERLAP, Guard.CROSS * text.glyph) then
						text.cover = text.cover or { cover = cover, w = w, h = h }
					end
				end
			end
		end
	end
	for i, text in ipairs(texts) do
		if not text.hidden then
			if text.cover then
				local a, b = subjectOf(text.item), subjectOf(text.cover.cover.item)
				if b < a then
					a, b = b, a
				end
				add("overlap", text.item, text.card, string.format("the texture covers the text by %.1f x %.1f units", text.cover.w, text.cover.h), a .. " & " .. b)
			end
			for j = i + 1, #texts do
				local other = texts[j]
				if not other.hidden and other.group == text.group then
					local w, h = crossing(text.ink, other.ink)
					if w > Guard.OVERLAP and h > math.max(Guard.OVERLAP, Guard.CROSS * math.min(text.glyph, other.glyph)) then
						local a, b = subjectOf(text.item), subjectOf(other.item)
						if a ~= b then
							if b < a then
								a, b = b, a
							end
							add("overlap", other.item, text.card, string.format("the texts cross by %.1f x %.1f units", w, h), a .. " & " .. b)
						end
					end
				end
			end
		end
	end
	table.sort(findings, function(a, b)
		return a.key < b.key
	end)
	return findings
end

local function glob(pattern)
	return "^" .. pattern:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*") .. "$"
end

-- LoadAllow(path) -> the allowlist: one entry per line, tab-separated: owner scope, scene glob, kind, subject
-- (its start, or "=" and the whole subject), reason. Lines starting with # and blank lines are skipped. A malformed line is an error, so a typo
-- cannot silently allow everything.
function Guard.LoadAllow(path)
	path = path or Guard.ALLOW
	local handle = io.open(path, "rb")
	if not handle then
		return {}
	end
	local entries, n = {}, 0
	for line in handle:lines() do
		n = n + 1
		line = line:gsub("\r$", "")
		if line ~= "" and not line:match("^#") then
			local owner, scene, kind, match, reason = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
			assert(owner, path .. ":" .. n .. ": owner, scene, kind, subject and reason, tab-separated")
			assert(Guard.OWNERS[owner], path .. ":" .. n .. ": unknown owner scope " .. owner)
			assert(Guard.KINDS[kind], path .. ":" .. n .. ": kind is ellipsis, outside, clipped or overlap")
			entries[#entries + 1] = { owner = owner, scene = scene, pattern = glob(scene), kind = kind, match = match, reason = reason, line = n }
		end
	end
	handle:close()
	return entries
end

-- Covers(match, subject) -> whether an allowlist line's subject covers a finding's: "=text" is the whole subject,
-- anything else its start.
function Guard.Covers(match, subject)
	if match:sub(1, 1) == "=" then
		return subject == match:sub(2)
	end
	return subject:sub(1, #match) == match
end

-- Sort(findings, allow, sceneName) -> fresh, allowed, stale: the findings no entry covers, the findings an entry
-- covers (each with .entry), and the entries naming this scene alone that matched nothing (fixed: delete the line).
-- An entry whose scene is a glob spans scenes, so one scene cannot call it stale.
function Guard.Sort(findings, allow, sceneName)
	local fresh, allowed, used = {}, {}, {}
	for _, finding in ipairs(findings) do
		local hit
		for _, entry in ipairs(allow) do
			if entry.kind == finding.kind and sceneName:match(entry.pattern) and Guard.Covers(entry.match, finding.subject) then
				hit = entry
				break
			end
		end
		if hit then
			used[hit] = true
			finding.entry = hit
			allowed[#allowed + 1] = finding
		else
			fresh[#fresh + 1] = finding
		end
	end
	local stale = {}
	for _, entry in ipairs(allow) do
		if not used[entry] and not entry.scene:find("*", 1, true) and sceneName:match(entry.pattern) then
			stale[#stale + 1] = entry
		end
	end
	return fresh, allowed, stale
end

-- Stale(allow, runs) -> the glob entries a run proved stale: runs is { { scene = name, findings = findings }, ... },
-- every scene of one render run (a gallery, the class renders, the regression sweep); an entry whose glob matched
-- at least one of those scenes and covered no finding in any of them is stale (fixed: delete the line). A glob
-- that matched no scene of the run is not judged, since the run never drew what it allows.
function Guard.Stale(allow, runs)
	local stale = {}
	for _, entry in ipairs(allow) do
		if entry.scene:find("*", 1, true) then
			local matched, used = false, false
			for _, run in ipairs(runs) do
				if run.scene:match(entry.pattern) then
					matched = true
					for _, finding in ipairs(run.findings) do
						if entry.kind == finding.kind and Guard.Covers(entry.match, finding.subject) then
							used = true
							break
						end
					end
				end
				if used then
					break
				end
			end
			if matched and not used then
				stale[#stale + 1] = entry
			end
		end
	end
	return stale
end

-- Lines(fresh, allowed, stale, mode) -> the report lines and whether the run fails. mode is "report" (list all,
-- never fail), "default" (fail on a fresh finding) or "strict" (also fail on a stale entry, so a fixed defect
-- leaves the list in the same PR: what the publish run uses). Allowlisted findings are always listed, with owner.
function Guard.Lines(fresh, allowed, stale, mode)
	local lines = {}
	for _, f in ipairs(fresh) do
		lines[#lines + 1] = "guard: " .. f.kind .. ": " .. f.subject .. " (" .. f.detail .. (f.card and (", card " .. f.card) or "") .. ")"
	end
	for _, f in ipairs(allowed) do
		lines[#lines + 1] = "guard: allowed (" .. f.entry.owner .. "): " .. f.kind .. ": " .. f.subject .. " (" .. f.detail .. ")"
	end
	for _, e in ipairs(stale) do
		lines[#lines + 1] = "guard: stale allowlist line " .. e.line .. " (" .. e.owner .. "): " .. e.kind .. " " .. e.match .. " matched nothing; delete it"
	end
	local fails = false
	if mode == "strict" then
		fails = #fresh + #stale > 0
	elseif mode ~= "report" then
		fails = #fresh > 0
	end
	return lines, fails
end

-- WriteRaw(findings, path) and ReadRaw(path): the findings as tab-separated lines (kind, subject, detail, card), the
-- sidecar shoot.sh passes from the scene step through the page step (which adds the texts it truncated) to the verdict.
local function clean(s)
	return (tostring(s or ""):gsub("[\t\r\n]", " "))
end

function Guard.WriteRaw(findings, path)
	local handle = assert(io.open(path, "wb"))
	for _, f in ipairs(findings) do
		handle:write(clean(f.kind), "\t", clean(f.subject), "\t", clean(f.detail), "\t", clean(f.card), "\n")
	end
	handle:close()
end

function Guard.ReadRaw(path)
	local out, seen = {}, {}
	local handle = io.open(path, "rb")
	if not handle then
		return out
	end
	for line in handle:lines() do
		local kind, subject, detail, card = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t?([^\t]*)$")
		if kind and kind ~= "" then
			local key = kind .. "|" .. subject
			if not seen[key] then
				seen[key] = true
				out[#out + 1] = { kind = kind, subject = subject, detail = detail, card = card ~= "" and card or nil, key = key }
			end
		end
	end
	handle:close()
	table.sort(out, function(a, b)
		return a.key < b.key
	end)
	return out
end

-- Verdict(scene, rawPath, mode, paged) -> lines, fails: the allowlist applied to a scene's raw findings. Without
-- the page step (paged false: shoot.sh --json-only) the page's truncations are unknown, so no ellipsis line is stale.
function Guard.Verdict(sceneName, rawPath, mode, paged)
	local fresh, allowed, stale = Guard.Sort(Guard.ReadRaw(rawPath), Guard.LoadAllow(), sceneName)
	if paged == false then
		local kept = {}
		for _, entry in ipairs(stale) do
			if entry.kind ~= "ellipsis" then
				kept[#kept + 1] = entry
			end
		end
		stale = kept
	end
	return Guard.Lines(fresh, allowed, stale, mode)
end

-- GlobLines(stale) -> the report lines for the glob entries a run proved stale.
function Guard.GlobLines(stale)
	local lines = {}
	for _, e in ipairs(stale) do
		lines[#lines + 1] = "guard: stale allowlist line " .. e.line .. " (" .. e.owner .. "): " .. e.kind .. " " .. e.match .. " (" .. e.scene .. ") matched nothing in any scene of this run; delete it"
	end
	return lines
end

-- Globs(rawPaths, mode) -> lines, fails: the glob lines judged by a run's raw sidecars (out/<scene>.guard.tsv, the
-- scene named by the file); fails in strict mode when any is stale.
function Guard.Globs(rawPaths, mode)
	local runs = {}
	for _, path in ipairs(rawPaths) do
		local scene = path:match("([^/\\]+)%.guard%.tsv$")
		if scene then
			runs[#runs + 1] = { scene = scene, findings = Guard.ReadRaw(path) }
		end
	end
	local stale = Guard.Stale(Guard.LoadAllow(), runs)
	return Guard.GlobLines(stale), mode == "strict" and #stale > 0
end

-- As a script: lua Tools/render/guard.lua <scene> <raw.tsv> [report|default|strict] [json-only]; exit 3 when the
-- scene fails. Or, after a run of several scenes: lua Tools/render/guard.lua --globs <mode> <raw.tsv>...; exit 3
-- in strict mode when a glob line matched nothing in any scene of the run.
if arg and arg[0] and arg[0]:match("guard%.lua$") and arg[1] then
	local lines, fails
	if arg[1] == "--globs" then
		local paths = {}
		for i = 3, #arg do
			paths[#paths + 1] = arg[i]
		end
		lines, fails = Guard.Globs(paths, arg[2] or "default")
	else
		lines, fails = Guard.Verdict(arg[1], arg[2], arg[3] or "default", arg[4] ~= "json-only")
	end
	for _, line in ipairs(lines) do
		io.stderr:write(line, "\n")
	end
	if fails then
		io.stderr:write("guard: ", arg[1] == "--globs" and "the run" or arg[1], " fails the render guard (Tools/render/README.md, Render guard)\n")
		os.exit(3)
	end
end

return Guard
