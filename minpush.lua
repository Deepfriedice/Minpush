require "compile"


function step(prog, state)
	prog[state.ip](state)
end


state = {
	ip = 1,
	running = false,
	dstack = {},
	astack = {},
	alstack = {},
	dest = 0,
	reg = {
		c = 0, w = 0, x = 0, y = 0, z = 0,
	},
}


--text = "2 5 48 ++ . x"
--text = "`Md100D..haH.x"
--text = "(e).haH.x"
text = [[
`a.
d1D
?
	`b.
	`c.
	`!.
	`z.
;
`d.
haH.
x
]]


prog = compile(text)

--for k,v in ipairs(prog) do print(k, v) end

print("running...")
state.running = true
while state.running do
	--print(state.ip)
	if state.ip > #prog then print("out of bounds") break end
	step(prog, state)
	-- for k,v in ipairs(state.dstack) do print(v) end
end
