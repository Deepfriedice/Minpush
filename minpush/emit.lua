WORD_MASK = 0xffffffff
BYTE_MASK = 0xff


DEBUG_EMIT_PRINT = false


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
		table.insert(state.stack, n)
		state.ip = state.ip + 1
	end)
end


function emit.push_bytes (prog, bytes)
	debug_print(#prog + 1, "push bytes (" .. #bytes .. ")")
	table.insert(prog, function (state)
		--append bytes onto the array
		table.move(bytes, 1, #bytes, #state.array+1, state.array)
		state.ip = state.ip + 1
	end)
end


function emit.add (prog)
	debug_print(#prog + 1, "add")
	table.insert(prog, function (state)
		state.ip = state.ip + 1
		local i = table.remove(state.stack)
		local j = table.remove(state.stack)
		table.insert(state.stack, i + j)
	end)
end


function emit.eq (prog)
	debug_print(#prog + 1, "eq")
	table.insert(prog, function (state)
		local i = table.remove(state.stack)
		local j = table.remove(state.stack)
		if j == i then
			table.insert(state.stack, -1)
		else
			table.insert(state.stack, 0)
		end
		state.ip = state.ip + 1
	end)
end


function emit.gt (prog)
	debug_print(#prog + 1, "gt")
	table.insert(prog, function (state)
		local i = table.remove(state.stack)
		local j = table.remove(state.stack)
		if j > i then
			table.insert(state.stack, -1)
		else
			table.insert(state.stack, 0)
		end
		state.ip = state.ip + 1
	end)
end


function emit.lt (prog)
	debug_print(#prog + 1, "lt")
	table.insert(prog, function (state)
		local i = table.remove(state.stack)
		local j = table.remove(state.stack)
		if j < i then
			table.insert(state.stack, -1)
		else
			table.insert(state.stack, 0)
		end
		state.ip = state.ip + 1
	end)
end


function emit.bnot (prog)
	debug_print(#prog + 1, "bit not")
	table.insert(prog, function (state)
		local len = #state.stack
		state.stack[len] = ~state.stack[len]
		state.ip = state.ip + 1
	end)
end


function emit.swap (prog)
	debug_print(#prog + 1, "swap")
	table.insert(prog, function (state)
		local len = #state.stack
		state.stack[len - 1], state.stack[len] = state.stack[len], state.stack[len - 1]
		state.ip = state.ip + 1
	end)
end


function emit.copy (prog)
	debug_print(#prog + 1, "copy")
	table.insert(prog, function (state)
		local tos = state.stack[#state.stack]
		table.insert(state.stack, tos)
		state.ip = state.ip + 1
	end)
end


function emit.array_copy (prog)
	debug_print(#prog + 1, "array copy")
	table.insert(prog, function (state)
		local count = table.remove(state.stack)
		local index = table.remove(state.stack) + 1
		assert(index >= 1, "array copy from before start of array")
		table.move(state.array, index, count, #state.array+1)
		state.ip = state.ip + 1
	end)
end


function emit.array_insert (prog)
	debug_print(#prog + 1, "array insert")
	table.insert(prog, function (state)
		local count = table.remove(state.stack)
		local dst_index = table.remove(state.stack) + 1
		local src_index = #state.array - count + 1
		assert(src_index <= #state.array, "array insert from before start of array")
		assert(dst_index <= #state.array, "array insert to before start of array")

		-- copy the data to insert
		local temp = table.move(state.array, src_index, #state.array, 1, {})

		-- move the data down by count bytes to make space
		table.move(state.array, dst_index, src_index-1, dst_index+count)

		-- insert
		table.move(temp, 1, count, dst_index, state.array)

		state.ip = state.ip + 1
	end)
end



function emit.array_remove (prog)
	debug_print(#prog + 1, "array remove")
	table.insert(prog, function (state)
		local count = table.remove(state.stack)
		local index = table.remove(state.stack) + 1
		assert(index >= 1, "array remove from before start of array")
		table.move(state.array, index + count, #state.array, index)
		for i = #state.array + 1 - count, #state.array do
			state.array[i] = nil
		end
		state.ip = state.ip + 1
	end)
end


function emit.write (prog)
	debug_print(#prog + 1, "write")
	table.insert(prog, function (state)
		local n = table.remove(state.stack)
		n = n & BYTE_MASK
		local c = string.char(n)
		state.output:write(c)
		state.ip = state.ip + 1
	end)
end


function emit.array_write (prog)
	debug_print(#prog + 1, "array write")
	table.insert(prog, function (state)
		local count = table.remove(state.stack)
		local start_index = table.remove(state.stack) + 1
		for i = start_index, start_index + count do
			local v = state.array[i]
			local c = string.char(v)
			state.output:write(c)
		end
		state.ip = state.ip + 1
	end)
end


function emit.read (prog)
	debug_print(#prog + 1, "read")
	table.insert(prog, function (state)
		local c = state.input:read(1)
		if c == nil then
			table.insert(state.stack, 0)
			table.insert(state.stack, 0)
		else
			local n = string.byte(c)
			table.insert(state.stack, n)
			table.insert(state.stack, -1)
		end
		state.ip = state.ip + 1
	end)
end


function emit.trim (prog)
	debug_print(#prog + 1, "trim")
	table.insert(prog, function (state)
		table.remove(state.stack)
		state.ip = state.ip + 1
	end)
end


function emit.get_array_length (prog)
	debug_print(#prog + 1, "get array length")
	table.insert(prog, function (state)
		table.insert(state.stack, #state.array)
		state.ip = state.ip + 1
	end)
end


function emit.set_array_length (prog)
	debug_print(#prog + 1, "set array length")
	table.insert(prog, function (state)
		local new_length = table.remove(state.stack)
		local old_length = #state.array
		for i = old_length + 1, new_length do
			state.array[i] = 0
		end
		for i = new_length + 1, old_length do
			state.array[i] = nil
		end
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


function emit.switch (prog, target)
	debug_print(#prog + 1, "switch " .. target)
	table.insert(prog, function (state)
		state.label = target
		state.ip = 1
	end)
end


function emit.cond_switch (prog, target)
	debug_print(#prog + 1, "cond switch " .. target)
	table.insert(prog, function (state)
		local n = table.remove(state.stack)
		if n ~= 0 then
			state.label = target
			state.ip = 1
		else
			state.ip = state.ip + 1
		end
	end)
end


function emit.set_reg (prog, reg)
	debug_print(#prog + 1, "set " .. reg)
	table.insert(prog, function (state)
		local n = table.remove(state.stack)
		state.reg[reg] = n
		state.ip = state.ip + 1
	end)
end


function emit.get_reg (prog, reg)
	debug_print(#prog + 1, "get " .. reg)
	table.insert(prog, function (state)
		local n = state.reg[reg]
		table.insert(state.stack, n)
		state.ip = state.ip + 1
	end)
end
