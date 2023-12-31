local compare = require "compare"
local emit = require "emit"
local run = require "run"


local function tmp_state ()
	-- Don't need IO for these tests
	return run.new_state(io.tmpfile(), io.tmpfile())
end


local function compare_state (actual, expected)
	-- Compare a state table, ignoring the input and output handles
	for key in pairs(expected) do
		if actual[key] == nil then
			return false
		end
	end
	for key, value in pairs(actual) do
		if key == "input" or key == "output" then
			-- skip
		elseif not compare(value, expected[key]) then
			return false
		end
	end
	return true
end


local function run_test (name, emit_func, prog, args, state, expected_state)
	DEBUG_EMIT_PRINT = false
	print("Running test: "..name)

	local success, result = pcall(emit_func, prog, table.unpack(args))
	if not success then
		print("Emit failed!")
		print(result)
		return false
	end

	state.ip = #prog
	success, result = pcall(run.step, prog, state)
	if not success then
		print("Execution failed!")
		print(result)
		return false
	end

	if not compare_state(state, expected_state) then
		print("Incorrect new state!")
		print("IP:", state.ip)
		print("stack: ", table.unpack(state.stack))
		return false
	end

	print("Success!")
	return true
end


local tests = {}


function tests.noop ()
	local expected = tmp_state()
	expected.ip = 2
	return run_test("noop", emit.noop, {}, {}, tmp_state(), expected)
end


function tests.push ()
	local args = { 48 }
	local expected = tmp_state()
	expected.ip = 2
	expected.stack = { 48 }
	return run_test("push", emit.push, {}, args, tmp_state(), expected)
end


function tests.push_bytes ()
	local args = { { 17, 18, 19, 20 } }
	local expected = tmp_state()
	expected.ip = 2
	expected.array = { 17, 18, 19, 20 }
	return run_test("push_bytes", emit.push_bytes, {}, args, tmp_state(), expected)
end


function tests.array_peek_be ()
	local array = { 45, 22, 0, 100 }
	local be_value = (array[1]<<24) + (array[2]<<16) + (array[3]<<8) + (array[4]<<0)
	local args = { "be word" }
	local initial_state = tmp_state()
	initial_state.ip = 1
	initial_state.stack = { 0 }
	initial_state.array = array
	local expected_state = tmp_state()
	expected_state.ip = 2
	expected_state.stack = { be_value }
	expected_state.array = array
	return run_test("array_peek_be", emit.array_peek, {}, args, initial_state, expected_state)
end


for name, test in pairs(tests) do
	test()
	print()
end
