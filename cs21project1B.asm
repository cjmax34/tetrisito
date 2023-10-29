# CS 21 LAB2 -- S2 AY 2022-2023
# Calvin James T. Maximo -- 21/05/2023
# cs21project1B.asm -- Project 1 (Implementation B with Bonus 2 - Line Clearing)
.data 	
	.eqv 	gridOne, $s0
	.eqv 	gridTwo, $s1
	
	.eqv 	grid, $s0		
	.eqv 	gridCopy, $s1
	.eqv 	piece, $s2
	
	.eqv	currGrid, $s0
	.eqv	pieces, $s1
	.eqv	i, $s2
	
	.eqv 	nextGrid, $s0
	
	.eqv 	hashtag, 0x23
	.eqv 	X, 0x58
	.eqv	dot, 0x2e
	
	yes:	.asciiz	"YES"
	no:	.asciiz	"NO"
	
.macro allocate_heap(%num_of_bytes)
	li 	$a0, %num_of_bytes	# Allocate # of bytes
	do_syscall(9)		# Allocate heap memory
.end_macro

.macro do_syscall(%callnumber)
	li 	$v0, %callnumber
	syscall
.end_macro

.macro string_input(%num_of_bytes)
	allocate_heap(%num_of_bytes)	# Allocate %num_of_bytes bytes to heap memory
	move 	$a0, $v0		# Move address of allocated heap memory to $a0
	addi 	$a1, $0, %num_of_bytes	# Allows the user to input #-1 of characters
	do_syscall(8)			# Syscall 8 for string input
.end_macro

.macro exit_program
	do_syscall(10)
.end_macro

.macro initialize_empty_rows
	allocate_heap(32)
	li 	$t0, 0x2e2e2e2e	# Equal to ....
	sw 	$t0, 0($v0)
	sw 	$t0, 8($v0)
	sw 	$t0, 16($v0)
	sw 	$t0, 24($v0)	
	
	li 	$t0, 0x00002e2e	# Equal to \0\0..
	sw 	$t0, 4($v0)
	sw 	$t0, 12($v0)
	sw 	$t0, 20($v0)
	sw 	$t0, 28($v0)
	
	li 	$t0, 0	# Clear temporary register
.end_macro

.text
main:
	initialize_empty_rows		# Initialize first 4 empty rows of start grid
	sw 	$v0, 0($gp)		# Store address of start_grid in $gp + 0
	jal 	input_6x6
	
	initialize_empty_rows		# Initialize first 4 empty rows of final grid	
	sw 	$v0, 4($gp)		# Store address of final_grid in $gp + 4
	jal 	input_6x6

	get_numPieces:
	do_syscall(5)			# Get input for number of pieces
    	sw 	$v0, 8($gp)		# Store numPieces in $gp + 8
	
	jal 	get_input_pieces	# Asks the user to input pieces
	sw 	$v0, 12($gp)		# Store address[piecesAscii] to $gp + 12
	
	jal 	convert_piece_to_pairs	# Converts the input pieces to (row, col) coordinates
	sw	$v0, 16($gp)		# Store address[converted_pieces]
	
	lw 	$a0, 0($gp)		# $a0 = start_grid
	lw 	$a1, 16($gp)		# $a1 = converted_pieces	
	addi 	$a2, $0, 0		# $a2 = 0
	jal 	backtrack		# backtrack(start_grid, converted_pieces, 0)
	
	beq 	$v0, 0, return_no	# $v0 = TRUE? Otherwise, branch
	la 	$a0, yes		
	do_syscall(4)			# Print 'YES'
	j 	exit
	
	return_no:
	la 	$a0, no
	do_syscall(4)			# Print 'YES'
	
