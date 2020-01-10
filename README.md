# Actora

Modern processors spend huge numbers of transistors on the
identification of instruction-level parallelism and the provision of
coherent shared memories.  But for applications conforming to the
actor model, parallelism is explicit and without shared state.

Actora is a processor designed to fit the actor model more directly,
using a large number of simple (embedded) cores running code written
in a small Erlang-like language called Elite.  The work is in the
preliminary stages.  So far, we have:

  * [Elite](compiler/Syntax.hs),
     a small Erlang-like language (no concurrency features yet!)
  * [Compiler](compiler/CBackend.hs)
    from Elite to C (runs on x86 and NIOS-II)
  * [Actora bytecode](#6-actora-bytecode),
    a custom stack-machine ISA for Elite
  * [Compiler](compiler/Compiler.hs) from Elite to Actora bytecode
  * [Emulator](emulator/actemu.cpp) for Actora bytecode
  * [Benchmarks](benchmarks/) written in Elite
  * [Comparison](#4-hipe-versus-elite-c-backend)
    of the Elite C Backend and the
    High-Performance Erlang Compiler (HIPE)
  * [Space-optimised Actora Core](rtl/Core.hs)
    implementation on FPGA
    (in [Blarney](https://github.com/mn416/blarney))
  * [Comparison](#5-elite-c-backend-versus-actora-core)
    of Actora core and NIOS-II on DE5-Net and DE10-Pro FPGAs

Below, there are some more details about what's been done so far.

## Contents

  * [1. Elite C Backend](#1-elite-c-backend)
  * [2. Actora Core](#2-actora-core)
  * [3. Elite Benchmarks](#3-elite-benchmarks)
  * [4. HIPE versus Elite C Backend](#4-hipe-versus-elite-c-backend)
  * [5. Elite C Backend versus Actora Core](
      #5-elite-c-backend-versus-actora-core)
  * [6. Actora Bytecode](#6-actora-bytecode)
  * [7. Error codes](#7-error-codes)

## 1. Elite C Backend

This is a C code generator that performs a like-for-like mapping from
Erlang functions to C functions, and from Erlang variables to C
variables.  As a result, it is both simple and efficient, exploiting
the optimisation capabilities of the C compiler, such as tail-call
optimisation, inlining, common subexpression elimination, and many
more.  However, a big drawback of the approach is that the garbage
collector must be *conservative* since pointers and integers cannot be
distinguished in C.  This also means that the garbage collector cannot
relocate objects, preventing the use of copying collectors, operating
in O(survivors) time, that work well for functional languages.  The
generated C code runs on both x86 and NIOS-II (small embedded RISC
core).

## 2. Actora Core

This is a simple [stack machine](#6-actora-bytecode) with a 3-stage
pipeline (Fetch, Decode, Execute).  It has separate memories for
instructions, stack data, and heap data.  The stack is implemented
using a dual-port RAM, allowing two stack elements to be accessed per
cycle.  The heap memory is two cells wide, since almost all heap
objects contain at least two cells.  Cells on the stack and heap are
both tagged with type information.  The tags of pointer cells contain
further information about the object pointed-to, such as its length
and arity (if it is a closure), often allowing patterns to be matched
and types to be checked without having to dereference. The core
supports a set of ALU primitives similar to those available on the
NIOS-II.  It also includes a fast copying garbage collector,
implemented as a small state-machine in hardware.  The compiler from
Elite to stack code is small and straightforward: in particular, there
is no register-file/spill optimisation required, avoiding much
complexity compared to a traditional RISC approach.

## 3. Elite Benchmarks

The following benchmarks are mostly representative of symbolic
functional programs, with plenty of pattern matching, recursion,
dynamic and persistent data structures.  One exception is *shiftsub*,
which is a tight tail-recursive loop with only primitive operations,
and should favour a register machine.

Benchmark | Description
--------- | -----------
[fib](/benchmarks/fib.erl) | Standard doubly-recursive fibonacci function
[adjoxo](/benchmarks/adjoxo.erl) | Adjudicator for naughts and crosses, involving sets as lists
[mss](/benchmarks/mss.erl) | Basic maximum segment sum function on lists
[redblack](/benchmarks/redblack.erl) | Insertion and membership functions on Red-Black trees
[while](/benchmarks/while.erl) | Operational semantics for a simple imperative language
[braun](/benchmarks/braun.erl) | Insertion and flattening functions on Braun trees
[queens](/benchmarks/queens.erl) | N-queens solver using success/fail continuation passing style
[shiftsub](/benchmarks/shiftsub.erl) | Binary long division

For further examples of Elite programs, see the [test suite](tests/).

## 4. HIPE versus Elite C Backend

We would like to use code generated by the Elite C Backend running on
the NIOS-II as a baseline to compare the performance the Actora Core.
Before that, it is useful to establish whether the Elite C Backend is
actually representative of the performance of existing Erlang
compilers.  We do this by comparing against **HIPE**, the
high-performance Erlang compiler, on an x86 machine.

Benchmark | HIPE (s) | Elite C backend (s) | GC (%) | Speedup
--------- | ----:    | -----:              | -----: | ------:
fib       | 1.06     |  1.02               | 0      |  1.03
adjoxo    | 0.40     |  0.39               | 38.40  |  1.02
mss       | 0.71     |  0.24               | 0.01   |  2.95
redblack  | 0.35     |  0.37               | 30.00  |  0.94
while     | 0.27     |  0.34               | 50.00  |  0.79
braun     | 0.21     |  0.33               | 45.45  |  0.63
queens    | 0.72     |  0.29               | 0.03   |  2.48
shiftsub  | 0.85     |  0.27               | 0      |  3.14

These results were obtained on an `Intel(R) Core(TM) i7-6770HQ CPU @
2.60GHz`.  The Elite C backend was given a 1MB heap.  The GC column
shows the proportion of time spent in the garbage collector
for the Elite C backend, not HIPE.

The results show that the Elite C backend provides decent performance.
It falls slightly short of HIPE only in the heap-intensive benchmarks,
were GC time (a known weakness) is significant.

## 5. Elite C Backend versus Actora Core

The Actora Core is slightly larger than a NIOS-II, and has a lower Fmax:

Implementation | DE5-Net Area (ALMs) | DE5-Net FMax (MHz)
-------------- | -----------------:  | -----------------:
NIOS-II        | 850 (0.0036%)       | 323
Elite core     | 1087 (0.0046%)      | 254     

Implementation | DE10-Pro Area (ALMs) | DE10-Pro FMax (MHz)
-------------- | ------------------:  | ------------------:
NIOS-II        | 1154 (0.0012%)       | 345
Elite core     | 1229 (0.0013%)       | 301     

Despite the lower Fmax, the Actora Core offers a performance
improvement (results for DE5-Net, both implementations use a 56KB
heap):

Benchmark | NIOS-II (s) | GC (%) | Actora core (s) | %GC    | Speedup
--------- | ----------: | -----: | -------------:  | -----: | ------:
fib       |   35.92     |      0 |  18.90          |     0  |  1.90
adjoxo    |   11.42     |  41.70 |   3.99          |  2.35  |  2.86
mss       |    7.81     |   1.97 |   4.73          |  0.23  |  1.65
redblack  |   11.26     |  39.47 |   4.86          |  7.87  |  2.31
while     |   12.12     |  42.65 |   3.30          |  2.31  |  3.67
braun     |   11.97     |  55.40 |   2.92          | 15.10  |  4.10
queens    |    7.89     |   3.80 |   6.09          |  0.10  |  1.30
shiftsub  |    7.41     |      0 |   4.76          |     0  |  1.55

Again, the difference is most visible in the benchmarks where GC time
is significant, which is a known weakness of the C backend (and
could probably be improved using a more sophisticated LLVM backend
instead).

The Actora Core is quite a modest attempt at a language-specific CPU in
the sense that aims to keep logic usage down -- we want to fit as many
instances of this core on an FPGA as we can.  But that goal has
resulted in only a modest performance improvement over a
space-optimised RISC core.

## 6. Actora Bytecode

```
           25---------------------15----------------------+
PushIPtr    | 1000000000           | data<16>             |
            +----------------------+----------------------+
PushInt     | 1000000001           | data<16>             |
            +----------------------+----------------------+
PushAtom    | 1000000010           | data<16>             |
            +----------------------+-------------5--------+
Slide       | 1000000100           | dist<10>    | n<6>   |
            +---------------------------------------------+
Return      | 1000000101           | dist<10>    | 000001 |
            +----------------------+----------------------+
Copy        | 1000000110           | n<16>                |
            +----------------------+----------------------+
Jump        | 1000001010           | addr<16>             |
            +----------------------+----------------------+
IJump       | 1000001011           |                      |
            +----------------------+-------14-------------+
Load        | 1000001101           | pop<1> |             |
            +----------------------+-----13------7------1-+
Store       | 1000001110           | k<2> | a<6> | n<6> | |
            +----------------------+----------------------+
Halt        | 1000001111           | error<16>            |
            +----------------------+----------------------+
Add         | 1000100000           |                      |
            +----------------------+----------------------+
Sub         | 1000100010           |                      |
            +----------------------+----------------------+
SetUpper    | 1000100101           | data<16>             |
            +----------------------+----------------------+
Eq          | 1000110000           |                      |
            +----------------------+----------------------+
NotEq       | 1000110010           |                      |
            +----------------------+----------------------+
Less        | 1000110100           |                      |
            +----------------------+----------------------+
GreaterEq   | 1000110110           |                      |
            +----------------------+----------------------+
And         | 1001000000           |                      |
            +----------------------+----------------------+
Or          | 1001000001           |                      |
            +----------------------+----------------------+
Xor         | 1001000010           |                      |
            +----------------------+----------------------+
ShiftRight  | 1001000100           |                      |
            +----------------------+----------------------+
AShiftRight | 1001000101           |                      |
            +----------------------+----------------------+
ShiftLeft   | 1001000110           |                      |
            +-----21---------------+----------------------+
CJumpPop    | 0000 | pop<6>        | addr<16>             |
            +------+-------20------+----------------------+
Match       | 0001 | neg<1> | c<5> | data<16>             |
            +------+--------+------+----------------------+
```

**PushIPtr**: Push a zero-extended instruction pointer onto the stack.

```
25          15         
+------------+----------+
| 1000000000 | data<16> |
+------------+----------+
```

**PushInt**: Push a sign-extended integer onto the stack.

```
25          15         
+------------+----------+
| 1000000001 | data<16> |
+------------+----------+
```

**PushAtom**: Push a zero-extended atom onto the stack.

```
25          15         
+------------+----------+
| 1000000010 | data<16> |
+------------+----------+
```

**Slide**: Slide the top `n` stack elements down the stack by `dist`
positions.

```
25          15          5
+------------+----------+------+
| 1000000100 | dist<10> | n<6> |
+------------+----------+------+
```

**Return**: Slide the top stack element down the stack by `dist`
positions.  The top two stack elements now contain the result and the
return address.  Pop these two elements, push the result, and jump to
the return address.

```
25          15     
+------------+----------+--------+
| 1000000101 | dist<10> | 000001 |
+------------+----------+--------+
```

**Copy**: Push the nth element from the stop of the stack onto the stack.

```
25          15      
+------------+-------+
| 1000000110 | n<16> |
+------------+-------+
```

**Jump**: Jump to given address (zero extended).

```
25          15     
+------------+----------+
| 1000001010 | addr<16> |
+------------+----------+
```

**IJump**: Jump to address on top of the stack.

```
25          15     
+------------+------------+
| 1000001011 | unused<16> |
+------------+------------+
```

**Load**: Load data from the heap at the address specified on top of
the stack, and push it onto the stack.  Optionally, the pointer can be
popped before pushing the heap data to the stack.

```
25          15      14
+------------+--------+------------+
| 1000001101 | pop<1> | unused<16> |
+------------+--------+------------+
```

**Store**: Pop the top `n` stack elements and append them to the heap.

```
25          15        13          7      1
+------------+---------+----------+------+-----------+
| 1000001110 | kind<2> | arity<6> | n<6> | unused<2> |
+------------+---------+----------+------+-----------+
```

The kind field is one of:

  * `00` - list constructor
  * `01` - tuple constructor
  * `10` - closure constructor

The `arity` is only valid when storing a closure.

**Add**: Replace the top two stack elements with their sum.

```
25          15     
+------------+------------+
| 1000100000 | unused<16> |
+------------+------------+
```

**Sub**: Replace the top two stack elements with their difference.

```
25          15     
+------------+------------+
| 1000100010 | unused<16> |
+------------+------------+
```

**Eq**: Replace the top two stack elements with `true` if equal,
otherwise `false.

```
25          15
+------------+------------+
| 1000110000 | unused<16> |
+------------+------------+
```

**NotEq**: Replace the top two stack elements with `true` if not equal,
otherwise `false.


```
25          15
+------------+------------+
| 1000110010 | unused<16> |
+------------+------------+
```

**Less**: Replace the top two stack elements with `true` if the first
is strictly less than the second, otherwise `false`.

```
25          15
+------------+------------+
| 1000110100 | unused<16> |
+------------+------------+
```

**GreaterEq**: Replace the top two stack elements with `true` if the first 
is greater than or equal to the second, otherwise `false`.

```
25          15
+------------+------------+
| 1000110110 | unused<16> |
+------------+------------+
```

**SetUpper**:  Overwrite the upper 16 bits of the top stack element
with the given data.

```
25          15         
+------------+----------+
| 1000100101 | data<16> |
+------------+----------+
```

**Halt**: Terminate with the given error code.

```
25          15
+------------+------------+
| 1000001111 | error<16>  |
+------------+------------+
```

**Match**: Match the top stack element according to condition, and set
the condition flag.

```
25     21       20       16
+------+--------+---------+----------+
| 0001 | neg<1> | cond<5> | data<16> |
+------+--------+---------+----------+
```

The 5-bit condition `cond` on the top stack element, which may be
negated using the `neg` bit, has the following format.


  * `00000` - Is top a function pointer?
  * `00001` - Is top an int with value == signExtend(data)?
  * `00010` - Is top an atom with value == zeroExtend(data)?
  * `00100` - Is top a pointer to a cons constructor?
  * `00101` - Is top a pointer to a tuple of length data?
  * `00110` - Is top a pointer to a closure of arity data?

**CJumpPop**: Conditional jump and pop from stack based on condition
flag.  If the jump is taken, a given number of items are popped from
the stack.

```
25     21       16
+------+--------+----------+
| 0000 | pop<6> | addr<16> |
+------+--------+----------+
```

**And**: Replace the top two stack elements with their bitwise conjunction.

```
25          15     
+------------+------------+
| 1001000000 | unused<16> |
+------------+------------+
```

**Or**: Replace the top two stack elements with their bitwise
disjunction.

```
25          15     
+------------+------------+
| 1001000001 | unused<16> |
+------------+------------+
```

**Xor**: Replace the top two stack elements with their bitwise xor.

```
25          15     
+------------+------------+
| 1001000010 | unused<16> |
+------------+------------+
```

**ShiftRight**: Replace the top two stack elements with the first
element logically shifted right by the second element.

```
25          15
+------------+------------+
| 1001000100 | unused<16> |
+------------+------------+
```

**AShiftRight**: Replace the top two stack elements with the first
element arithmetically shifted right by the second element.

```
25          15
+------------+------------+
| 1001000101 | unused<16> |
+------------+------------+
```

**ShiftLeft**: Replace the top two stack elements with the first
element logically shifted left by the second element.

```
25          15
+------------+------------+
| 1001000110 | unused<16> |
+------------+------------+
```

## 7. Error codes

  Error           | Code   | Meaning
  --------------- | ------ | -------
  ENone           | 0      | No error
  EStackOverflow  | 1      | Stack overflow
  EHeapOverflow   | 2      | Live heap too large
  EArith          | 3      | Bad type in arithmetic operand(s)
  ELoadAddr       | 4      | Load address is not a data pointer
  EJumpAddr       | 5      | Jump/branch/call target is not an instr pointer
  EStackIndex     | 6      | Stack index out of bounds
  EUnknown        | 7      | Unknown error
  EInstrIndex     | 8      | Instruction index out of bounds
  EUnknownInstr   | 9      | Unrecognised instruction
  EStackUnderflow | 10     | Stack underflow
  EBindFail       | 16     | Pattern mismatch in binding
  ECaseFail       | 17     | No matching case alternatives
  EEqnFail        | 18     | No matching equation
  EApplyFail      | 19     | Application of non-closure
