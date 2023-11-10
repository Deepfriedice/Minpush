require "compile"
require "run"


local function run_test (name, src, input, expected)
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
		return false
	else
		program = result
	end

	success, result = pcall(run, program, input_file, output_file)
	if not success then
		print("Execution failed!")
		print(result)
		return false
	end

	output_file:seek("set", 0)
	local output = output_file:read("a")
	if output ~= expected then
		print("Incorrect output!")
		print("\""..output.."\"")
		return false
	else
		print("Success!")
		return true
	end
end


local tests = {}


function tests.comments ()
	local src = [[
		This is a comment.
		{start:
			(A comment inside a definition.)
			`a`b`c...
		:stop}
		This is another comment.
	]]
	local input = ""
	local output = "cba"
	run_test("comments", src, input, output)
end


function tests.states ()
	local src = [[
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
	local input = ""
	local output = "QWWWWEWEWRR"
	run_test("parity states", src, input, output)
end


function tests.cond ()
	local src = [[
		{start:
			d0D X
			$
			x d10D = ?stop;
			x `0 + .
			x d1D + X
		}
	]]
	local input = ""
	local output = "0123456789"
	run_test("conditions", src, input, output)
end


function tests.literals ()
	local src = [[ {start: `a. d98D. h63H. :stop} ]]
	local input = ""
	local output = "abc"
	run_test("literals", src, input, output)
end


function tests.stack()
	local src = [[
		{start:
			`A `B `C t . `-.
			`D c .. `-.
			`E `F `G r ... `-.
			`H `I `J R ... `-.
			.
		:stop}
	]]
	local input = ""
	local output = "B-DD-EGF-IHJ-A"
	run_test("stack manipulation", src, input, output)
end


function tests.math ()
	local src = [[
		{start:
			d3D d5D + `0+.     (3+5=8)
			d7D d2D - `0+.     (7-2=5)
			d2D d3D * `0+.     (2*3=6)
			d8D d3D / `0+.     (8/3=2)
			d7D d4D % `0+.     (7%4=3)
			d3D ~ d5D + `0+.  (-3+5=2)
		:stop}
	]]
	local input = ""
	local output = "856232"
	run_test("math operations", src, input, output)
end


function tests.bitwise ()
	local src = [[
		{start:
			d200D ! .
			d92D d123D & .
			d62D d21D | .
		:stop}
	]]
	local input = ""
	local output = "7X?"
	run_test("bitwise operations", src, input, output)
end


function tests.string ()
	local src = [[ {start: 'Hello World!" d0D d12D _ :stop} ]]
	local input = ""
	local output = "Hello World!"
	run_test("write string", src, input, output)
end


function tests.byte_array ()
	local src = [[
		{start:
			[48 65 6c 6c 6f 20 57 6f 72 6c 64 21]
			d0D d12D _
		:stop}
	]]
	local input = ""
	local output = "Hello World!"
	run_test("byte array", src, input, output)
end


function tests.array_length()
	local src = [[
		{start:
			      L`0+.
			'ABC" L`0+.
			'DEF" L`0+.
			'GHI" L`0+.
		:stop}
	]]
	local input = ""
	local output = "0369"
	run_test("array length", src, input, output)
end


function tests.array_manipulation()
	local src = [[
		{start:
			'ABCDEF"  d0DL_ `-.
			d8D     S d0DL_ `-.
			d4D     S d0DL_ `-.
			d0D d2D C d0DL_ `-.
			d0D d2D I d0DL_ `-.
			d1D d4D K d0DL_
		:stop}
	]]
	local input = ""
	local output = "ABCDEF-ABCDEF\0\0-ABCD-ABCDAB-ABABCD-AD"
	run_test("array manipulation", src, input, output)
end


function tests.array_peek()
	local src = [[
		{start:
			'ABCDEF"             (literal string)
			d3D op `D =          (peek at byte 3)
			d1D Ep h42434445H =  (peek at bytes 1,2,3,4)
			d1D ep h45444342H =  (peek at bytes 1,2,3,4 reversed)
			& & ?pass;
		:fail}
		{pass: 'PASS" d6D d4D _ :stop}
		{fail: 'FAIL" d6D d4D _ :stop}
	]]
	local input = ""
	local output = "PASS"
	run_test("array peek", src, input, output)
end


function tests.array_poke()
	local src = [[
		{start:
			'---------"        (literal string)
			`E d4D oP          (poke "E" to byte 4)
			h41424344H d0D EP  (poke ABCD to bytes 0-3)
			h49484746H d5D eP  (poke FGHI to bytes 5-7 reversed)
			d0DL_
		:stop}
	]]
	local input = ""
	local output = "ABCDEFGHI"
	run_test("array poke", src, input, output)
end


function tests.array_append()
	local src = [[
		{start:
			'A"            (literal A)
			`B oA          (append B)
			h43444546H EA  (append CDEF)
			h4a494847H eA  (append JIHG reversed)
			d0DL_
		:stop}
	]]
	local input = ""
	local output = "ABCDEFGHIJ"
	run_test("array append", src, input, output)
end


function tests.input ()
	local src = [[ {start: i ! ?stop; . } ]]
	local input = "Hello World!"
	local output = "Hello World!"
	run_test("cat", src, input, output)
end


for name, test in pairs(tests) do
	test()
	print()
end
