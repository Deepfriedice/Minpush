require "compile"
require "ksum"


function step(prog, state)
	prog[state.ip](state)
end


state = {
	ip = 1,
	running = false,
	dstack = {},
	astack = {},
	alstack = {},
	label = ksum_text("start"),
	reg = {
		w = 0, x = 0, y = 0, z = 0,
	},
}


text = [[
	
	{ start :
		d0D
		(loop) @
	}
	
	{ loop :
		c d10D = ?
			x
		;
		c `0 + .
		haH .
		d1D +
	}
	
]]


prog = compile(text)

--for k,v in ipairs(prog) do print(k, v) end

print("running...")
state.running = true
while state.running do
	--print(state.ip)
	if state.ip > #prog then error("out of bounds: " .. state.ip) end
	step(prog, state)
	-- for k,v in ipairs(state.dstack) do print(v) end
end