exit:	exit_program			# Terminate the program

	
### Functions	
input_6x6:	# Input last 6 rows of start and final grid
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$s0, 28($sp)
	sw 	$s1, 24($sp)
	sw 	$s2, 20($sp)
	sw 	$ra, 16($sp)
	####preamble####
	addi 	$s0, $0, 0 # i = 0
	input_6x6_loop:	
		beq 	$s0, 6, exit_input_6x6	# branch when i = 6
		allocate_heap(8)	# allocate 8 bytes
		addi 	$s1, $v0, 0	# $s1 = address at $v0
		addi 	$a0, $v0, 0	# $a0 = address at $v0
		li 	$a1, 8		# Input 8-1 = 7 characters long
		li 	$v0, 8		# Syscall 8 for string input
		syscall
		addi 	$s2, $0, 0 	# j = 0
		frozen:			# mark frozen blocks as 'X'
			beq 	$s2, 6, exit_frozen	# exit when j = 6
			li 	$t0, hashtag		# Loads ASCII value of # into $t0
			lb 	$t1, 0($s1)		# Get byte at addr[$s1]
			beq 	$t0, $t1, append_x	# Branch if row[j] == '#'
			addi 	$s1, $s1, 1		# increment address by 1
			addi 	$s2, $s2, 1		# increment j
			j frozen
			append_x:
			li 	$t0, X		# Loads ASCII value of X into $t0
			sb 	$t0, 0($s1)	# Stores ASCII value of X in addr[$s1]
			addi 	$s1, $s1, 1	# increment address by 1
			addi 	$s2, $s2, 1	# increment j
			j 	frozen
		exit_frozen:
			addi 	$s0, $s0, 1	# increment i
			j 	input_6x6_loop
	exit_input_6x6:
	####end####
	lw 	$s0, 28($sp)
	lw 	$s1, 24($sp)
	lw 	$s2, 20($sp)
	lw 	$ra, 16($sp)
	addi 	$sp, $sp, 32
	####end####
	jr 	$ra

get_input_pieces: # Gets the input pieces from the player
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$ra, 28($sp)
	sw 	$s0, 24($sp)
	sw 	$s1, 20($sp)
	sw 	$s2, 16($sp)
	sw 	$s3, 12($sp)
	####preamble####
	addi 	$s0, $0, 0	# counter of for _ in range(numPieces)
	lw 	$s1, 8($gp)	# $s1 = numPieces
	get_input_pieces_outer:
		beq 	$s0, $s1, exit_get_input_pieces	# if $s0 == numPieces, exit the loop
		addi 	$s2, $0, 0	# counter for for _ in range(4)
		get_input_pieces_inner:
			beq 	$s2, 4, exit_get_input_pieces_inner	# if $s2 == 4, exit inner loop
			string_input(8)	# Input for each row of the piece
			addi 	$s2, $s2, 1	# Increment $s2/inner counter
			j 	get_input_pieces_inner	
		exit_get_input_pieces_inner:
		addi 	$s0, $s0, 1	# Increment $t0/outer counter
		j 	get_input_pieces_outer
	exit_get_input_pieces:
	move 	$t0, $a0	# Get address of last row of last input piece
	addi 	$t1, $0, 32	# Load 32 to $t0 for multiplying to numPieces
	mult 	$s1, $t1	# numPieces * 32
	mflo 	$t1		# Computes the address of first row of first input piece in the heap
	sub 	$t0, $t0, $t1	# 
	addi 	$t0, $t0, 8 	# Address of first row of first input piece in the heap
	move 	$v0, $t0	# Store address in $v0
	####end####
	lw 	$ra, 28($sp)
	lw 	$s0, 24($sp)
	lw 	$s1, 20($sp)
	lw 	$s2, 16($sp)
	lw 	$s3, 12($sp)
	addi 	$sp, $sp, 32
	####end####
	jr 	$ra	
	
