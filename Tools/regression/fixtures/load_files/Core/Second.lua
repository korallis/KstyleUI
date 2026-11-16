local _, ns = ...
ns.order[#ns.order + 1] = 'Second'
ns.frame = CreateFrame('Frame', 'KstyleUITestFrame')
ns.kind = type(Secret(3))
