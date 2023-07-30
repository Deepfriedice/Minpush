WORD_MASK = 0xffffffff
BYTE_MASK = 0xff


DEBUG_EMIT_PRINT = false


function debug_print(...)
	if DEBUG_EMIT_PRINT then
		print(...)
	end
end


--[[
	Given a function with name and arity, return an emitter which
	produces a instruction which operates on the top arity values of the stack.
	This is intended to simplify the simpler ~50% of instruction definitions.
	Compare the implementations below of "emit.multiple" with "emit.divide",
	which includes a divide-by-zero check.
]]--
function simple_emitter (name, arity, func)
	return function (prog)
		debug_print(#prog + 1, name)
		table.insert(prog, function (state)
			local stack_len = #state.stack
			local first_arg = stack_len - arity + 1
			assert(stack_len >= arity, name .. " with less than " .. arity .. " stack items")

			-- take top arity values from the stack
			local args = table.move(state.stack, first_arg, stack_len, 1, {})

			-- clear used stack positions
			table.move({}, 1, arity, first_arg, state.stack)

			local result = table.pack(func(table.unpack(args)))

			-- place results back onto the stack
			table.move(result, 1, #result, #state.stack + 1, state.stack)
			state.ip = state.ip + 1
		end)
	end
end


emit = {}


function emit.noop (prog)
	debug_print(#prog + 1, "noop")
	table.insert(prog, function (state)
		state.ip = state.ip + 1
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


function emit.exit (prog)
	debug_print(#prog + 1, "exit")
	table.insert(prog, function (state)
		state.running = false
	end)
end


function emit.push (prog, n)
	debug_print(#prog + 1, "push " .. n)
	table.insert(prog, function (state)
		table.insert(state.stack, n)
		state.ip = state.ip + 1
	end)
end


emit.trim = simple_emitter("trim", 1, function (x)
end)


emit.copy = simple_emitter("copy", 1, function (x)
	return x, x
end)


emit.swap = simple_emitter("swap", 2, function (x, y)
	return y, x
end)


emit.rotate = simple_emitter("rotate", 3, function (x, y, z)
	return y, z, x
end)


emit.rev_rotate = simple_emitter("rev rotate", 3, function (x, y, z)
	return z, x, y
end)


emit.negate = simple_emitter("negate", 1, function (x)
	return -x
end)


emit.add = simple_emitter("add", 2, function (x, y)
	return x + y
end)


emit.subtract = simple_emitter("subtract", 2, function (x, y)
	return x - y
end)


emit.multiply = simple_emitter("multiply", 2, function (x, y)
	return x * y
end)


emit.divide = simple_emitter("divide", 2, function (x, y)
	assert(y ~= 0, "divide by zero")
	return x // y
end)


emit.modulo = simple_emitter("modulo", 2, function (x, y)
	assert(y ~= 0, "modulo by zero")
	return x % y
end)


emit.equal = simple_emitter("equal", 2, function (x, y)
	if x == y then
		return -1
	else
		return 0
	end
end)


emit.less_than = simple_emitter("less than", 2, function (x, y)
	if x < y then
		return -1
	else
		return 0
	end
end)


emit.greater_than = simple_emitter("greater than", 2, function (x, y)
	if x > y then
		return -1
	else
		return 0
	end
end)


emit.bit_not = simple_emitter("bit not", 1, function (x)
	return ~x
end)


emit.bit_and = simple_emitter("bit and", 2, function (x, y)
	return x & y
end)


emit.bit_or = simple_emitter("bit or", 2, function (x, y)
	return x | y
end)


function emit.get_reg (prog, reg)
	debug_print(#prog + 1, "get " .. reg)
	table.insert(prog, function (state)
		local n = state.reg[reg]
		table.insert(state.stack, n)
		state.ip = state.ip + 1
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


function emit.push_bytes (prog, bytes)
	debug_print(#prog + 1, "push bytes (" .. #bytes .. ")")
	table.insert(prog, function (state)
		--append bytes onto the array
		table.move(bytes, 1, #bytes, #state.array+1, state.array)
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
		assert(new_length >= 0, "cannot set array to negative length")
		for i = old_length + 1, new_length do
			state.array[i] = 0
		end
		for i = new_length + 1, old_length do
			state.array[i] = nil
		end
		state.ip = state.ip + 1
	end)
end


function emit.array_copy (prog)
	debug_print(#prog + 1, "array copy")
	table.insert(prog, function (state)
		local count = table.remove(state.stack)
		local index = table.remove(state.stack) + 1
		assert(index >= 1, "array copy from before start of array")
		assert(index + count < #state.array+1, "cannot copy from past the end of array")
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
		assert(src_index > 0, "array insert from before start of array")
		assert(src_index <= #state.array, "array insert from after end of array")
		assert(dst_index > 0, "array insert to before start of array")
		assert(dst_index <= #state.array, "array insert to after end of array")

		-- copy the data to insert
		local temp = table.move(state.array, src_index, #state.array, 1, {})

		-- move the data down by count bytes to make space
		table.move(state.array, dst_index, src_index-1, dst_index+count)

		-- insert
		table.move(temp, 1, count, dst_index, state.array)

		state.ip = state.ip + 1
	end)
end


function emit.array_delete (prog)
	debug_print(#prog + 1, "array delete")
	table.insert(prog, function (state)
		local count = table.remove(state.stack)
		local index = table.remove(state.stack) + 1
		assert(index >= 1, "array delete from before start of array")
		assert(index + count - 1 <= #state.array, "array delete after end of array")
		table.move(state.array, index + count, #state.array, index)
		for i = #state.array + 1 - count, #state.array do
			state.array[i] = nil
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
		local end_index = start_index + count - 1
		assert(start_index >= 1, "array write from before start of array")
		assert(end_index <= #state.array, "array write exceeds length of array")
		for i = start_index, end_index do
			local v = state.array[i]
			local c = string.char(v)
			state.output:write(c)
		end
		state.ip = state.ip + 1
	end)
end