convert_piece_to_pairs: # Converts each # of piece to a tuple of coordinates (row, col)
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$ra, 28($sp)
	sw 	$s0, 24($sp)
	sw 	$s1, 20($sp)
	sw 	$s2, 16($sp)
	sw 	$s3, 12($sp)
	sw 	$s4, 8($sp)
	####preamble####
	addi 	$t0, $0, 8	# 8 bytes per set of coordinates of a piece
	lw 	$t1, 8($gp)	# $t1 = numPieces
	mult 	$t1, $t0	# Gets the total number of bytes to allocate in heap memory for storing the coordinates
	mflo 	$a0		# Store the result in $a0
	do_syscall(9)		# Allocate bytes in heap memory
	
	move 	$s0, $v0	# Store the address of converted_pieces
	move 	$t0, $s0	# Store a temporary copy of addr[converted_pieces] in $t0 to be used in this function
	lw 	$t1, 12($gp)	# Store a temporary copy of addr[pieceAscii] in $t4 to be used in this function
	
	addi 	$s1, $0, 0 	# counter for outer loop
	lw 	$s2, 8($gp)	# $s2 = numPieces
	
	convert_piece_to_pairs_outer:
		beq 	$s1, $s2, exit_convert_piece_to_pairs	# If $s1 = numPieces, exit	
		addi 	$s3, $0, 0		# row = 0
		convert_piece_to_pairs_row:
			beq 	$s3, 4, exit_convert_piece_to_pairs_row
			addi 	$s4, $0, 0		# col = 0 
			convert_piece_to_pairs_col:
				beq 	$s4, 4, exit_convert_piece_to_pairs_col
				lb 	$t2, 0($t1) 	# Get byte at address at $t1
				beq 	$t2, hashtag, store_pair # Store (row,col) if $t5 == '#'
				addi 	$t1, $t1, 1	# Increment addr[pieceAscii] by 1
				addi 	$s4, $s4, 1	# Increment col
				j 	convert_piece_to_pairs_col
			store_pair:
				sb 	$s3, 0($t0)	# Store row coordinate in converted_pieces
				addi 	$t0, $t0, 1	# Increment addr[converted_pieces] by 1
				sb	$s4, 0($t0)	# Store col coordinate in converted_pieces
				addi 	$t0, $t0, 1	# Increment addr[converted_pieces] by 1
				addi 	$t1, $t1, 1	# Increment addr[pieceAscii] by 1
				addi 	$s4, $s4, 1	# Increment col
				j 	convert_piece_to_pairs_col
			exit_convert_piece_to_pairs_col:
				addi 	$t1, $t1, 4	# Increment addr[pieceAscii] by 4 (move to next row of input piece)
				addi 	$s3, $s3, 1	# Increment row
				j 	convert_piece_to_pairs_row
		exit_convert_piece_to_pairs_row:
			addi 	$s1, $s1, 1	# Increment outer loop counter
			j 	convert_piece_to_pairs_outer
	exit_convert_piece_to_pairs:
	move 	$v0, $s0	# $v0 = addr[converted_pieces]
	####end####
	lw 	$ra, 28($sp)
	lw 	$s0, 24($sp)
	lw 	$s1, 20($sp)
	lw 	$s2, 16($sp)
	lw 	$s3, 12($sp)
	lw 	$s4, 8($sp)
	addi 	$sp, $sp, 32
	####end####
	jr 	$ra
	
is_equal_grids:	# Compare if two grids (gridOne and gridTwo) are equal, returns result
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$ra, 28($sp)
	sw 	gridOne, 24($sp)
	sw 	gridTwo, 20($sp)
	sw 	$s2, 16($sp)
	sw 	$s3, 12($sp)
	sw 	$s4, 8($sp)
	####preamble####
	move 	gridOne, $a0	# Move address of $a0 (1st input grid) to gridOne
	move 	gridTwo, $a1	# Move address of $a1 (2nd input grid) to gridTwo
	move 	$t0, gridOne	# Move gridOne to $t0 for manipulating in function
	move 	$t1, gridTwo	# Move gridTwo to $t1 for manipulating in function
	
	addi 	$s2, $0, 1	# result = True
	addi 	$s3, $0, 0	# i = 0
	
	is_equal_grids_i:
		beq 	$s3, 10, exit_is_equal_grids	# Exit when i = 10
		addi 	$s4, $0, 0	# j = 0
		is_equal_grids_j:
			beq 	$s4, 6, exit_is_equal_grids_j	# Exit when j = 6
			lb 	$t2, 0($t0)	# Load character at addr[gridOne]
			addi 	$t0, $t0, 1	# Increment addr[gridOne] by 1
			lb 	$t3, 0($t1)	# Load character at addr[gridTwo]
			addi 	$t1, $t1, 1	# Increment addr[gridTwo] by 1
			bne 	$t2, $t3, is_equal_grids_false	# return result = False
			addi 	$s2, $0, 1	# result = result AND (gridOne[i][j] == gridTwo[i][j])
			addi 	$s4, $s4, 1	# Increment j
			j 	is_equal_grids_j					
		exit_is_equal_grids_j:
		addi 	$t0, $t0, 2	# Increment addr[gridOne] by 2 to move to next row of gridOne
		addi 	$t1, $t1, 2	# Increment addr[gridOne] by 2 to move to next row of gridOne
		addi 	$s3, $s3, 1	# Increment i
		j 	is_equal_grids_i
	is_equal_grids_false:
		addi 	$s2, $0, 0	# result = False
	exit_is_equal_grids:
	move 	$v0, $s2	# Store result in $v0
	####end####
	lw 	$ra, 28($sp)
	lw 	gridOne, 24($sp)
	lw 	gridTwo, 20($sp)
	lw 	$s2, 16($sp)
	lw 	$s3, 12($sp)
	lw 	$s4, 8($sp)
	addi 	$sp, $sp, 32
	####end###
	jr 	$ra

