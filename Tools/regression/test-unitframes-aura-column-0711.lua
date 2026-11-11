-- test-unitframes-aura-column-0711.lua: the column target's debuff row stays inside its reserve at UI scale 768 / 1080, every screen and interface size.
dofile("Tools/regression/aura_column_lib.lua").Run(768 / 1080)
print("unitframes aura column 768 / 1080 ok")
