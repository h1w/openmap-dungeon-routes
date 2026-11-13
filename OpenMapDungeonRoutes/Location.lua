local _, NS = ...
local Location = {}
NS.Location = Location

function Location.Resolve(dr, key, floor)
	if key ~= dr.currentKey then return end
	local located, actualFloor, u, v = dr:LocatePlayer(floor)
	u, v = dr.Safe(u), dr.Safe(v)
	if located == key and actualFloor then
		if actualFloor ~= floor then return end
		if type(u) == "number" and type(v) == "number" then
			return { kind = "exact", x = u, y = v, facing = dr:GetPlayerFacing() }
		end
	end
	local room = dr.Room:Get()
	if room and dr.Room:OnFloor(room, floor) then
		u, v = dr.Room:Center(room, floor)
		if u then return { kind = "room", x = u, y = v, room = room } end
	end
end

function Location.FollowFloor(dr, key, preferred)
	if key ~= dr.currentKey then return end
	local located, floor = dr:LocatePlayer(preferred)
	if located == key and floor then return floor end
	local room = dr.Room:Get()
	if room then
		if preferred and dr.Room:OnFloor(room, preferred) then return preferred end
		return dr.Room:MainFloor(room)
	end
	local route = dr:GetActiveRoute(key)
	local nextStop = route and dr:GetNextStopIndex(key, route)
	return nextStop and route.stops[nextStop].floor
end