get_max_x_of_piece:	# Get x value of rightmost block of piece
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$ra, 28($sp)
	sw 	$s0, 24($sp)
	sw 	$s1, 20($sp)
	sw 	$s2, 16($sp)
	####preamble####
	move 	$s0, $a0		# $s0 = addr[piece]
	move 	$t0, $s0		# $t0 = $s0 for use in function
	addi 	$s1, $0, -1		# max_x = -1
	addi 	$s2, $0, 0		# block = 0
	get_max_x_of_piece_loop:
		beq 	$s2, 4, end_get_max_x_of_piece	# Exit once finished iterating through all blocks of the piece
		lb 	$t1, 1($t0)		# Load to $t3 the x-coordinate of the block
		bgt 	$s1, $t1, get_max_x_continue	# Compare max_x to $t3, branch when max_x is greater (no change in max_x)
		move 	$s1, $t1		# max_x = block[1]
		get_max_x_continue:
		addi 	$t0, $t0, 2	# Increment addr[block] by 2 to move to next coordinate
		addi 	$s2, $s2, 1	# Increment counter
		j 	get_max_x_of_piece_loop
	end_get_max_x_of_piece:
	move 	$v0, $s1	# Return max_x
	####end####
	lw 	$ra, 28($sp)
	lw 	$s0, 24($sp)
	lw 	$s1, 20($sp)
	lw 	$s2, 16($sp)
	addi 	$sp, $sp, 32
	####end#### 
	jr 	$ra

deepcopy:
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$ra, 28($sp)
	sw 	grid, 24($sp)	
	sw 	gridCopy, 20($sp)	
	sw 	$s2, 16($sp)	
	####preamble####
	move 	grid, $a0	# $s0 = addr[grid]
	move	$t0, grid	# $t0 = $s0 for manipulating in function
	addi 	$a0, $0, 80	# Allocate 80 bytes for copying grid
	do_syscall(9)		# Syscall 9 for allocating bytes to heap
	
	# $v0 contains the address pointing to the start of gridCopy
	move 	gridCopy, $v0	# $s1 = addr[gridCopy]
	move	$t1, gridCopy	# $t1 = $s1 for manipulating in function
	addi 	$s2, $0, 0	# i = 0
	deepcopy_loop:
		beq 	$s2, 20, exit_deepcopy	# Exit when i = 20
		lw 	$t2, 0($t0)		# Get word from original grid and store in $t3
		sw 	$t2, 0($t1)		# Store the word in gridCopy
		addi 	$t0, $t0, 4	# Increment addr[grid] by 4 for word alignment
		addi 	$t1, $t1, 4	# Increment addr[gridCopy] by 4 for word alignment
		addi 	$s2, $s2, 1	# Increment loop counter by 1
		j 	deepcopy_loop
	exit_deepcopy:
	move 	$v0, gridCopy		# $v0 = address pointing to the start of gridCopy
	####end####
	lw 	$ra, 28($sp)
	lw 	grid, 24($sp)	
	lw 	gridCopy, 20($sp)	
	lw 	$s2, 16($sp)
	addi 	$sp, $sp, 32
	####end####
	jr 	$ra

