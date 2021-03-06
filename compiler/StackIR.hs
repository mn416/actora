-- Stack intermediate representation

module StackIR where

import Data.Map as M
import Data.Set as S
import Data.List as L

-- Some meaningful type names, for readability
type Arity = Int
type StackOffset = Int
type InstrAddr = Int
type NumAtoms = Int
type PopAmount = Int
type ErrorCode = String

-- An instruction pointer before linking is a label,
-- and after linking is an address
data InstrPtr =
    InstrLabel String
  | InstrAddr InstrAddr
  deriving (Eq, Ord, Show)

-- Atoms are words residing on the stack and heap
data Atom =
    FUN InstrPtr
  | INT Int
  | ATOM String
  | PTR PtrKind NumAtoms Int
  deriving (Eq, Ord, Show)

-- Pointers can point to partial applications, tuples, and cons cells
data PtrKind = PtrApp Arity | PtrTuple | PtrCons
  deriving (Eq, Ord, Show)

-- Primitive operators
data Prim =
    PrimAdd
  | PrimSub
  | PrimAddImm Int
  | PrimSubImm Int
  | PrimEq
  | PrimNotEq
  | PrimLess
  | PrimGreaterEq
  | PrimInv
  | PrimAnd
  | PrimOr
  | PrimXor
  | PrimShiftLeft
  | PrimShiftRight
  | PrimArithShiftRight
  deriving Show

-- Instruction set
data Instr =
    LABEL String
  | PUSH Atom
  | SETU Int
  | COPY StackOffset
  | JUMP InstrPtr
  | IJUMP
  | SLIDE PopAmount NumAtoms
  | RETURN PopAmount
  | SLIDE_JUMP PopAmount NumAtoms InstrPtr
  | LOAD Bool
  | STORE NumAtoms PtrKind
  | MATCH BranchCond
  | CJUMPPOP PopAmount InstrPtr
  | PRIM Prim
  | HALT ErrorCode
  deriving Show

-- Branch conditions
type BranchCond = (Polarity, BCond)
data Polarity = Pos | Neg deriving (Eq, Ord, Show)

data BCond =
    IsAtom String
  | IsInt Int
  | IsCons
  | IsTuple NumAtoms
  | IsApp Arity
  deriving (Eq, Ord, Show)

-- Replace labels with addresses
link :: [Instr] -> ([Instr], M.Map String InstrAddr)
link instrs = (L.map replace (dropLabels instrs), toAddr)
  where
    -- Compute mapping from labels to addresses
    compute i [] = []
    compute i (LABEL s:rest) = (s, i) : compute i rest
    compute i (instr:rest) = compute (i+1) rest

    -- Mapping from labels to addresses
    toAddr = M.fromList (compute 0 instrs)

    -- Determine address for given label
    resolve s =
      case M.lookup s toAddr of
        Nothing -> error ("link: unknown label " ++ s)
        Just addr -> InstrAddr addr

    -- Drop all labels
    dropLabels [] = []
    dropLabels (LABEL s:rest) = dropLabels rest
    dropLabels (i:is) = i : dropLabels is

    -- Replace labels with addresses
    replace (PUSH (FUN (InstrLabel s))) = PUSH (FUN (resolve s))
    replace (SLIDE_JUMP n m (InstrLabel s)) = SLIDE_JUMP n m (resolve s)
    replace (JUMP (InstrLabel s)) = JUMP (resolve s)
    replace (CJUMPPOP pop (InstrLabel s)) = CJUMPPOP pop (resolve s)
    replace other = other

-- Determine all atoms used
atoms :: [Instr] -> [String]
atoms is = 
  reserved ++ S.toList (S.unions (L.map get is) S.\\ S.fromList reserved)
  where
    reserved = ["false", "true", "[]"]
    get (PUSH (ATOM a)) = S.singleton a
    get (MATCH (_, IsAtom a)) = S.singleton a
    get other = S.empty
