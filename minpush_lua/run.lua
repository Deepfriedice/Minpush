local ksum = require "ksum"


local run = {}
local start_label = ksum.ksum_text("start")


function run.new_state (input, output)
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
		label = start_label,
		reg = { w = 0, x = 0, y = 0, z = 0 },
	}
end


function run.step(prog, state)
	local ip = state.ip
	assert(ip <= #prog, "out of bounds: " .. ip)
	local operation = prog[ip]
	operation(state)
end


function run.execute(prog, input, output)
	local state = run.new_state(input, output)
	while state.running do
		run.step(prog, state)
	end
end


return run