freeze_blocks:
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$ra, 28($sp)
	sw 	grid, 24($sp)
	sw	$s1, 20($sp)
	sw 	$s2, 16($sp)
	####preamble####
	move 	grid, $a0		# grid = $a0
	move 	$t0, grid		# $t0 = addr[grid]
	addi 	$s1, $0, 0		# i = 0
	freeze_blocks_outer:
		beq 	$s1, 10, exit_freeze_blocks	# Exit when i = 10
		addi 	$s2, $0, 0			# j = 0
		freeze_blocks_inner:
			beq 	$s2, 6, exit_freeze_blocks_inner
			sll 	$t1, $s1, 3	# 8i
			add 	$t1, $t1, $s2	# 8i + j
			add 	$t0, $t0, $t1	# Get address of grid[i][j]
			lb 	$t2, 0($t0)	# $t2 = grid[i][j]
			seq 	$t2, $t2, hashtag	# grid[i][j] == '#'?
			beq 	$t2, 0, fb_not_hash	# Continue looping if grid[i][j] != '#'
			addi 	$t2, $0, X	# $t2 = 'X'
			sb 	$t2, 0($t0)	# grid[i][j] = 'X'
			fb_not_hash:
			move 	$t0, grid	# Restore addr[grid] to $t0
			addi 	$s2, $s2, 1	# Increment j
			j 	freeze_blocks_inner
		exit_freeze_blocks_inner:
		addi 	$s1, $s1, 1	# Increment i
		j 	freeze_blocks_outer
	exit_freeze_blocks:
	move 	$v0, grid		# $v0 = addr[grid]
	####end####
	lw 	$ra, 28($sp)
	lw 	grid, 24($sp)
	lw	$s1, 20($sp)
	lw 	$s2, 16($sp)
	addi 	$sp, $sp, 32
	####end####
	jr 	$ra
	
