require "compile"
require "run"


function testfile_extract (testfile)
	testfile:seek("set", 0)
	return testfile:read('a')
end

function run_test (name, src, input, expected)
	DEBUG_EMIT_PRINT = false
	input_file = io.tmpfile()
	input_file:write(input)
	input_file:seek("set", 0)
	output_file = io.tmpfile()
	print("Running test: "..name)
	
	local success, prog = pcall(compile, src)
	if not success then
		print("\tCompilation failed!")
		return False
	end
	
	success = pcall(run, prog, input_file, output_file)
	if not success then
		print("\tExecution failed!")
		return False
	end
	
	output_file:seek("set", 0)
	output = output_file:read("a")
	if output ~= expected then
		print("\tIncorrect output!")
		return False
	else
		print("\tSuccess!")
		return True
	end
end

function run_all_tests ()
	for name, test in pairs(_ENV) do
		if name:len() > 5 and name:sub(1,5) == "test_" then
			test()
		end
	end
end


function test_cond ()
	src = [[
		{ start :
			d0D X
			$
			x d10D = ?
				(stop) @
			;
			x `0 + .
			x d1D + X
		}
	]]
	input = ""
	output = "0123456789"
	run_test("conditions", src, input, output)
end

function test_bnot ()
	src = [[
		{ start :
			d200D ! .
			(stop) @
		}
	]]
	input = ""
	output = "7"
	run_test("binary not", src, input, output)
end

function test_byte_array ()
	src = [[
		{ start :
			[48 65 6c 6c 6f 20 57 6f 72 6c 64 21]
			_
			(stop) @
		}
	]]
	input = ""
	output = "Hello World!"
	run_test("byte array", src, input, output)
end

function test_string ()
	src = [[
		{ start :
			'Hello World!"
			_
			(stop) @
		}
	]]
	input = ""
	output = "Hello World!"
	run_test("write string", src, input, output)
end

function test_states ()
	src = [[
		{ start :
			`Q. d1D
			(foo) @
		}
		{ foo :
			`W. d1D +
			c d8D > ? (baz) @ ;
			c d4D > ? (bar) @ ;
		}
		{ bar :
			`E. d1D +
			(foo) @
		}
		{ baz :
			`R. d1D +
			c d10D > ? (stop) @ ;
		}
	]]
	input = ""
	output = "QWWWWEWEWRR"
	run_test("parity states", src, input, output)
end

function test_literals ()
	src = [[
		{ start :
			`a .
			d98D .
			h63H .
			(stop) @
		}
	]]
	input = ""
	output = "abc"
	run_test("literals", src, input, output)
end

function test_trim ()
	src = [[
		{ start :
			`a `b `c
			. t .
			` .
			'Foo" 'Bar"
			T _
			(stop) @
		}
	]]
	input = ""
	output = "ca Foo"
	run_test("trim & array trim", src, input, output)
end


run_all_tests()
