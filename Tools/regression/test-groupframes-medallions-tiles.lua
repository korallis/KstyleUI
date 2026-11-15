-- test-groupframes-medallions-tiles.lua: the Medallions raid tile on the 16:9 CREW screens, 1280x720 to 3840x2160 (medallions_tiles.lua has the check; test-groupframes-medallions-tiles-wide.lua the other screens).
dofile("Tools/regression/medallions_tiles.lua").Run({ { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 } }, "test-groupframes-medallions-tiles")