drop_piece_in_grid:
	####preamble####
	addi 	$sp, $sp, -44
	sw 	$ra, 40($sp)
	sw 	grid, 36($sp)
	sw 	gridCopy, 32($sp)
	sw	piece, 28($sp)
	sw	$s3, 24($sp)
	sw	$s4, 20($sp)
	sw	$s5, 16($sp)
	sw	$s6, 12($sp)
	####preamble####
	move 	grid, $a0		# grid = $a0
	jal 	deepcopy		# gridCopy = deepcopy(grid)
	move 	gridCopy, $v0		# store address from $v0 to gridCopy
	move 	$t0, gridCopy		# $t0 holds address of gridCopy for manipulating
	move	piece, $a1		# piece = $a1
	move 	$t1, piece		# $t1 holds address of piece for manipulating
	move 	$s3, $a2		# $s3 holds xOffset	
	addi 	$s4, $0, 0		# block = 0
	drop_piece_in_grid_block_loop:
		beq 	$s4, 4, exit_block_loop	# Exit when block = 4
		lb 	$t2, 0($t1)		# $t2 = block[0]
		sll 	$t2, $t2, 3		# $t2 = 8 * block[0]
		add 	$t0, $t0, $t2		# $t0 = gridCopy[block[0]]
		lb 	$t2, 1($t1)		# $t2 = block[1]
		add 	$t2, $t2, $s3		# $t2 = block[1] + xOffset
		add 	$t0, $t0, $t2		# $t0 = gridCopy[block[0]][block[1] + xOffset]
		addi 	$t2, $0, hashtag	# $t2 = ASCII value of '#'
		sb 	$t2, 0($t0)		# gridCopy[block[0]][block[1] + xOffset] = '#'
		addi 	$t1, $t1, 2		# Move to next set of coordinates
		addi 	$s4, $s4, 1		# Increment block by 1
		move 	$t0, gridCopy		# $t1 = Restore value of addr[gridCopy]
		j drop_piece_in_grid_block_loop	# Loop back
	exit_block_loop:
	move 	$t0, gridCopy		# $t1 = Restore value of addr[gridCopy]
	addi 	$s4, $0, 1		# canStillGoDown = True
	addi 	$s5, $0, 0		# i = 0
	drop_piece_for_loop_while:
		beq 	$s5, 10, exit_drop_piece_for_loop_while		# Exit when i = 10
		addi 	$s6, $0, 0					# j = 0
		drop_piece_for_loop_while_inner:
			beq 	$s6, 6, exit_for_loop_inner		# Exit when j = 6
			sll 	$t2, $s5, 3	# 8i
			add 	$t2, $t2, $s6	# 8i + j
			add 	$t0, $t0, $t2	# gridCopy[i][j]
			lb 	$t2, 0($t0)	# $t2 <- gridCopy[i][j]  
			seq 	$t2, $t2, hashtag	# Check if gridCopy[i][j] == '#
			addi 	$t3, $s5, 1	# $t3 = i + 1
			seq 	$t3, $t3, 10	# Check if i + 1 == 10
			lb 	$t4, 8($t0)	# $t4 <- gridCopy[i+1][j]
			seq 	$t4, $t4, X	# Check if gridCopy[i + 1][j] == 'X'
			or 	$t3, $t3, $t4	# i + 1 == 10 or gridCopy[i + 1][j] == 'X'
			and 	$t2, $t2, $t3	# gridCopy[i][j] == '#' and (i + 1 == 10 or gridCopy[i + 1][j] == 'X')
			beq 	$t2, 0, continue_inner	# If false, continue for loop; otherwise, canStillGoDown = False and continue for loop
			addi 	$s4, $0, 0		# canStillGoDownFalse = False
			#j 	exit_drop_piece_for_loop_while
			continue_inner:
			move 	$t0, gridCopy	# Restore gridCopy to $t0
			addi 	$s6, $s6, 1	# Increment j
			j 	drop_piece_for_loop_while_inner	# Loop back
		exit_for_loop_inner:
			addi 	$s5, $s5, 1	# Increment i
			j 	drop_piece_for_loop_while
	exit_drop_piece_for_loop_while:
	move 	$t0, gridCopy	# Restore gridCopy to $t0
	beq 	$s4, $0, break_out_of_while	# if canStillGoDown == False, break
	addi 	$s5, $0, 8			# i = 8
	if_canStillGoDown_loop:	# for i in range(8, -1, -1)
		beq 	$s5, -1, exit_ifCanStillGoDown	# Exit when i = -1
		addi 	$s6, $0, 0		# j = 0
		if_canStillGoDown_loop_inner:	# for j in range(6)
			beq 	$s6, 6, exit_ifCanStillGoDown_inner	# Exit when j = 6
			sll 	$t2, $s5, 3	# 8i
			add 	$t2, $t2, $s6	# 8i + j
			add 	$t0, $t0, $t2	# address of gridCopy[i][j]
			lb 	$t2, 0($t0)	# $t2 <- gridCopy[i][j]
			seq 	$t2, $t2, hashtag	# if gridCopy[i][j] == '#'
			beq 	$t2, $0, continue_cSGD_inner # branch if gridCopy[i][j] != '#'
			addi 	$t2, $0, hashtag	# $t2 = '#'
			sb 	$t2, 8($t0)	# gridCopy[i+1][j] = '#'
			addi 	$t2, $0, dot	# $t2 = '.'
			sb 	$t2, 0($t0)	# gridCopy[i][j] = '.'
			continue_cSGD_inner:
			move 	$t0, gridCopy	# restore addr[gridCopy] to $t0
			addi 	$s6, $s6, 1	# Increment j
			j 	if_canStillGoDown_loop_inner
		exit_ifCanStillGoDown_inner:
		addi 	$s5, $s5, -1		# Decrement i by 1
		j 	if_canStillGoDown_loop
	exit_ifCanStillGoDown:
	j 	exit_block_loop			# Keep looping while True
	break_out_of_while:
	move 	$t0, gridCopy	# Restore gridCopy to $t0
	addi 	$s4, $0, 100		# maxY = 100
	addi 	$s5, $0, 0		# i = 0
	maxY_loop:
		beq 	$s5, 10, exit_maxY_loop		# Exit when i = 10
		addi 	$s6, $0, 0			# j = 0
		maxY_loop_inner:
			beq 	$s6, 6, exit_maxY_loop_inner	# Exit when j = 6
			sll 	$t2, $s5, 3	# 8i
			add 	$t2, $t2, $s6	# 8i + j
			add 	$t0, $t0, $t2	# Get address of gridCopy[i][j]
			lb 	$t2, 0($t0)	# $t2 <- gridCopy[i][j]
			seq 	$t2, $t2, hashtag	# gridCopy[i][j] == '#'
			beq 	$t2, 0, continue_maxY_loop_inner
			blt 	$s4, $s5, continue_maxY_loop_inner	# if maxY > i, maxY = i
			move 	$s4, $s5	# maxY = i
			continue_maxY_loop_inner:
			move 	$t0, gridCopy	# Restore addr[gridCopy] to $t0
			addi 	$s6, $s6, 1	# Increment j
			j 	maxY_loop_inner
		exit_maxY_loop_inner:
		addi 	$s5, $s5, 1		# Increment i
		j 	maxY_loop
	exit_maxY_loop:	# $t2 = maxY
	bgt 	$s4, 3, return_freeze_blocks	# if maxY <= 3, return grid, False
	move 	$v0, grid			# $v0 = addr[grid]
	addi 	$v1, $0, 0			# $v1 = False
	j 	end_drop_piece_in_grid
	
	return_freeze_blocks:		# if maxY > 3, return freeze_blocks(gridCopy), true
	move 	$a0, gridCopy		# $a0 = gridCopy
	jal 	freeze_blocks		# $v0 = addr[freeze_blocks(gridCopy)]
	addi 	$v1, $0, 1			# $v1 = True
	end_drop_piece_in_grid:
	####end####
	lw 	$ra, 40($sp)
	lw 	grid, 36($sp)
	lw 	gridCopy, 32($sp)
	lw	piece, 28($sp)
	lw	$s3, 24($sp)
	lw	$s4, 20($sp)
	lw	$s5, 16($sp)
	lw	$s6, 12($sp)
	addi 	$sp, $sp, 44
	####end####
	jr $ra
	
