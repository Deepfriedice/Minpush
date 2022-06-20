require "ksum"
require "emit"

BLOCK_LEN = 10


function compile (text)
	local prog = {}
	local cstate = {
		mode = "body",
		cond = false,
		buffer = nil,
		root = 0
	}

	local compilers = {
		body  = compile_body,
		instr = compile_instr,
		char  = compile_char,
		deci  = compile_deci,
		hexa  = compile_hexa,
		label = compile_label,
		str   = compile_str,
		bytes = compile_bytes,
		b_mid = compile_b_mid,
		state = compile_state,
	}

	for i = 1, #text do
		c = text:sub(i, i)
		local compiler = compilers[cstate.mode]
		--print(c, cstate.mode)
		compiler(prog, cstate, c)
	end

	compile_stop(prog, cstate)

	return prog
end


-- emit the "post" jumps which should
-- be at the start of each block
function start_block (prog, cstate)

	if cstate.root == 0 then
		emit.noop(prog)

	elseif not cstate.cond then
		emit.seek(prog, 2)
		emit.seek(prog, BLOCK_LEN)

	else
		emit.seek(prog, 3)
		emit.seek(prog, BLOCK_LEN)
		emit.seek(prog, BLOCK_LEN)

	end
end


function compile_body (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing

	elseif c == '{' then
		cstate.buffer = 0
		cstate.mode = "state"
		emit.noop(prog)  -- ensure enter will be aligned

	else
		error("Invalid body command: " .. c)
	end
end


function compile_instr (prog, cstate, c)
	if #prog % BLOCK_LEN == 0 then
		start_block(prog, cstate)
	end

	-- compile
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing

	elseif c == '`' then
		cstate.mode = "char"

	elseif c == 'd' then
		cstate.buffer = 0
		cstate.mode = "deci"

	elseif c == 'h' then
		cstate.buffer = 0
		cstate.mode = "hexa"

	elseif c == '(' then
		cstate.buffer = 0
		cstate.mode = "label"

	elseif c == "'" then
		cstate.buffer = {}
		cstate.mode = "str"

	elseif c == '[' then
		cstate.buffer = {}
		cstate.mode = "bytes"

	elseif c == '}' then
		if cstate.cond then error("unfinished condition") end
		emit.jump(prog, cstate.root)
		cstate.root = 0
		cstate.mode = "body"
		while #prog % BLOCK_LEN ~= 0 do
			emit.noop(prog)
		end

	elseif c == '?' then
		if cstate.cond then error("nested condition") end
		cstate.cond = true
		local block_start = #prog - (#prog % BLOCK_LEN) + 1
		local skip_dest = block_start + BLOCK_LEN + 2
		emit.cond(prog, skip_dest)

	elseif c == ';' then
		if not cstate.cond then error("free condition end") end
		emit.jump(prog, cstate.root)
		cstate.cond = false
		while #prog % BLOCK_LEN ~= 0 do
			emit.noop(prog)
		end

	elseif c == '+' then
		emit.add(prog)

	elseif c == '=' then
		emit.eq(prog)

	elseif c == '>' then
		emit.gt(prog)

	elseif c == '<' then
		emit.lt(prog)

	elseif c == '!' then
		emit.bnot(prog)

	elseif c == '.' then
		emit.write(prog)

	elseif c == '_' then
		emit.array_write(prog)

	elseif c == 'i' then
		emit.read(prog)

	elseif c == 't' then
		emit.trim(prog)

	elseif c == 'T' then
		emit.trim_array(prog)

	elseif c == 'c' then
		emit.copy(prog)

	elseif c == 'C' then
		emit.array_copy(prog)

	elseif c == 's' then
		emit.swap(prog)

	elseif c == 'S' then
		emit.array_swap(prog)

	elseif c == '$' then
		cstate.root = #prog + 1

	elseif 'W' <= c and c <= 'Z' then
		local r = string.lower(c)
		emit.set_reg(prog, r)

	elseif 'w' <= c and c <= 'x' then
		emit.get_reg(prog, c)

	elseif c == '@' then
		emit.switch(prog)

	else
		error("Invalid instruction: " .. c)
	end
end


function compile_char (prog, cstate, c)
	local n = string.byte(c)
	emit.push(prog, n)
	cstate.mode = 'instr'
end


function compile_deci (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif '0' <= c and c <= '9' then
		cstate.buffer = 10 * cstate.buffer + c:byte() - 48
	elseif  c == 'D' then
		emit.push(prog, cstate.buffer)
		cstate.mode = 'instr'
	else
		error("Invalid decimal: " .. c)
	end
end


function compile_hexa (prog, cstate, c)
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
		cstate.mode = 'instr'
	else
		error("Invalid hexadecimal: " .. c)
	end
end


function compile_label (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif c == '_' or
			'0' <= c and c <= '9'  or
			'A' <= c and c <= 'Z' or
			'a' <= c and c <= 'z' then
		cstate.buffer = ksum(cstate.buffer, c:byte())
	elseif c == ')' then
		emit.push(prog, cstate.buffer)
		cstate.mode = 'instr'
	else
		error("Invalid label: " .. c)
	end
end


function compile_str (prog, cstate, c)
	if  c == '"' then
		emit.push_array(prog, cstate.buffer)
		cstate.mode = 'instr'
	else
		table.insert(cstate.buffer, c:byte())
	end
end


function compile_bytes (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif '0' <= c and c <= '9' then
		local n = c:byte() - string.byte('0')
		table.insert(cstate.buffer, 16 * n)
		cstate.mode = 'b_mid'
	elseif 'A' <= c and c <= 'F' then
		local n = c:byte() - string.byte('A') + 10
		table.insert(cstate.buffer, 16 * n)
		cstate.mode = 'b_mid'
	elseif 'a' <= c and c <= 'f' then
		local n = c:byte() - string.byte('a') + 10
		table.insert(cstate.buffer, 16 * n)
		cstate.mode = 'b_mid'
	elseif  c == ']' then
		emit.push_array(prog, cstate.buffer)
		cstate.mode = 'instr'
	else
		error("Character " .. c .. " not valid in bytes")
	end
end


function compile_b_mid (prog, cstate, c)
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


function compile_state (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif c == '_' or
			'0' <= c and c <= '9'  or
			'A' <= c and c <= 'Z' or
			'a' <= c and c <= 'z' then
		cstate.buffer = ksum(cstate.buffer, c:byte())
	elseif c == ':' then
		local block_start = #prog - (#prog % BLOCK_LEN) + 1
		local skip_dest = block_start + BLOCK_LEN + 1
		emit.enter(prog, cstate.buffer, skip_dest)
		cstate.root = #prog
		cstate.mode = 'instr'
	else
		error("Invalid label: " .. c)
	end
end


function compile_stop (prog, cstate)
	while #prog % BLOCK_LEN ~= 1 do
		emit.noop(prog)
	end
	emit.exit(prog)
end
