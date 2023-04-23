{ start :
	`Q. d1D
	: foo
}
{ foo :
	`W. d1D +
	c d8D > ?baz;
	c d4D > ?bar;
}
{ bar :
	`E. d1D +
	: foo
}
{ baz :
	`R. d1D +
	c d10D > ?stop;
}
