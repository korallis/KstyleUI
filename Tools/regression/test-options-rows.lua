-- test-options-rows.lua: settings help text wraps, every row grows to hold it, and no label or help line runs under a control, at the window's default and minimum sizes.
local Scene = dofile("Tools/render/scene.lua")
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local Module = W.CoreEnv.Module

local LONG = "Snaps every frame you move in Layout Mode to the grid and to the edges of the frames around it."

local env, K, ns = O.New({
	before = function(_, K)
		K.Modules.Register(Module("UnitFrames", { defaults = { snap = true, size = 20, style = "solid" } }))
		K.Options.Register("UnitFrames", {
			{ type = "header", label = "Placement" },
			{ type = "toggle", key = "snap", label = "Snap to grid", help = LONG },
			{ type = "slider", key = "size", label = "Grid size", help = LONG, min = 10, max = 40, step = 1 },
			{ type = "dropdown", key = "style", label = "Grid style", help = "Lines or dots.", options = {
				{ value = "solid", label = "Lines" }, { value = "dots", label = "Dots" },
			} },
		})
	end,
})

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function rect(object)
	local x, y, w, h = Scene.Rect(env, object)
	if not x then
		return nil
	end
	return { left = x, top = y, right = x + w, bottom = y + h }
end

local function drawn(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			local r = item.rect
			return { left = r[1], top = r[2], right = r[1] + r[3], bottom = r[2] + r[4] }
		end
	end
end

local EPS = 0.01
local function inside(a, b)
	return a.left >= b.left - EPS and a.right <= b.right + EPS and a.top >= b.top - EPS and a.bottom <= b.bottom + EPS
end
local function overlaps(a, b)
	return a.left < b.right - EPS and b.left < a.right - EPS and a.top < b.bottom - EPS and b.top < a.bottom - EPS
end
local function describe(r)
	return string.format("(%.1f, %.1f to %.1f, %.1f)", r.left, r.top, r.right, r.bottom)
end

local function resize(width, height)
	local win = ns.Window.Frame()
	K.Widgets.Size(win, width, height)
	win:Restyle()
	local content = ns.Window.Parts().content
	content:GetScript("OnSizeChanged")(content, content:GetWidth(), content:GetHeight())
	ns.Window.Refresh()
	settle()
end

-- Check every row the list shows wholly inside its view.
local function check(page, width, height)
	K.Options.Open(page)
	settle()
	resize(width, height)
	local content = ns.Window.Parts().content
	local view = rect(content.view)
	local scene = Scene.Build(env)
	local checked, previous = 0, nil
	local rows = {}
	for _, row in ipairs(content.rows) do
		if row:IsShown() and row.index then
			rows[#rows + 1] = row
		end
	end
	table.sort(rows, function(a, b)
		return a.index < b.index
	end)
	for _, row in ipairs(rows) do
		local box = rect(row)
		local where = page .. " at " .. width .. " by " .. height .. ", row " .. row.index .. " (" .. tostring(row.item.label) .. ")"
		if previous then
			assert(box.top >= previous.bottom - EPS, where .. " starts above the row before it ends")
		end
		previous = box
		if box.top >= view.top - EPS and box.bottom <= view.bottom + EPS then
			local kind = row.item.kind
			local control = row.controls[kind]
			local controlBox = control and control:IsShown() and rect(control)
			if kind == "note" then
				local note = assert(drawn(scene, row.note), where .. ": the note draws")
				assert(inside(note, box), where .. ": the note " .. describe(note) .. " fits its row " .. describe(box))
			elseif kind ~= "header" then
				local wrap = W.LastCall(row.help, "SetWordWrap")
				assert(wrap and wrap[1] == true, where .. ": help text wraps")
				local label = assert(drawn(scene, row.label), where .. ": the label draws")
				assert(inside(label, box), where .. ": the label " .. describe(label) .. " fits its row " .. describe(box))
				local help = row.item.help and row.item.help ~= "" and drawn(scene, row.help)
				if help then
					assert(inside(help, box), where .. ": the help " .. describe(help) .. " fits its row " .. describe(box))
					assert(help.right - help.left >= 200, where .. ": the help gets a readable measure, got " .. (help.right - help.left))
					assert(help.top >= label.bottom - EPS, where .. ": the help sits under the label")
				end
				if controlBox then
					assert(inside(controlBox, box), where .. ": the control " .. describe(controlBox) .. " fits its row " .. describe(box))
					assert(not overlaps(label, controlBox), where .. ": the label " .. describe(label) .. " runs under the control " .. describe(controlBox))
					if help then
						assert(not overlaps(help, controlBox), where .. ": the help " .. describe(help) .. " runs under the control " .. describe(controlBox))
					end
				end
			end
			checked = checked + 1
		end
	end
	assert(checked >= 3, page .. " at " .. width .. " by " .. height .. ": only " .. checked .. " rows were checked")
	return checked
end

for _, size in ipairs({ { 1040, 680 }, { 880, 520 } }) do
	for _, page in ipairs({ "UnitFrames", "General" }) do
		check(page, size[1], size[2])
		local content = ns.Window.Parts().content
		for _ = 1, 40 do
			content:ScrollTo(content:GetOffset() + 120, true)
			settle()
			check(page, size[1], size[2])
			if content:GetOffset() >= content:GetMaxOffset() then
				break
			end
		end
	end
end

-- A row whose help is long grows past the standard row height; a short one keeps it.
do
	K.Options.Open("UnitFrames")
	settle()
	resize(880, 520)
	local content = ns.Window.Parts().content
	local tall, short
	for i, item in ipairs(ns.Window.State().items) do
		local top = content.tops and content.tops[i]
		local height = top and content.tops[i + 1] - top
		if item.label == "Snap to grid" then
			tall = height
		elseif item.label == "Grid style" then
			short = height
		end
	end
	assert(tall and tall > ns.Rows.HEIGHT, "the long help's row grows, got " .. tostring(tall))
	assert(short == ns.Rows.HEIGHT, "a one-line help keeps the standard row, got " .. tostring(short))
end

assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))
print("options rows ok")
