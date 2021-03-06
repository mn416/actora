module Decode where

-- Bit-level representation of instructions and data.
-- See doc/ISA.md for more details.

import Blarney
import Types

-- Stack/Heap cells
-- ================

-- Stack/Heap cell type
data Cell = Cell { tag :: Tag, content :: Bit 32 }
  deriving (Generic, Bits, FShow)

-- Tag type
type Tag = Bit 3

-- Tag values
funTag, intTag, atomTag, consTag, tupleTag, closureTag :: Tag
funTag     = 0b000
intTag     = 0b001
atomTag    = 0b010
consTag    = 0b100
tupleTag   = 0b101
closureTag = 0b110
gcTag      = 0b111

-- Cons, tuple and closure cells all contain heap pointers
isPtr :: Cell -> Bit 1
isPtr cell = at @2 (cell.tag)

-- If it's a pointer, then bits [31:26] of the cell contents
-- hold the length of the object pointed-to.  This field
-- might be enlarged in future to support arrays.
getObjectLen :: Cell -> Bit 6
getObjectLen cell = slice @31 @26 (cell.content)

-- If it's a pointer to a closure, bits [25:20] of the cell
-- contents hold the arity of the closure, i.e. how many
-- arguments still need to be applied.
getClosureArity :: Cell -> Bit 6
getClosureArity cell = slice @25 @20 (cell.content)

-- Extract pointer value from cell
getObjectPtr :: Cell -> HeapPtr
getObjectPtr cell = truncate (slice @19 @0 (cell.content))

