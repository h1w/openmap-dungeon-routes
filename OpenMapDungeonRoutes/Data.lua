local _, NS = ...
local Data = {}
NS.Data = Data

function Data.BuildFloors(dr, instanceID)
	local floors, seen = {}, {}
	for _, dungeon in ipairs(dr.Dungeons) do
		if dungeon.instanceID == instanceID then
			for _, id in ipairs(dungeon.floors) do
				local info = dr.Floors[id]
				if info and not seen[id] then
					seen[id] = true
					floors[#floors + 1] = {
						fdrFloor = id, fdrKey = dungeon.key, tiles = info.tiles,
						image = info.image, credit = info.credit,
						name = dr.LocText(info, "name"),
						wing = dungeon.name:gsub(": ", " - "),
					}
				end
			end
		end
	end
	return floors
end


-- OpenMap's page is 1002x668, whereas picture files may include padding.
function Data.ImageCrop(image, tile)
	local col, row = (tile - 1) % 4, math.floor((tile - 1) / 4)
	local right, bottom = image.right or 1, image.bottom or 1
	return col * 256 / 1002 * right, row * 256 / 668 * bottom,
		math.min((col + 1) * 256, 1002) / 1002 * right,
		math.min((row + 1) * 256, 668) / 668 * bottom
end
