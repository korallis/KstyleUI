-- test-groupframes-medallions-tiles-wide.lua: the Medallions raid tile on the ultrawide CREW screens and the MacBook window, 3440x1440, 5120x1440, 3840x1080 and 2383x1540 (medallions_tiles.lua has the check).
dofile("Tools/regression/medallions_tiles.lua").Run({ { 3440, 1440 }, { 5120, 1440 }, { 3840, 1080 }, { 2383, 1540 } }, "test-groupframes-medallions-tiles-wide")
