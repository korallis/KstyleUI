-- test-options-preview.lua: a settings schema may carry a preview builder, which Options.Preview returns for the settings window.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises, Module = CoreEnv.Raises, CoreEnv.Module

local function fresh()
	local env, K = CoreEnv.New()
	K.Modules.Register(Module("UnitFrames", { defaults = { width = 220 } }))
	return env, K
end

local function rows()
	return {
		{ type = "header", label = "Frames" },
		{ type = "slider", key = "width", label = "Width", help = "Frame width in units.", min = 100, max = 400, step = 1 },
	}
end

-- A schema's preview builder is kept and returned ---------------------------------------------------

do
	local _, K = fresh()
	local schema = rows()
	local function build(parent)
		return parent
	end
	schema.preview = build
	K.Options.Register("UnitFrames", schema)
	assert(K.Options.Preview("UnitFrames") == build, "Preview returns the schema's builder")
	assert(#K.Options.Get("UnitFrames") == 2, "the preview field is not a row")
	assert(K.Options.Preview("Appearance") == nil, "a schema without a preview returns nil")
	assert(K.Options.Preview("ActionBars") == nil, "a module with no schema returns nil")
end

-- A preview that is not a function, and other named fields, are refused ----------------------------

do
	local _, K = fresh()
	local schema = rows()
	schema.preview = "draw a frame"
	Raises(function() K.Options.Register("UnitFrames", schema) end, "preview must be a function(parent)", "a preview that is not a function")
end

do
	local _, K = fresh()
	local schema = rows()
	schema.title = "Unit frames"
	Raises(function() K.Options.Register("UnitFrames", schema) end, "list of rows with no gaps", "another named field")
end

print("options preview ok")
