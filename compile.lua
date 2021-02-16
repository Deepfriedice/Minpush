require "ksum"
require "operations"

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


-- emit the "post" jumps which should
-- be at the start of each block
function start_block (prog, cstate)

	if cstate.root == 0 then
		table.insert(prog, ops.noop)
		print(#prog, "noop")

	elseif not cstate.cond then
		table.insert(prog, ops.seek_n(2))
		print(#prog, "seek", 2)
		table.insert(prog, ops.seek_n(BLOCK_LEN))
		print(#prog, "seek", BLOCK_LEN)

	else
		table.insert(prog, ops.seek_n(3))
		print(#prog, "seek", 3)
		table.insert(prog, ops.seek_n(BLOCK_LEN))
		print(#prog, "seek", BLOCK_LEN)
		table.insert(prog, ops.seek_n(BLOCK_LEN))
		print(#prog, "seek", BLOCK_LEN)

	end
end


function compile_body (prog, cstate, c)
	if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
		-- nothing

	elseif c == '{' then
		cstate.buffer = 0
		cstate.mode = "state"
		table.insert(prog, ops.noop)  -- ensure enter will be aligned
		print(#prog, "noop")

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

	elseif c == '}' then
		if cstate.cond then error("unfinished condition") end
		table.insert(prog, ops.jump_n(cstate.root))
		print(#prog, "jump", cstate.root)
		cstate.root = 0
		cstate.mode = "body"
		while #prog % BLOCK_LEN ~= 0 do
			table.insert(prog, ops.noop)
			print(#prog, "noop")
		end

	elseif c == '?' then
		if cstate.cond then error("nested condition") end
		cstate.cond = true
		local block_start = #prog - (#prog % BLOCK_LEN) + 1
		local skip_dest = block_start + BLOCK_LEN + 2
		table.insert(prog, ops.cond(skip_dest))
		print(#prog, "cond", skip_dest)

	elseif c == ';' then
		if not cstate.cond then error("free condition end") end
		cstate.cond = false
		while #prog % BLOCK_LEN ~= 0 do
			table.insert(prog, ops.noop)
			print(#prog, "noop")
		end

	elseif c == '+' then
		table.insert(prog, ops.add)
		print(#prog, "+")

	elseif c == '=' then
		table.insert(prog, ops.eq)
		print(#prog, "=")

	elseif c == '>' then
		table.insert(prog, ops.gt)
		print(#prog, ">")

	elseif c == '<' then
		table.insert(prog, ops.lt)
		print(#prog, "<")

	elseif c == '!' then
		table.insert(prog, ops.lnot)
		print(#prog, "not")

	elseif c == '.' then
		table.insert(prog, ops.write)
		print(#prog, "write")

	elseif c == 'c' then
		table.insert(prog, ops.copy)
		print(#prog, "copy")

	elseif c == 's' then
		table.insert(prog, ops.swap)
		print(#prog, "swap")

	elseif c == 'r' then
		table.insert(prog, ops.restart)
		print(#prog, "restart")

	elseif c == '$' then
		cstate.root = #prog + 1

	elseif 'W' <= c and c <= 'Z' then
		local r = string.lower(c)
		table.insert(prog, ops.set_r(r))
		print(#prog, "set " .. r)

	elseif 'w' <= c and c <= 'x' then
		table.insert(prog, ops.get_r(c))
		print(#prog, "get " .. c)

	elseif c == '@' then
		table.insert(prog, ops.switch)
		print(#prog, "switch")

	elseif c == 'x' then
		table.insert(prog, ops.exit)
		print(#prog, "exit")

	else
		error("Invalid instruction: " .. c)
	end
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
		table.insert(prog, ops.push_n(cstate.buffer))
		print(#prog, "push", cstate.buffer)
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
		table.insert(prog, ops.push_n(cstate.buffer))
		print(#prog, "push", cstate.buffer)
		cstate.mode = 'instr'
	else
		error("Invalid label: " .. c)
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
		table.insert(prog, ops.enter(cstate.buffer, skip_dest))
		print(#prog, "enter", cstate.buffer, skip_dest)
		cstate.root = #prog
		cstate.mode = 'instr'
	else
		error("Invalid label: " .. c)
	end
end
