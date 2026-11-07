-- History.lua: Layout Mode's undo and redo stacks, with a size limit and merging of repeated nudges.
local _, ns = ...

local Layout = ns.Layout or {}
ns.Layout = Layout

local History = {}
Layout.History = History

local Stack = {}
Stack.__index = Stack

function History.New(limit)
	return setmetatable({ limit = limit or 100, undo = {}, redo = {} }, Stack)
end

local function merge(into, entry)
	for key, change in pairs(entry.changes or {}) do
		local existing = into.changes[key]
		if existing then
			existing.after = change.after
		else
			into.changes[key] = change
		end
	end
end

function Stack:Push(entry)
	local undo = self.undo
	local top = undo[#undo]
	local canMerge = #self.redo == 0 and top ~= nil and entry.merge ~= nil and top.merge == entry.merge and top.changes ~= nil
	self.redo = {}
	if canMerge then
		merge(top, entry)
		return
	end
	undo[#undo + 1] = entry
	while #undo > self.limit do
		table.remove(undo, 1)
	end
end

function Stack:Undo()
	local entry = table.remove(self.undo)
	if entry then
		self.redo[#self.redo + 1] = entry
	end
	return entry
end

function Stack:Redo()
	local entry = table.remove(self.redo)
	if entry then
		self.undo[#self.undo + 1] = entry
	end
	return entry
end

function Stack:CanUndo()
	return #self.undo > 0
end

function Stack:CanRedo()
	return #self.redo > 0
end

function Stack:Size()
	return #self.undo
end

function Stack:Clear()
	self.undo, self.redo = {}, {}
end
