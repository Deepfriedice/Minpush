require "compare"
require "emit"
require "run"


function tmp_state ()
	-- Don't need IO for these tests
	return new_state(io.tmpfile(), io.tmpfile())
end


function compare_state (actual, expected)
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


function run_test (name, emit_func, prog, args, state, expected_state)
	DEBUG_EMIT_PRINT = false
	print("Running test: "..name)

	if not pcall(emit_func, prog, table.unpack(args)) then
		print("\tEmit failed!")
		return False
	end

	state.ip = #prog
	if not pcall(step, prog, state) then
		print("\tExecution failed!")
		return False
	end

	if not compare_state(state, expected_state) then
		print("\tIncorrect new state!")
		return False
	end

	print("\tSuccess!")
	return True
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


for name, test in pairs(tests) do
	test()
end
