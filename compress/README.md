The `./compress_pkg.vhd` package holds some vital functions:
- `trunc`, the truncate function
- `f_GB`, the round function
- `f_PERMUTATE`, the permutation function P

The `./compress.vhd` file will hold the statemachine for the component.

## Proposed Interface for the compression interface

Inputs:

	- All Signals related to using the memory controller for external memory
	- Indices from the indexing function to access correct `B[i][j]`

Outputs:

	- All Signals related to using the memory controller for external memory
	- Some kind of ready / finished indicator
	- A 1024 Byte sized output vector (which will propably written to memory)