-- Change a pointer in a cell
modifyPtr :: Cell -> HeapPtr -> Cell
modifyPtr cell p = 
  cell { content = (cell.getObjectLen) # (cell.getClosureArity) # 0 # p }

-- Instructions
-- ============

-- 26-bit instructions
type Instr = Bit 26

-- The top 10 bits contains the opcode
opcode :: Instr -> Bit 10
opcode = slice @25 @16

-- Many instructions contain a 16-bit operand
operand :: Instr -> Bit 16
operand = slice @15 @0

-- Is it a Push instruction?
isPush :: Instr -> Bit 1
isPush i = at @25 i .&. (slice @6 @2 (i.opcode) .==. 0b00000)

-- Determine value to push
getPushVal :: Instr -> Cell
getPushVal i =
  Cell {
    tag = 0b0 # slice @1 @0 (i.opcode)
  , content = signExtend (sign # (i.operand))
  }
  where
    sign = at @0 i ? (at @15 i, 0)

-- Is it a Slide instruction?
isSlide :: Instr -> Bit 1
isSlide i = at @25 i .&. (slice @6 @1 (i.opcode) .==. 0b000010)

-- Assuming isSlide, is it a Return instruction?
isReturn :: Instr -> Bit 1
isReturn i = at @0 (i.opcode)

-- Determine distance of Slide
getSlideDist :: Instr -> Bit 10
getSlideDist = slice @15 @6

-- Determine length of Slide
getSlideLen :: Instr -> Bit 6
getSlideLen = slice @5 @0

-- Is it a Copy instruction?
isCopy :: Instr -> Bit 1
isCopy i = at @25 i .&. (slice @6 @0 (i.opcode) .==. 0b0000110)

-- Is it a Jump, IJump instruction?
isControl :: Instr -> Bit 1
isControl i = at @25 i .&. (slice @6 @2 (i.opcode) .==. 0b00010)

-- Assuming isControl, is it a direct or indirect jump?
isIndirect :: Instr -> Bit 1
isIndirect = at @16

-- Is it a Load instruction?
isLoad :: Instr -> Bit 1
isLoad i = at @25 i .&. (slice @6 @0 (i.opcode) .==. 0b0001101)

-- Assuming isLoad, should the pointer be popped before loading?
isLoadPop :: Instr -> Bit 1
isLoadPop = at @15

-- Is it a Store instruction?
isStore :: Instr -> Bit 1
isStore i = at @25 i .&. (slice @6 @0 (i.opcode) .==. 0b0001110)

-- What's the tag for data being stored?
getStoreTag :: Instr -> Tag
getStoreTag i = (1 :: Bit 1) # slice @15 @14 i

-- What's the arity of the closure being stored?
getStoreArity :: Instr -> Bit 6
getStoreArity = slice @13 @8

-- What's the length of the object being stored?
getStoreLen :: Instr -> Bit 6
getStoreLen = slice @7 @2

-- What's the pointer for given store instruction and heap pointer?
makeStorePtr :: Instr -> HeapPtr -> Cell
makeStorePtr i p =
  Cell {
    tag = i.getStoreTag
  , content =
      (i.getStoreLen) # (i.getStoreArity) # 0 # p
  }

-- Is it a Halt instuction?
isHalt :: Instr -> Bit 1
isHalt i = at @25 i .&. (slice @6 @0 (i.opcode) .==. 0b0001111)

-- Is it a primitive function?
isPrim :: Instr -> Bit 1
isPrim i = at @25 i .&. at @5 (i.opcode)

-- Assuming isPrim, is it an arithmetic instruction?
isArith :: Instr -> Bit 1
isArith i = inv (at @4 (i.opcode))

-- Assuming isPrim, is it a comparison?
isComparison :: Instr -> Bit 1
isComparison i = at @4 (i.opcode)

-- Assuming isArith, is it an Add or Sub?
isAddOrSub :: Instr -> Bit 1
isAddOrSub i = slice @3 @2 (i.opcode) .==. 0b00

-- Assuming isAddOrSub, is it a Sub?
isSub :: Instr -> Bit 1
isSub i = at @1 (i.opcode)

-- Assuming isAddOrSub, is it an Add?
isAdd :: Instr -> Bit 1
isAdd i = inv (at @1 (i.opcode))

-- Assuming isArith, is it a SetUpper?
isSetUpper :: Instr -> Bit 1
isSetUpper i = slice @3 @1 (i.opcode) .==. 0b010

-- Assuming isComparison, is it an Eq or NotEq?
isEq :: Instr -> Bit 1
isEq i = slice @3 @2 (i.opcode) .==. 0b00

-- Assuming isComparison, is it a Less or GreaterEq?
isLess :: Instr -> Bit 1
isLess i = slice @3 @2 (i.opcode) .==. 0b01

-- Assuming isComparison, should comparison be negated?
isNegCmp :: Instr -> Bit 1
isNegCmp i = at @1 (i.opcode)

-- Is it a CJumpPop instruction?
isCJumpPop :: Instr -> Bit 1
isCJumpPop i = inv (at @25 i) .&. inv (at @22 i)

-- Get pop amount from CJumpPop instruction
getCJumpPop :: Instr -> Bit 6
getCJumpPop = slice @21 @16

-- Is it a Match instruction?
isMatch :: Instr -> Bit 1
isMatch i = inv (at @25 i) .&. at @22 i

-- Is Match condition negated?
isMatchNeg :: Instr -> Bit 1
isMatchNeg = at @21

-- Get condition from Match instruction
getMatchCond :: Instr -> Bit 3
getMatchCond = slice @18 @16

-- Is it a multicycle primitive?
isMultiPrim :: Instr -> Bit 1
isMultiPrim i = at @25 i .&. at @6 (i.opcode)

-- Assuming isMultiPrim, is it a bitwise operation?
isBitwise :: Instr -> Bit 1
isBitwise i = inv (at @2 (i.opcode))

-- Assuming isBitwise, is it a bitwise and?
isAnd :: Instr -> Bit 1
isAnd i = slice @1 @0 (i.opcode) .==. 0b00

-- Assuming isBitwise, is it a bitwise or?
isOr :: Instr -> Bit 1
isOr i = slice @1 @0 (i.opcode) .==. 0b01

-- Assuming isBitwise, is it a bitwise xor?
isXor :: Instr -> Bit 1
isXor i = slice @1 @0 (i.opcode) .==. 0b10

-- Assuming isMultiPrim, is it a shift operation?
isShift :: Instr -> Bit 1
isShift i = at @2 (i.opcode)

-- Assuming isShift, is it a left shift?
isLeftShift :: Instr -> Bit 1
isLeftShift i = at @1 (i.opcode)

-- Assuming isShift, is it an arithmetic shift?
isArithShift :: Instr -> Bit 1
isArithShift i = at @0 (i.opcode)

-- Exceptions
-- ==========

excNone           = 0
excStackOverflow  = 1
excHeapOverflow   = 2
excArith          = 3
excLoadAddr       = 4
excJumpAddr       = 5
excStackIndex     = 6
excUnknown        = 7
excInstrIndex     = 8
excUnknownInstr   = 9
excStackUnderflow = 10
excBindFail       = 16
excCaseFail       = 17
excEqnFail        = 18
excApplyFail      = 19
