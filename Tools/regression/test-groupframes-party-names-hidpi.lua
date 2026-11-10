local check = dofile("Tools/regression/group_names_env.lua")

check({ { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } })

print("party names: high-density screens ok")
