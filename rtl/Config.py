#!/usr/bin/env python2

import sys

# Circuit-generator parameters
p = {}

# Instruction memory size (in instructions)
p["LogInstrMemSize"] = 11

# Stack size (in cells)
p["LogStackSize"] = 11

# Heap size (in cells)
p["LogHeapSize"] = 13

# Heap size (in cell pairs)
p["LogHeapSizeMinusOne"] = p["LogHeapSize"] - 1

# GC scratchpad size (in cell pairs)
p["LogScratchpadSizeMinusOne"] = p["LogHeapSizeMinusOne"] - 1

# GC threshold (GC invoked when heap size passes this)
p["GCThreshold"] = (
    (2 ** p["LogHeapSizeMinusOne"]) - (2 ** (p["LogStackSize"]-1)) - 32
  )

# Emit parameters in desired format
if len(sys.argv) > 1:
  mode = sys.argv[1]
else:
  print "Usage: config.py <hw-cpp|cpp>"
  sys.exit(-1)

if mode == "hw-cpp":
  for var in p:
    print("#define " + var + " " + str(p[var]))
elif mode == "cpp":
  for var in p:
    print("#define Act" + var + " " + str(p[var]))