backtrack:	# Start exhaustively searching if final_grid is possible from start_grid and input pieces
	####preamble####
	addi 	$sp, $sp, -48
	sw 	$ra, 44($sp)
	sw 	currGrid, 40($sp)
	sw	pieces, 36($sp)
	sw	i, 32($sp)
	sw	$s3, 28($sp)
	sw	$s4, 24($sp)
	sw	$s5, 20($sp)
	sw	$s6, 16($sp)
	sw	$s7, 12($sp)
	sw	$t0, 8($sp)
	sw	$t1, 4($sp)
	####preamble####
	move 	currGrid, $a0		# Store addr[$a0] to currGrid
	move 	pieces, $a1		# Store addr[$a1} to pieces
	lw 	$a1, 4($gp)		# Store addr[final_grid] to $a1
	jal 	is_equal_grids
	beq 	$v0, 1, exit_backtrack	# return True
	
	move 	i, $a2		# Store $a2 to i
	lw 	$t0, 8($gp)	# $t0 = numPieces
	bge 	$a2, $t0, backtrack_return_false	# Exit when i >= len(pieces)
	
	move	$s3, pieces		# Store addr[pieces] to $s3
	move 	$t0, i			# $t0 = i
	sll 	$t0, $t0, 3		# $t0 = 8 * i
	add 	$s3, $s3, $t0		# $s3 = pieces[i]
	move 	$a0, $s3		# Store pieces[i] to $a0
	jal 	get_max_x_of_piece	# $v0 = get_max_x_of_piece(pieces[i])
	move 	$s4, $v0		# max_x_of_piece = get_max_x_of_piece(pieces[i])
	
	addi 	$s5, $0, 0		# offset = 0
	addi 	$s6, $0, 6		# 6
	sub 	$s6, $s6, $s4		# 6 - max_x_of_piece
	addi 	$s7, $0, 0		# unsuccessful = 0
	backtrack_loop:	# for offset in range(6 - max_x_of_piece)
		beq 	$s5, $s6, backtrack_return_false	# Exit if offset == 6 - max_x_of_piece
		move 	$a0, currGrid	# $a0 = currGrid
		move 	$a1, $s3	# $a1 = pieces[i]
		move 	$a2, $s5	# $a2 = offset
		jal 	drop_piece_in_grid	# nextGrid, success = drop_piece_in_grid(currGrid, pieces[i], offset)
		move 	$t0, $v0	# Move nextGrid to $t0
		move 	$t1, $v1	# Move success to $t1
		move	$a0, $t0	# Move nextGrid to $a0
		jal	line_clearing	# line_clearing(nextGrid)
		move	$t0, $v0	# Move $v0 to $t0
		beq 	$t1, 0, else_not_success	
		move 	$a0, $t0	# $a0 = nextGrid
		move 	$a1, pieces	# $a1 = pieces
		addi 	$a2, i, 1	# $a2 = i + 1
		jal 	backtrack	# backtrack(nextGrid, pieces, i + 1)
		beq 	$v0, 1, exit_backtrack	# Return True
		j 	backtrack_loop_increment
		else_not_success:
		addi 	$t2, $s6, -1	# 6 - max_x_of_piece - 1
		bne 	$s7, $t2, increment_unsuccessful	# Proceed if (unsuccessful == 6 - max_x_of_piece - 1)
		move 	$a0, $t0 	# $a0 = nextGrid
		move 	$a1, pieces	# $a1 = pieces
		addi 	$a2, i, 1	# $a2 = i + 1
		jal 	backtrack		# backtrack(nextGrid, pieces, i + 1)
		beq 	$v0, 1, exit_backtrack	# Return True
		increment_unsuccessful:
		addi 	$s7, $s7, 1	# Increment unsuccessful by 1
		backtrack_loop_increment:
		addi 	$s5, $s5, 1	# Increment offset
		j 	backtrack_loop
	backtrack_return_false:
		addi 	$v0, $0, 0	# Return false
	exit_backtrack:
	####end####
	lw 	$ra, 44($sp)
	lw 	currGrid, 40($sp)
	lw	pieces, 36($sp)
	lw	i, 32($sp)
	lw	$s3, 28($sp)
	lw	$s4, 24($sp)
	lw	$s5, 20($sp)
	lw	$s6, 16($sp)
	lw	$s7, 12($sp)
	lw	$t0, 8($sp)
	lw	$t1, 4($sp)
	addi 	$sp, $sp, 48
	####end#### 
	jr 	$ra

