require "ksum"


function step(prog, state)
	local ip = state.ip
	assert(ip <= #prog, "out of bounds: " .. ip)
	local operation = prog[ip]
	operation(state)
end


function run(prog)
	local state = {
		ip = 1,
		running = true,
		dstack = {},
		astack = {},
		alstack = {},
		label = ksum_text("start"),
		reg = { w = 0, x = 0, y = 0, z = 0 },
	}
	while state.running do
		step(prog, state)
	end
end
