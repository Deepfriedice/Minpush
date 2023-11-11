local compile = require "compile"
local run = require "run"

local filename = assert(arg[1], "No program!")
local src_file = assert(io.open(filename), "Cannot open: "..filename)
local text = src_file:read("a")
src_file:close()

print("compiling...")

local prog = compile.compile(text)

print("running...")

run.execute(prog)

print("done")
