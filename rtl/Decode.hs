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

-- Cons, tuple and closure cells all contain heap pointers
isPtr :: Cell -> Bit 1
isPtr cell = index @2 (cell.tag)

-- If it's a pointer, then bits [31:26] of the cell contents
-- hold the length of the object pointed-to.  This field
-- might be enlarged in future to support arrays.
getObjectLen :: Cell -> Bit 6
getObjectLen cell = range @31 @26 (cell.content)

-- If it's a pointer to a closure, bits [25:20] of the cell
-- contents hold the arity of the closure, i.e. how many
-- arguments still need to be applied.
getClosureArity :: Cell -> Bit 6
getClosureArity cell = range @25 @20 (cell.content)

-- Extract pointer value from cell
getObjectPtr :: Cell -> HeapPtr
getObjectPtr cell = truncate (range @19 @0 (cell.content))

-- Instructions
-- ============

-- 26-bit instructions
type Instr = Bit 26

-- The top 10 bits contains the opcode
opcode :: Instr -> Bit 10
opcode = range @25 @16

-- Many instructions contain a 16-bit operand
operand :: Instr -> Bit 16
operand = range @15 @0

-- Is it a Push instruction?
isPush :: Instr -> Bit 1
isPush i = index @25 i .&. (range @5 @2 (i.opcode) .==. 0b0000)

-- Determine value to push
getPushVal :: Instr -> Cell
getPushVal i =
  Cell {
    tag = 0b0 # range @1 @0 (i.opcode)
  , content = signExtend (sign # (i.operand))
  }
  where
    sign = index @0 i ? (index @15 i, 0)

-- Is it a Slide or Return instruction?
isSlide :: Instr -> Bit 1
isSlide i = index @25 i .&. (range @5 @1 (i.opcode) .==. 0b00010)

-- Assuming isSlide, is it a Return?
isReturn :: Instr -> Bit 1
isReturn = index @16

-- Determine distance of Slide
getSlideDist :: Instr -> Bit 10
getSlideDist = range @15 @6

-- Determine length of Slide
getSlideLen :: Instr -> Bit 6
getSlideLen = range @5 @0

-- Is it a Copy instruction?
isCopy :: Instr -> Bit 1
isCopy i = index @25 i .&. (range @5 @0 (i.opcode) .==. 0b000110)

-- Is it a Jump, IJump, Call, or ICall instruction?
isControl :: Instr -> Bit 1
isControl i = index @25 i .&. (range @5 @2 (i.opcode) .==. 0b0010)

-- Assuming isControl, is it an Jump or IJump?
isJump :: Instr -> Bit 1
isJump = index @17

-- Assuming isControl, is it an IJump or ICall?
isIndirect :: Instr -> Bit 1
isIndirect = index @16

-- Is it a Load instruction?
isLoad :: Instr -> Bit 1
isLoad i = index @25 i .&. (range @5 @0 (i.opcode) .==. 0b001101)

-- Assuming isLoad, should the pointer be popped before loading?
isLoadPop :: Instr -> Bit 1
isLoadPop = index @15

-- Is it a Store instruction?
isStore :: Instr -> Bit 1
isStore i = index @25 i .&. (range @5 @0 (i.opcode) .==. 0b001110)

-- What's the tag for data being stored?
getStoreTag :: Instr -> Tag
getStoreTag i = (1 :: Bit 1) # range @15 @14 i

-- What's the arity of the closure being stored?
getStoreArity :: Instr -> Bit 6
getStoreArity = range @13 @8

-- What's the length of the object being stored?
getStoreLen :: Instr -> Bit 6
getStoreLen = range @7 @2

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
isHalt i = index @25 i .&. (range @5 @0 (i.opcode) .==. 0b001111)

-- Is it a primitive function?
isPrim :: Instr -> Bit 1
isPrim i = index @25 i .&. index @5 (i.opcode)

-- Assuming isPrim, is it an arithmetic instruction?
isArith :: Instr -> Bit 1
isArith i = inv (index @4 (i.opcode))

-- Assuming isPrim, is it a comparison?
isComparison :: Instr -> Bit 1
isComparison i = index @4 (i.opcode)

-- Assuming isArith, is it an Add or Sub?
isAddOrSub :: Instr -> Bit 1
isAddOrSub i = range @3 @2 (i.opcode) .==. 0b00

-- Assuming isAddOrSub, is it a Sub?
isSub :: Instr -> Bit 1
isSub i = index @1 (i.opcode)

-- Assuming isAddOrSub, is it an Add?
isAdd :: Instr -> Bit 1
isAdd i = inv (index @1 (i.opcode))

-- Assuming isArith, is it a SetUpper?
isSetUpper :: Instr -> Bit 1
isSetUpper i = range @3 @1 (i.opcode) .==. 0b010

-- Assuming isComparison, is it an Eq or NotEq?
isEq :: Instr -> Bit 1
isEq i = range @3 @2 (i.opcode) .==. 0b00

-- Assuming isComparison, is it a Less or GreaterEq?
isLess :: Instr -> Bit 1
isLess i = range @3 @2 (i.opcode) .==. 0b01

-- Assuming isComparison, should comparison be negated?
isNegCmp :: Instr -> Bit 1
isNegCmp i = index @1 (i.opcode)

-- Is it a BranchPop instruction?
isBranchPop :: Instr -> Bit 1
isBranchPop i = inv (index @25 i)

-- Format of BranchPop instruction
data BranchPop =
  BranchPop {
    branchOp     :: Bit 1
  , branchNeg    :: Bit 1
  , branchTag    :: Tag
  , branchArg    :: Bit 6
  , branchPop    :: Bit 5
  , branchOffset :: Bit 10
  }
  deriving (Generic, Bits, FShow)