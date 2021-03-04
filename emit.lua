DEBUG_EMIT_PRINT = true


function debug_print(...)
	if DEBUG_EMIT_PRINT then
		print(...)
	end
end


emit = {}


function emit.noop (prog)
	debug_print(#prog + 1, "noop")
	table.insert(prog, function (state)
		state.ip = state.ip + 1
	end)
end


function emit.push (prog, n)
	debug_print(#prog + 1, "push " .. n)
	table.insert(prog, function (state)
		table.insert(state.dstack, n)
		state.ip = state.ip + 1
	end)
end

function emit.push_array (prog, a)
	debug_print(#prog + 1, "push array (" .. #a .. ")")
	table.insert(prog, function (state)
		table.insert(state.astack, a)
		table.insert(state.alstack, #a)
		state.ip = state.ip + 1
	end)
end


function emit.add (prog)
	debug_print(#prog + 1, "add")
	table.insert(prog, function (state)
		state.ip = state.ip + 1
		local i = table.remove(state.dstack)
		local j = table.remove(state.dstack)
		table.insert(state.dstack, i + j)
	end)
end


function emit.eq (prog)
	debug_print(#prog + 1, "eq")
	table.insert(prog, function (state)
		local i = table.remove(state.dstack)
		local j = table.remove(state.dstack)
		if j == i then
			table.insert(state.dstack, -1)
		else
			table.insert(state.dstack, 0)
		end
		state.ip = state.ip + 1
	end)
end


function emit.gt (prog)
	debug_print(#prog + 1, "gt")
	table.insert(prog, function (state)
		local i = table.remove(state.dstack)
		local j = table.remove(state.dstack)
		if j > i then
			table.insert(state.dstack, -1)
		else
			table.insert(state.dstack, 0)
		end
		state.ip = state.ip + 1
	end)
end


function emit.lt (prog)
	debug_print(#prog + 1, "lt")
	table.insert(prog, function (state)
		local i = table.remove(state.dstack)
		local j = table.remove(state.dstack)
		if j < i then
			table.insert(state.dstack, -1)
		else
			table.insert(state.dstack, 0)
		end
		state.ip = state.ip + 1
	end)
end


function emit.lnot (prog)
	debug_print(#prog + 1, "lnot")
	table.insert(prog, function (state)
		local i = table.remove(state.dstack)
		if i ~= 0 then
			table.insert(state.dstack, -1)
		else
			table.insert(state.dstack, 0)
		end
		state.ip = state.ip + 1
	end)
end


function emit.swap (prog)
	debug_print(#prog + 1, "swap")
	table.insert(prog, function (state)
		local len = #state.dstack
		state.dstack[len - 1], state.dstack[len] = state.dstack[len], state.dstack[len - 1]
		state.ip = state.ip + 1
	end)
end


function emit.array_swap (prog)
	debug_print(#prog + 1, "array swap")
	table.insert(prog, function (state)
		local len = #state.alstack
		state.alstack[len - 1], state.alstack[len] = state.alstack[len], state.alstack[len - 1]
		state.astack[len - 1], state.astack[len] = state.astack[len], state.astack[len - 1]
		state.ip = state.ip + 1
	end)
end


function emit.copy (prog)
	debug_print(#prog + 1, "copy")
	table.insert(prog, function (state)
		local tos = state.dstack[#state.dstack]
		table.insert(state.dstack, tos)
		state.ip = state.ip + 1
	end)
end


function emit.array_copy (prog)
	debug_print(#prog + 1, "array copy")
	table.insert(prog, function (state)
		local len = #state.alstack
		table.insert(state.alstack, state.alstack[len])
		table.insert(state.astack, state.astack[len])
		state.ip = state.ip + 1
	end)
end


function emit.write (prog)
	debug_print(#prog + 1, "write")
	table.insert(prog, function (state)
		local n = table.remove(state.dstack)
		local c = string.char(n)
		io.write(c)
		state.ip = state.ip + 1
	end)
end


function emit.array_write (prog)
	debug_print(#prog + 1, "array write")
	table.insert(prog, function (state)
		local n = table.remove(state.alstack)
		local data = table.remove(state.astack)
		for k,v in ipairs(data) do
			local c = string.char(v)
			io.write(c)
		end
		state.ip = state.ip + 1
	end)
end


function emit.read (prog)
	debug_print(#prog + 1, "read")
	table.insert(prog, function (state)
		local c = io.read(1)
		local n = string.byte(c)
		table.insert(state.dstack, n)
		state.ip = state.ip + 1
	end)
end


function emit.exit (prog)
	debug_print(#prog + 1, "exit")
	table.insert(prog, function (state)
		state.running = false
	end)
end


function emit.jump (prog, dest)
	debug_print(#prog + 1, "jump " .. dest)
	table.insert(prog, function (state)
		state.ip = dest
	end)
end


function emit.seek (prog, n)
	local dest = #prog + n + 1
	emit.jump(prog, dest)
end


function emit.enter (prog, label, dest)
	debug_print(#prog + 1, "enter " .. label .. " " .. dest)
	table.insert(prog, function (state)
		if state.label == label then
			state.ip = state.ip + 1
		else
			state.ip = dest
		end
	end)
end


function emit.switch (prog)
	debug_print(#prog + 1, "switch")
	table.insert(prog, function (state)
		state.label = table.remove(state.dstack)
		state.ip = 1
	end)
end


function emit.cond (prog, skip_dest)
	debug_print(#prog + 1, "cond " .. skip_dest)
	table.insert(prog, function (state)
		local n = table.remove(state.dstack)
		if n ~= 0 then
			state.cond = true
			state.ip = state.ip + 1
		else
			state.ip = skip_dest
		end
	end)
end


function emit.set_reg (prog, reg)
	debug_print(#prog + 1, "set " .. reg)
	table.insert(prog, function (state)
		local n = table.remove(state.dstack)
		state.reg[reg] = n
		state.ip = state.ip + 1
	end)
end


function emit.get_reg (prog, reg)
	debug_print(#prog + 1, "get " .. reg)
	table.insert(prog, function (state)
		local n = state.reg[reg]
		table.insert(state.dstack, n)
		state.ip = state.ip + 1
	end)
end