line_clearing:
	####preamble####
	addi 	$sp, $sp, -32
	sw 	$ra, 28($sp)
	sw	nextGrid, 24($sp)
	sw	$s1, 20($sp)
	sw	$s2, 16($sp)
	sw	$s3, 12($sp)
	####preamble####
	move 	nextGrid, $a0	# nextGrid = $a0
	move	$t0, nextGrid	# $t0 = nextGrid for use in function
	addi	$s1, $0, 9	# $s1 = i = 9
	line_clearing_i:
		beq 	$s1, 3, exit_line_clearing	# Exit when i = 3
	check_if_clearable:
		addi	$s2, $0, 1	# $s2 = Check if line can be cleared
		addi	$s3, $0, 0	# $s3 = j
		line_clearing_j:
			beq 	$s3, 6, exit_lc_j	# Exit when j = 6
			sll	$t1, $s1, 3		# 8i
			add	$t1, $t1, $s3		# 8i + j
			add	$t0, $t0, $t1		# nextGrid[i][j]
			lb	$t1, 0($t0)		# $t1 = nextGrid[i][j]
			seq	$t1, $t1, dot		# nextGrid[i][j] == '.'? If yes, don't clear
			beq	$t1, 0, continue_lc_j	# nextGrid[i][j] != '.', continue looping
			addi	$s2, $0, 0		# $s2 = Line can't be cleared
			move 	$t0, nextGrid		# Restore address of nextGrid to $t0
			j exit_lc_j			# Exit the loop
			continue_lc_j:
			addi	$s3, $s3, 1		# Increment j
			move 	$t0, nextGrid		# Restore address of nextGrid to $t0
			j 	line_clearing_j
		exit_lc_j:
		beq	$s2, 1, shift_rows	# If line can be cleared, shift rows downwards
		addi 	$s1, $s1, -1		# Decrement i
		j 	line_clearing_i
		shift_rows:
		move	$t0, nextGrid
		addi 	$t2, $s1, 0	# $t2 = $s1 = x
		shift_rows_out:
			beq 	$t2, 3, check_if_clearable	# Exit when x = 3
			addi	$t3, $0, 0	# $t3 = y
			shift_rows_inner:
				beq 	$t3, 6, exit_sri	# Exit when y = 6
				addi	$t4, $t2, -1	# x-1
				sll 	$t4, $t4, 3	# 8(x-1)
				add 	$t4, $t4, $t3	# 8(x-1) + y
				add	$t0, $t0, $t4	# address of nextGrid[x-1][y]
				lb	$t4, 0($t0)	# $t4 = nextGrid[x-1][y]
				sb	$t4, 8($t0)	# nextGrid[x][y] = $t4
				move	$t0, nextGrid	# Restore address of nextGrid to $t0
				addi	$t3, $t3, 1	# Increment y by 1
				j 	shift_rows_inner
			exit_sri:
			addi	$t2, $t2, -1	# Decrement x
			j 	shift_rows_out
	exit_line_clearing:	
	move	$v0, nextGrid
	####end####
	lw 	$ra, 28($sp)
	lw	nextGrid, 24($sp)
	lw	$s1, 20($sp)
	lw	$s2, 16($sp)
	lw	$s3, 12($sp)
	addi 	$sp, $sp, 32
	####end####
	jr 	$ra
