require "ksum"


function new_state (input, output)
	if input == nil then
		input = io.input()
	end
	if output == nil then
		output = io.output()
	end
	return {
		input = input,
		output = output,
		ip = 1,
		running = true,
		stack = {},
		array = {},
		label = ksum_text("start"),
		reg = { w = 0, x = 0, y = 0, z = 0 },
	}
end


function step(prog, state)
	local ip = state.ip
	assert(ip <= #prog, "out of bounds: " .. ip)
	local operation = prog[ip]
	operation(state)
end


function run(prog, input, output)
	local state = new_state(input, output)
	while state.running do
		step(prog, state)
	end
end
