require "ksum"
require "emit"

BLOCK_LEN = 10

compile_modes = {}


function compile (text)
	local prog = {}
	local cstate = {
		mode = "base",
		buffer = nil,
		root = 0
	}

	for i = 1, #text do
		c = text:sub(i, i)
		local compiler = compile_modes[cstate.mode]
		--print(c, cstate.mode)
		compiler(prog, cstate, c)
	end

	compile_modes.finish(prog, cstate)

	return prog
end


function compile_modes.base (prog, cstate, c)
	if c == '{' then
		cstate.buffer = 0
		cstate.mode = "state_name"
	elseif c == '}' then
		error("Not inside a state.")
	end
end


function compile_modes.state_name (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif c == '_' or
			'0' <= c and c <= '9' or
			'A' <= c and c <= 'Z' or
			'a' <= c and c <= 'z' then
		cstate.buffer = ksum(cstate.buffer, c:byte())
	elseif c == ':' then
		local block_start = #prog - (#prog % BLOCK_LEN) + 1
		local skip_dest = block_start + BLOCK_LEN + 1
		emit.noop(prog)  -- ensure enter will be aligned
		emit.enter(prog, cstate.buffer, skip_dest)
		cstate.root = #prog
		cstate.mode = 'state_body'
	else
		error("Invalid label: " .. c)
	end
end


function compile_modes.state_body (prog, cstate, c)

	-- add the hop & skip to the start of
	-- each block inside this state
	if #prog % BLOCK_LEN == 0 then
		emit.seek(prog, 2)
		emit.seek(prog, BLOCK_LEN)
	end

	-- compile
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing

	elseif c == ':' then
		cstate.buffer = 0
		cstate.mode = "switch"

	elseif c == '$' then
		cstate.root = #prog + 1

	elseif c == '?' then
		cstate.buffer = 0
		cstate.mode = "condition"

	elseif c == '}' then
		emit.jump(prog, cstate.root)
		cstate.root = 0
		cstate.mode = "base"
		while #prog % BLOCK_LEN ~= 0 do
			emit.noop(prog)
		end

	elseif c == '(' then
		cstate.mode = "comment"

	elseif c == '`' then
		cstate.mode = "character"

	elseif c == 'd' then
		cstate.buffer = 0
		cstate.mode = "decimal"

	elseif c == 'h' then
		cstate.buffer = 0
		cstate.mode = "hexadecimal"

	elseif c == 't' then
		emit.trim(prog)

	elseif c == 'c' then
		emit.copy(prog)

	elseif c == 's' then
		emit.swap(prog)

	elseif c == 'r' then
		emit.rotate(prog)

	elseif c == 'R' then
		emit.rev_rotate(prog)

	elseif c == '~' then
		emit.negate(prog)

	elseif c == '+' then
		emit.add(prog)

	elseif c == '-' then
		emit.subtract(prog)

	elseif c == '*' then
		emit.multiply(prog)

	elseif c == '/' then
		emit.divide(prog)

	elseif c == '%' then
		emit.modulo(prog)

	elseif c == '=' then
		emit.equal(prog)

	elseif c == '<' then
		emit.less_than(prog)

	elseif c == '>' then
		emit.greater_than(prog)

	elseif c == '!' then
		emit.bit_not(prog)

	elseif c == '&' then
		emit.bit_and(prog)

	elseif c == '|' then
		emit.bit_or(prog)

	elseif 'w' <= c and c <= 'z' then
		emit.get_reg(prog, c)

	elseif 'W' <= c and c <= 'Z' then
		local r = string.lower(c)
		emit.set_reg(prog, r)

	elseif c == "'" then
		cstate.buffer = {}
		cstate.mode = "string"

	elseif c == '[' then
		cstate.buffer = {}
		cstate.mode = "bytes"

	elseif c == 'L' then
		emit.get_array_length(prog)

	elseif c == 'S' then
		emit.set_array_length(prog)

	elseif c == 'C' then
		emit.array_copy(prog)

	elseif c == 'I' then
		emit.array_insert(prog)

	elseif c == 'K' then
		emit.array_delete(prog)

	elseif c == 'i' then
		emit.read(prog)

	elseif c == '.' then
		emit.write(prog)

	elseif c == '_' then
		emit.array_write(prog)

	else
		error("Invalid action: " .. c)
	end
end


function compile_modes.switch (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif c == '_' or
			'0' <= c and c <= '9' or
			'A' <= c and c <= 'Z' or
			'a' <= c and c <= 'z' then
		cstate.buffer = ksum(cstate.buffer, c:byte())
	elseif c == '}' then
		emit.switch(prog, cstate.buffer)
		cstate.root = 0
		cstate.mode = "base"
		while #prog % BLOCK_LEN ~= 0 do
			emit.noop(prog)
		end
	else
		error("Invalid label: " .. c)
	end
end


function compile_modes.condition (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif c == '_' or
			'0' <= c and c <= '9' or
			'A' <= c and c <= 'Z' or
			'a' <= c and c <= 'z' then
		cstate.buffer = ksum(cstate.buffer, c:byte())
	elseif c == ';' then
		emit.cond_switch(prog, cstate.buffer)
		cstate.mode = 'state_body'
	else
		error("Invalid label: " .. c)
	end
end


function compile_modes.finish (prog, cstate)
	while #prog % BLOCK_LEN ~= 1 do
		emit.noop(prog)
	end
	emit.exit(prog)
end


function compile_modes.comment (prog, cstate, c)
	if c == ')' then
		cstate.mode = "state_body"
	end
end


function compile_modes.character (prog, cstate, c)
	local n = string.byte(c)
	emit.push(prog, n)
	cstate.mode = 'state_body'
end


function compile_modes.decimal (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif '0' <= c and c <= '9' then
		cstate.buffer = 10 * cstate.buffer + c:byte() - 48
	elseif  c == 'D' then
		emit.push(prog, cstate.buffer)
		cstate.mode = 'state_body'
	else
		error("Invalid decimal: " .. c)
	end
end


function compile_modes.hexadecimal (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif '0' <= c and c <= '9' then
		cstate.buffer = 16 * cstate.buffer + c:byte() - string.byte('0')
	elseif 'A' <= c and c <= 'F' then
		cstate.buffer = 16 * cstate.buffer + c:byte() - string.byte('A') + 10
	elseif 'a' <= c and c <= 'f' then
		cstate.buffer = 16 * cstate.buffer + c:byte() - string.byte('a') + 10
	elseif  c == 'H' then
		emit.push(prog, cstate.buffer)
		cstate.mode = 'state_body'
	else
		error("Invalid hexadecimal: " .. c)
	end
end


function compile_modes.string (prog, cstate, c)
	if  c == '"' then
		emit.push_bytes(prog, cstate.buffer)
		cstate.mode = 'state_body'
	else
		table.insert(cstate.buffer, c:byte())
	end
end


function compile_modes.bytes (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif '0' <= c and c <= '9' then
		local n = c:byte() - string.byte('0')
		table.insert(cstate.buffer, 16 * n)
		cstate.mode = 'byte_complete'
	elseif 'A' <= c and c <= 'F' then
		local n = c:byte() - string.byte('A') + 10
		table.insert(cstate.buffer, 16 * n)
		cstate.mode = 'byte_complete'
	elseif 'a' <= c and c <= 'f' then
		local n = c:byte() - string.byte('a') + 10
		table.insert(cstate.buffer, 16 * n)
		cstate.mode = 'byte_complete'
	elseif  c == ']' then
		emit.push_bytes(prog, cstate.buffer)
		cstate.mode = 'state_body'
	else
		error("Character " .. c .. " not valid in bytes")
	end
end


function compile_modes.byte_complete (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif '0' <= c and c <= '9' then
		local n = c:byte() - string.byte('0')
		cstate.buffer[#cstate.buffer] = cstate.buffer[#cstate.buffer] + n
		cstate.mode = 'bytes'
	elseif 'A' <= c and c <= 'F' then
		local n = c:byte() - string.byte('A') + 10
		cstate.buffer[#cstate.buffer] = cstate.buffer[#cstate.buffer] + n
		cstate.mode = 'bytes'
	elseif 'a' <= c and c <= 'f' then
		local n = c:byte() - string.byte('a') + 10
		cstate.buffer[#cstate.buffer] = cstate.buffer[#cstate.buffer] + n
		cstate.mode = 'bytes'
	elseif  c == ']' then
		error("literal bytes must have even length!")
	else
		error("Character " .. c .. " not valid in bytes")
	end
end
