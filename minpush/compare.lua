function compare (a, b)
	-- Compare two objects recursively
	local t = type(a)
	if t ~= type(b) then
		return false
	elseif t == "table" then
		for key, value in pairs(a) do
			if not compare(value, b[key]) then
				return false
			end
		end
		for key in pairs(b) do
			if a[key] == nil then
				return false
			end
		end
		return true
	else
		return a == b
	end
end