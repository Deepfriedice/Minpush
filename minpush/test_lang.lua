require "compile"
require "run"


function run_test (name, src, input, expected)
	DEBUG_EMIT_PRINT = false
	BLOCK_LEN = 5
	local input_file = io.tmpfile()
	input_file:write(input)
	input_file:seek("set", 0)
	local output_file = io.tmpfile()
	print("Running test: "..name)

	local success, result = pcall(compile, src)
	local program
	if not success then
		print("Compilation failed!")
		print(result)
		return False
	else
		program = result
	end

	local success, result = pcall(run, program, input_file, output_file)
	if not success then
		print("Execution failed!")
		print(result)
		return False
	end

	output_file:seek("set", 0)
	local output = output_file:read("a")
	if output ~= expected then
		print("Incorrect output!")
		print("\""..output.."\"")
		return False
	else
		print("Success!")
		return True
	end
end


local tests = {}


function tests.comments ()
	src = [[
		This is a comment.
		{start:
			(A comment inside a definition.)
			`a`b`c...
		:stop}
		This is another comment.
	]]
	input = ""
	output = "cba"
	run_test("comments", src, input, output)
end


function tests.cond ()
	src = [[
		{start:
			d0D X
			$
			x d10D = ?stop;
			x `0 + .
			x d1D + X
		}
	]]
	input = ""
	output = "0123456789"
	run_test("conditions", src, input, output)
end


function tests.stack()
	src = [[
		{start:
			`A `B `C t . `-.
			`D c .. `-.
			`E `F `G r ... `-.
			`H `I `J R ... `-.
			.
		:stop}
	]]
	input = ""
	output = "B-DD-EGF-IHJ-A"
	run_test("stack manipulation", src, input, output)
end


function tests.math ()
	src = [[
		{start:
			d3D d5D + `0+.     (3+5=8)
			d7D d2D - `0+.     (7-2=5)
			d2D d3D * `0+.     (2*3=6)
			d8D d3D / `0+.     (8/3=2)
			d7D d4D % `0+.     (7%4=3)
			d3D ~ d5D + `0+.  (-3+5=2)
		:stop}
	]]
	input = ""
	output = "856232"
	run_test("math operations", src, input, output)
end


function tests.bnot ()
	src = [[ {start: d200D ! . :stop} ]]
	input = ""
	output = "7"
	run_test("binary not", src, input, output)
end


function tests.byte_array ()
	src = [[
		{start:
			[48 65 6c 6c 6f 20 57 6f 72 6c 64 21]
			_
		:stop}
	]]
	input = ""
	output = "Hello World!"
	run_test("byte array", src, input, output)
end


function tests.string ()
	src = [[ {start: 'Hello World!" _ :stop} ]]
	input = ""
	output = "Hello World!"
	run_test("write string", src, input, output)
end


function tests.states ()
	src = [[
		{start: `Q. d1D :foo}
		{foo:
			`W. d1D +
			c d8D > ?baz;
			c d4D > ?bar;
		}
		{bar: `E. d1D + :foo}
		{baz:
			`R. d1D +
			c d10D > ?stop;
		}
	]]
	input = ""
	output = "QWWWWEWEWRR"
	run_test("parity states", src, input, output)
end


function tests.literals ()
	src = [[
		{start :
			`a .
			d98D .
			h63H .
		:stop}
	]]
	src = [[ {start: `a. d98D. h63H. :stop} ]]
	input = ""
	output = "abc"
	run_test("literals", src, input, output)
end


function tests.trim ()
	src = [[
		{start:
			`a `b `c
			. t .
			` .
			'Foo" 'Bar"
			T _
		:stop}
	]]
	input = ""
	output = "ca Foo"
	run_test("trim & array trim", src, input, output)
end


function tests.input ()
	src = [[ {start: i ! ?stop; . } ]]
	input = "Hello World!"
	output = "Hello World!"
	run_test("cat", src, input, output)
end


for name, test in pairs(tests) do
	test()
	print()
end
