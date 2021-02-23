require "compile"
require "run"

filename = assert(arg[1], "No program!")
src_file = assert(io.open(filename), "Cannot open: "..filename)
text = src_file:read("a")
src_file:close()

print("compiling...")

prog = compile(text)

print("running...")

run(prog)

print("done")
