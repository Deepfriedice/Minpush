ops = {}


ops.noop = function (state)
	state.ip = state.ip + 1
end


ops.push_n = function (n)
	return function (state)
		state.ip = state.ip + 1
		table.insert(state.dstack, n)
	end
end


ops.add = function (state)
	state.ip = state.ip + 1
	local i = table.remove(state.dstack)
	local j = table.remove(state.dstack)
	table.insert(state.dstack, i + j)
end


ops.swap = function (state)
	state.ip = state.ip + 1
	local len = #state.dstack
	state.dstack[len - 1], state.dstack[len] = state.dstack[len], state.dstack[len - 1]
end


ops.copy = function (state)
	state.ip = state.ip + 1
	local tos = state.dstack[#state.dstack]
	table.insert(state.dstack, tos)
end


ops.write = function (state)
	state.ip = state.ip + 1
	local n = table.remove(state.dstack)
	local c = string.char(n)
	io.write(c)
end


ops.read = function (state)
	state.ip = state.ip + 1
	table.insert(state.dstack, io.read(1))
end


ops.exit = function (state)
	state.running = false
end


ops.restart = function (state)
	state.ip = 1
end


ops.jump_n = function (n)
	return function (state)
		state.ip = n
	end
end


ops.seek_n = function (n)
	return function (state)
		state.ip = state.ip + n
	end
end


ops.enter = function (label)
	return function (state)
		--TODO
	end
end


ops.cond = function (post)
	return function (state)
		local n = table.remove(state.dstack)
		if n ~= 0 then
			state.cond = true
			state.ip = state.ip + 1
		else
			state.ip = post
		end
	end
end
