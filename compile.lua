require "ksum"
require "operations"

BLOCK_LEN = 10


function compile (text)
	local prog = {}
	local cstate = {
		mode = "instr",
		cond = false,
		buffer = nil,
		root = 0
	}

	local compilers = {
		instr = compile_instr,
		char  = compile_char,
		deci  = compile_deci,
		hexa  = compile_hexa,
		label = compile_label,
		state = compile_state,
	}

	for i = 1, #text do
		c = text:sub(i, i)
		local compiler = compilers[cstate.mode]
		--print(c, cstate.mode)
		compiler(prog, cstate, c)
	end

	return prog
end


function compile_instr (prog, cstate, c)

	-- add posts
	if cstate.cond and #prog % BLOCK_LEN == 0 then
		table.insert(prog, ops.seek_n(2))
		print(#prog, "seek", 2)
	end

	if cstate.cond and #prog % BLOCK_LEN == 1 then
		table.insert(prog, ops.seek_n(BLOCK_LEN))
		print(#prog, "seek", BLOCK_LEN)
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

	elseif c == '{' then
		cstate.mode = "state"

	elseif c == '?' then
		if cstate.cond then error("nested condition") end
		cstate.cond = true
		local next_post = (-#prog % BLOCK_LEN) + #prog + 2
		table.insert(prog, ops.cond(next_post))
		print(#prog, "cond", next_post)

	elseif c == ';' then
		if not cstate.cond then error("free condition end") end
		cstate.cond = false
		local next_post = (1 - #prog) % BLOCK_LEN + #prog

		while #prog < next_post do
			table.insert(prog, ops.noop)
			print(#prog, "noop")
		end

	elseif c == '+' then
		table.insert(prog, ops.add)
		print(#prog, "+")
	elseif c == '.' then
		table.insert(prog, ops.write)
		print(#prog, ".")
	elseif c == 's' then
		table.insert(prog, ops.swap)
	elseif c == 'r' then
		table.insert(prog, ops.restart)
		print(#prog, "r")
	elseif c == 'x' then
		table.insert(prog, ops.exit)
		print(#prog, "x")
	else
		print("Invalid instruction:", c)
	end
	return new_mode
end


function compile_char (prog, cstate, c)
	local n = string.byte(c)
	table.insert(prog, ops.push_n(n))
	print(#prog, "push", n)
	cstate.mode = 'instr'
end


function compile_deci (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing
	elseif '0' <= c and c <= '9' then
		cstate.buffer = 10 * cstate.buffer + c:byte() - 48
	elseif  c == 'D' then
		table.insert(prog, ops.push_n(cstate.buffer))
		print(#prog, "push", cstate.buffer)
		cstate.mode = 'instr'
	else
		print("Invalid decimal:", c)
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
		table.insert(prog, ops.push_n(cstate.buffer))
		print(#prog, "push", cstate.buffer)
		cstate.mode = 'instr'
	else
		print("Invalid hexadecimal:", c)
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
		table.insert(prog, ops.push_n(cstate.buffer))
		print(#prog, "push", cstate.buffer)
		cstate.mode = 'instr'
	else
		print("Invalid label:", c)
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
		table.insert(prog, ops.enter(cstate.buffer))
		print(#prog, "enter", cstate.buffer)
		cstate.root = #prog
		cstate.mode = 'instr'
	else
		print("Invalid label:", c)
	end
end
