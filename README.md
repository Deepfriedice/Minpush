# Minpush
Minpush is a simple programming language inspired by [pushdown autonoma](https://en.wikipedia.org/wiki/Pushdown_automaton).
It's intended to be very simple to compile, with an eventual goal of being self-hosting despite it's minimalism.


## Design
Minpush consists of four major parts:

### States
Instead of functions, a Minpush program is divided into states.
One state is active at any time, and states can be repeated and conditionally switched.
Execution starts in the "start" state and ends in the "stop" state".

### Stack
Most operations are performed using the stack, with inputs being popped off the stack and results pushed back on. All values on the stack are 32bit signed integers.

### Registers
Four 32bit registers are also available, to help avoid excessive stack manipulation. These are named W X Y Z.

### Array
Operations on strings or larger data can be done using the array.
This supports reading and writing at arbitrary positions, appending, and endianness conversions.


## Syntax
Whitespace is ignored in almost all circumstances.

### States
Each state is defined using a pair of curly braces, with the name of the state first, then the body, then an optional following state.

The body of a state is a sequence of operations which will be executed in order.
If there is a following state, it will become active after the last operation in a state. Otherwise, the state will loop.

For example: ``{foo: `E . :bar}`` is a state named "foo" which prints the letter "E", and then switches to the bar state.
Additionally, ``{baz: `F . }`` is a state named "baz" which prints the letter "F" in a loop forever.

### Comments
All text outside a state definition other than "{" and "}" is considered a comment. Inside a state definition, "(" enters a comment, and ")" leaves it.

### Operations
| group              | symbol          | name                     | stack effect       | description                                                                                                         |
| ------------------ | --------------- | ------------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------- |
| control operations |                 |                          |                    |                                                                                                                     |
|                    | `?foo;`         | conditional state switch | `(v --)`           | Pop the two element off the stack. If it's non-zero, switch the the given state.                                    |
|                    | `$`             | loop restart marker      |                    | In states which loop, this marks the place that subsequent iterations of that loop will begin.                      |
| literals           |                 |                          |                    |                                                                                                                     |
|                    | `d12D`          | decimal literal          | `(-- v)`           | Push a base-10 literal integer onto the stack.                                                                      |
|                    | `h0aH`          | hexadecimal literal      | `(-- v)`           | Push a base-16 literal integer onto the stack. Both upper and lower case letters are allowed.                       |
|                    | `` `M ``        | character literal        | `(-- v)`           | Push the ASCII value of a character onto the stack.                                                                 |
|                    | `'HelloWorld!"` | string literal           |                    | Append the ASCII values of each character onto the array.                                                           |
|                    | `[4e501f]`      | bytes literal            |                    | Append a sequence of hexadecimal-formatted values onto the array.                                                   |
| stack manipulation |                 |                          |                    |                                                                                                                     |
|                    | `t`             | trim (drop)              | `(x --)`           | Remove the top element of the stack.                                                                                |
|                    | `c`             | copy (dup)               | `(x -- x x)`       | Duplicate the top element of the stack.                                                                             |
|                    | `s`             | swap                     | `(x y -- y x)`     | Reverse the order of the two top stack elements.                                                                    |
|                    | `r`             | rotate                   | `(x y z -- y z x)` | Move the third item on the stack to the top.                                                                        |
|                    | `R`             | reverse rotate           | `(x y z -- z x y)` | Move the top item on the stack back two positions.                                                                 |
| arithmetic         |                 |                          |                    |                                                                                                                     |
|                    | `~`             | arithmetic negate        | `(x -- y)`         | Change the sign of an integer.                                                                                      |
|                    | `+`             | addition                 | `(x y -- z)`       | Add two integers.                                                                                                   |
|                    | `-`             | subtraction              | `(x y -- z)`       | Subtract two integers.                                                                                              |
|                    | `*`             | multiplication           | `(x y -- z)`       | Multiply two integers.                                                                                              |
|                    | `/`             | division                 | `(x y -- z)`       | Divide two integers.                                                                                                |
|                    | `%`             | modulo                   | `(x y -- z)`       | Remainder after dividing two integers.                                                                              |
| comparison         |                 |                          |                    |                                                                                                                     |
|                    | `=`             | equality                 | `(x y -- z)`       | Test if x=y, returning -1 if true and 0 otherwise.                                                                  |
|                    | `<`             | less than                | `(x y -- z)`       | Test x < y.                                                                                                         |
|                    | `>`             | greater than             | `(x y -- z)`       | Test x > y.                                                                                                         |
| bitwise / logical  |                 |                          |                    |                                                                                                                     |
|                    | `!`             | bitwise not              | `(x -- y)`         | Return the bitwise inverse of a value.                                                                              |
|                    | `&`             | bitwise and              | `(x y -- z)`       | Perform a bitwise "and" operation.                                                                                  |
|                    | `\|`             | bitwise or               | `(x y -- z)`       | Perform a bitwise "or" operation.                                                                                   |
| registers          |                 |                          |                    |                                                                                                                     |
|                    | `w x y z`       | get from register        | `(-- v)`           | Get the current value of one of the four registers.                                                                 |
|                    | `W X Y Z`       | set to register          | `(v --)`           | Set the value of one of the four registers.                                                                         |
| array manipulation |                 |                          |                    |                                                                                                                     |
|                    | `L`             | get array length         | `(-- v)`           | Get the number of bytes allocated to the array.                                                                     |
|                    | `S`             | resize array             | `(n --)`           | Change the number of bytes in the array, either truncating or appending 0's.                                        |
|                    | `C`             | copy byte range          | `(i n --)`         | Copy n bytes starting at index i in the array, appending the bytes to the end.                                      |
|                    | `I`             | insert byte range        | `(i n --)`         | Move the last n bytes from the end of the array to the index i.                                                     |
|                    | `K`             | delete byte range        | `(i n --)`         | Remove n bytes from index i of the array, moving any subsequent bytes back.                                         |
| transfer           |                 |                          |                    |                                                                                                                     |
|                    | `o-`            | byte prefix              |                    | Prefix to indicate that a byte will be moved. Must precede a transfer type.                                         |
|                    | `E-`            | big endian prefix        |                    | Prefix to move four bytes as a big-endian value. Must precede a transfer type.                                      |
|                    | `e-`            | little endian prefix     |                    | Prefix to move four bytes as a little-endian value. Must precede a transfer type.                                   |
|                    | `-p`            | array peek               | `(i -- v)`         | Read a value from index in the array onto the stack.                                                                |
|                    | `-P`            | array poke               | `(v i --)`         | Write a value from the stack into index i in the array.                                                             |
|                    | `-A`            | array append             | `(v --)`           | Append a value from the stack onto the array.                                                                       |
| IO                 |                 |                          |                    |                                                                                                                     |
|                    | `i`             | read value               | `(-- v t)`         | Read a value from input (likely stdin). Will return the value and 0 (false), or 0 and -1 (true) if input is closed. |
|                    | `.`             | write value              | `(v --)`           | Write a value from the stack to output (likely stdout).                                                             |
|                    | `_`             | write bytes              | `(i n --)`         | Write n bytes from the array, starting at index i, to the output.                                                   |
