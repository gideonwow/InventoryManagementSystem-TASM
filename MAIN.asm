; =============================================================================
; Inventory Management System
; Written in TASM Assembly for x86
; =============================================================================

.MODEL SMALL
.STACK 100h

.DATA
    ; =========================================================================
    ; Menu and UI Strings
    ; =========================================================================
    myName      DB "=== Gideon Ran ===", 0Dh, 0Ah, "$"
    welcomeMsg  DB "===|||=== WELCOME TO INVENTORY MANAGEMENT SYSTEM ===|||===", 0Dh, 0Ah, "$"
    menuTitle   DB "=== MAIN MENU ===", 0Dh, 0Ah, "$"
    menu1       DB "1. View All Items", 0Dh, 0Ah, "$"
    menu2       DB "2. View Items by Low Stock", 0Dh, 0Ah, "$"
    menu3       DB "3. Add Quantity", 0Dh, 0Ah, "$"
    menu4       DB "4. Subtract Quantity", 0Dh, 0Ah, "$"
    menu5       DB "5. Calculate Current Total Quantity", 0Dh, 0Ah, "$"
    menu0       DB "0. Exit Program", 0Dh, 0Ah, "$"
    menuPrompt  DB "Enter your choice: $"
    
    ; Table display formatting
    headerLine  DB "--------------------------------------", 0Dh, 0Ah, "$"
    headerText  DB "ID      Name    Quantity        Price", 0Dh, 0Ah, "$"
    
    ; User prompts and messages
    idPrompt    DB "Enter Item ID: $"
    qtyPrompt   DB "Enter Quantity (1-8): $"
    notFoundMsg DB "==||== Item ID not found! ==||== Press any key to continue...", 0Dh, 0Ah, "$"
    invalidQtyMsg DB "==||== Invalid quantity! ==||== Press any key to continue...", 0Dh, 0Ah, "$"
    lowStockMsg DB "Showing items with stock lower than 15:", 0Dh, 0Ah, "$"
    continueMsg DB "Press any key to continue...$"
    
    ; Operation confirmation messages
    qtyAddedMsg DB "==||== Quantity is added! ==||== Press any key to continue...", 0Dh, 0Ah, "$"
    qtySubtractedMsg DB "==||== Quantity is subtracted! ==||== Press any key to continue...", 0Dh, 0Ah, "$"
    
    ; Total quantity display
    totalQtyHeader DB "=== TOTAL INVENTORY QUANTITY ===", 0Dh, 0Ah, "$"
    totalQtyMsg    DB "Total quantity across all items: $"
    
    ; =========================================================================
    ; Variables for user input and program state
    ; =========================================================================
    choiceInput DB ?    ; Stores user's menu selection
    itemID      DB ?    ; Stores selected item ID
    quantity    DB ?    ; Stores quantity to add/subtract
    
    ; 16-bit variable to hold sum of all quantities
    totalQty    DW ?
    
    ; =========================================================================
    ; Inventory Data Structure
    ; =========================================================================
    ; Each item structure: ID(1), Name(8), Quantity(1), Price(1) = 11 bytes total
    items       DB 0, "Pencil  ", 250, 1
                DB 1, "Pen     ", 75, 4
                DB 2, "USB     ", 5, 6
                DB 3, "Chair   ", 10, 85
                DB 4, "Marker  ", 72, 1
                DB 5, "Desk    ", 10, 22
    
    itemCount   DB 6    ; Number of items in the inventory
    itemSize    DB 11   ; Size of each item record in bytes
    
    ; Buffer for number conversion operations
    numBuffer   DB 5 DUP(?)
    
.CODE
MAIN PROC
    ; Initialize data segment register
    MOV AX, @data
    MOV DS, AX
    
    JMP MainMenu     ; Skip function definitions and go to main program flow
    
; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

; -----------------------------------------------------------------------------
; DisplayItem: Displays a single inventory item at offset SI
; Input: SI - Offset into items array for the item to display
; Output: None, displays item data on screen
; -----------------------------------------------------------------------------
DisplayItem:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    
    ; Display ID field
    MOV AL, [items+SI]
    ADD AL, '0'     ; Convert number to ASCII character
    MOV DL, AL
    MOV AH, 02h     ; DOS function: display character
    INT 21h
    
    ; Display tab separator
    MOV DL, 09h     ; Tab character
    MOV AH, 02h
    INT 21h
    
    ; Display name field (8 characters)
    MOV CX, 8       ; Loop counter for 8 characters
    ADD SI, 1       ; Point to name field (offset 1)
    
DisplayNameLoop:
    MOV DL, [items+SI]
    MOV AH, 02h
    INT 21h
    INC SI
    LOOP DisplayNameLoop
    
    ; Display tab separator
    MOV DL, 09h
    MOV AH, 02h
    INT 21h
    
    ; Display quantity field
    MOV AL, [items+SI]
    CALL PrintNumber
    
    ; Display tab separator
    MOV DL, 09h
    MOV AH, 02h
    INT 21h
    
    ; Display price field
    INC SI          ; Point to price field
    MOV AL, [items+SI]
    CALL PrintNumber
    
    ; End line
    CALL NewLine
    
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

; -----------------------------------------------------------------------------
; PrintNumber: Prints a byte value in decimal format
; Input: AL - 8-bit value to print
; Output: None, displays number on screen
; -----------------------------------------------------------------------------
PrintNumber:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    MOV AH, 0       ; Clear AH for division
    MOV BL, 10      ; Divisor = 10 (for decimal conversion)
    MOV CX, 0       ; Counter for number of digits
    
    ; Special case: handle zero value
    CMP AL, 0
    JNE ConvertLoop
    
    MOV DL, '0'     ; Just print '0' character
    MOV AH, 02h
    INT 21h
    JMP EndPrintNumber
    
ConvertLoop:
    ; Check if conversion complete
    CMP AL, 0
    JE PrintLoop
    
    ; Divide by 10 to get next digit
    DIV BL          ; AX/BL = AL remainder AH
    MOV BH, AH      ; Save remainder (current digit)
    MOV AH, 0       ; Clear for next division
    
    ; Push digit onto stack (LIFO order gives correct display)
    PUSH BX
    INC CX          ; Count digits
    
    JMP ConvertLoop
    
PrintLoop:
    ; Check if all digits printed
    CMP CX, 0
    JE EndPrintNumber
    
    ; Pop digit from stack
    POP BX
    
    ; Print digit as ASCII character
    MOV DL, BH      ; Get digit value
    ADD DL, '0'     ; Convert to ASCII
    MOV AH, 02h
    INT 21h
    
    DEC CX          ; Decrement counter
    JMP PrintLoop
    
EndPrintNumber:
    POP DX
    POP CX
    POP BX
    POP AX
    RET

; -----------------------------------------------------------------------------
; PrintNumberWord: Prints a 16-bit value in decimal format
; Input: AX - 16-bit value to print
; Output: None, displays number on screen
; -----------------------------------------------------------------------------
PrintNumberWord:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    MOV BX, 10      ; Divisor = 10 (for decimal conversion)
    MOV CX, 0       ; Counter for number of digits
    
    ; Special case: handle zero value
    CMP AX, 0
    JNE WordConvertLoop
    
    MOV DL, '0'     ; Just print '0' character
    MOV AH, 02h
    INT 21h
    JMP EndPrintNumberWord
    
WordConvertLoop:
    ; Check if conversion complete
    CMP AX, 0
    JE WordPrintLoop
    
    ; Divide by 10 to get next digit
    XOR DX, DX      ; Clear DX for division (DX:AX / BX)
    DIV BX          ; Result in AX, remainder in DX
    
    ; Push digit onto stack (LIFO order gives correct display)
    PUSH DX
    INC CX          ; Count digits
    
    JMP WordConvertLoop
    
WordPrintLoop:
    ; Check if all digits printed
    CMP CX, 0
    JE EndPrintNumberWord
    
    ; Pop digit from stack
    POP DX
    
    ; Print digit as ASCII character
    ADD DL, '0'     ; Convert to ASCII
    MOV AH, 02h
    INT 21h
    
    DEC CX          ; Decrement counter
    JMP WordPrintLoop
    
EndPrintNumberWord:
    POP DX
    POP CX
    POP BX
    POP AX
    RET

; -----------------------------------------------------------------------------
; PrintString: Displays a string terminated with '$'
; Input: DX - Address of string
; Output: None, displays string on screen
; -----------------------------------------------------------------------------
PrintString:
    PUSH AX
    MOV AH, 09h     ; DOS function: display string
    INT 21h
    POP AX
    RET

; -----------------------------------------------------------------------------
; NewLine: Prints a carriage return and line feed
; Input: None
; Output: None, moves cursor to beginning of next line
; -----------------------------------------------------------------------------
NewLine:
    PUSH AX
    PUSH DX
    
    MOV DL, 0Dh     ; Carriage return
    MOV AH, 02h
    INT 21h
    
    MOV DL, 0Ah     ; Line feed
    MOV AH, 02h
    INT 21h
    
    POP DX
    POP AX
    RET

; -----------------------------------------------------------------------------
; GetChar: Gets a single character from keyboard
; Input: None
; Output: AL - ASCII character
; -----------------------------------------------------------------------------
GetChar:
    MOV AH, 01h     ; DOS function: read keyboard
    INT 21h
    RET

; =============================================================================
; MAIN MENU AND PROGRAM FLOW
; =============================================================================

; -----------------------------------------------------------------------------
; MainMenu: Displays the main menu and processes user selection
; -----------------------------------------------------------------------------
MainMenu:
    ; Clear screen for clean display
    MOV AX, 0600h    ; BIOS scroll function (clear)
    MOV BH, 07h      ; Normal attributes (white on black)
    MOV CX, 0000h    ; Upper left corner (0,0)
    MOV DX, 184Fh    ; Lower right corner (24,79)
    INT 10h
    
    ; Reset cursor to top of screen
    MOV AH, 02h
    MOV BH, 00h
    MOV DX, 0000h
    INT 10h
    
    ; Display menu header and options
    LEA DX, myName
    CALL PrintString
    
    LEA DX, welcomeMsg
    CALL PrintString
    
    LEA DX, menuTitle
    CALL PrintString
    
    LEA DX, menu1
    CALL PrintString
    
    LEA DX, menu2
    CALL PrintString
    
    LEA DX, menu3
    CALL PrintString
    
    LEA DX, menu4
    CALL PrintString
    
    LEA DX, menu5
    CALL PrintString
    
    LEA DX, menu0
    CALL PrintString
    
    ; Prompt for user selection
    LEA DX, menuPrompt
    CALL PrintString
    
    ; Get user choice
    CALL GetChar
    MOV choiceInput, AL
    CALL NewLine
    
    ; Process menu selection
    CMP choiceInput, '0'
    JE ExitProgram
    
    CMP choiceInput, '1'
    JE OptionViewAllItems
    
    CMP choiceInput, '2'
    JE OptionViewLowStock
    
    CMP choiceInput, '3'
    JE OptionAddQuantity
    
    CMP choiceInput, '4'
    JE OptionSubtractQuantity
    
    CMP choiceInput, '5'
    JE OptionCalculateTotalQuantity
    
    ; Invalid option - return to menu
    JMP MainMenu

; Menu option handlers - using shorter jumps to proper functions
OptionViewAllItems:
    JMP ViewAllItems
    
OptionViewLowStock:
    JMP ViewLowStock
    
OptionAddQuantity:
    JMP AddQuantity
    
OptionSubtractQuantity:
    JMP SubtractQuantity
    
OptionCalculateTotalQuantity:
    JMP CalculateTotalQuantity

; -----------------------------------------------------------------------------
; ExitProgram: Terminates the program
; -----------------------------------------------------------------------------
ExitProgram:
    MOV AH, 4Ch     ; DOS function: terminate program
    INT 21h

; =============================================================================
; FEATURE IMPLEMENTATIONS
; =============================================================================

; -----------------------------------------------------------------------------
; ViewAllItems: Displays all items in the inventory
; -----------------------------------------------------------------------------
ViewAllItems:
    ; Display header for item list
    LEA DX, headerLine
    CALL PrintString
    
    LEA DX, headerText
    CALL PrintString
    
    ; Initialize for item iteration
    XOR SI, SI      ; SI = 0 (start at first item)
    MOV CL, 0       ; CL = Item counter
    
DisplayAllLoop:
    ; Check if we've displayed all items
    MOV AL, CL
    CMP AL, itemCount
    JAE EndDisplayAll
    
    ; Calculate item address: items + CL * itemSize
    MOV AL, CL
    MUL itemSize    ; AX = AL * itemSize
    MOV SI, AX      ; SI = offset to current item
    
    ; Display the current item
    CALL DisplayItem
    
    ; Move to next item
    INC CL
    JMP DisplayAllLoop
    
EndDisplayAll:
    ; Wait for user input before returning to menu
    LEA DX, continueMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu

; -----------------------------------------------------------------------------
; ViewLowStock: Displays items with quantity less than 15
; -----------------------------------------------------------------------------
ViewLowStock:
    ; Display header for low stock items
    LEA DX, headerLine
    CALL PrintString
    
    LEA DX, lowStockMsg
    CALL PrintString
    
    LEA DX, headerText
    CALL PrintString
    
    ; Initialize for item iteration
    XOR SI, SI      ; SI = 0 (start at first item)
    MOV CL, 0       ; CL = Item counter
    
DisplayLowStockLoop:
    ; Check if we've processed all items
    MOV AL, CL
    CMP AL, itemCount
    JAE EndDisplayLowStock
    
    ; Calculate item address: items + CL * itemSize
    MOV AL, CL
    MUL itemSize    ; AX = AL * itemSize
    MOV SI, AX      ; SI = offset to current item
    
    ; Check if quantity is less than 15 (low stock threshold)
    ADD SI, 9       ; Point to quantity field (offset 9)
    MOV AL, [items+SI]
    CMP AL, 15
    JAE SkipItemLowStock    ; Skip if quantity >= 15
    
    ; Reset SI to start of item and display it
    SUB SI, 9       ; Reset to item start
    CALL DisplayItem
    
SkipItemLowStock:
    ; Move to next item
    INC CL
    JMP DisplayLowStockLoop
    
EndDisplayLowStock:
    ; Wait for user input before returning to menu
    LEA DX, continueMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu

; -----------------------------------------------------------------------------
; CalculateTotalQuantity: Sums and displays total inventory quantity
; -----------------------------------------------------------------------------
CalculateTotalQuantity:
    ; Clear screen for clean display
    MOV AX, 0600h    ; BIOS scroll function (clear)
    MOV BH, 07h      ; Normal attributes (white on black)
    MOV CX, 0000h    ; Upper left corner (0,0)
    MOV DX, 184Fh    ; Lower right corner (24,79)
    INT 10h
    
    ; Reset cursor to top of screen
    MOV AH, 02h
    MOV BH, 00h
    MOV DX, 0000h
    INT 10h
    
    ; Display headers
    LEA DX, totalQtyHeader
    CALL PrintString
    
    LEA DX, headerLine
    CALL PrintString
    
    ; Initialize for calculation
    XOR SI, SI      ; SI = 0
    MOV CL, 0       ; CL = Item counter
    MOV totalQty, 0 ; Reset total quantity
    
CalcTotalLoop:
    ; Check if we've processed all items
    MOV AL, CL
    CMP AL, itemCount
    JAE EndCalcTotal
    
    ; Calculate item address and point to quantity field
    MOV AL, CL
    MUL itemSize    ; AX = AL * itemSize
    MOV SI, AX      ; SI = offset to current item
    ADD SI, 9       ; Point to quantity field (offset 9)
    
    ; Add this item's quantity to running total
    XOR AH, AH      ; Clear high byte for addition
    MOV AL, [items+SI]  ; Get item quantity
    ADD totalQty, AX    ; Add to total (16-bit addition)
    
    ; Move to next item
    INC CL
    JMP CalcTotalLoop
    
EndCalcTotal:
    ; Display the calculated total
    LEA DX, totalQtyMsg
    CALL PrintString
    
    MOV AX, totalQty    ; Load total for display
    CALL PrintNumberWord
    
    CALL NewLine
    CALL NewLine
    
    ; Wait for user input before returning to menu
    LEA DX, continueMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu

; -----------------------------------------------------------------------------
; AddQuantity: Increases item quantity by user-specified amount
; -----------------------------------------------------------------------------
AddQuantity:
    ; Prompt for item ID
    LEA DX, idPrompt
    CALL PrintString
    
    ; Get and convert item ID input
    CALL GetChar
    SUB AL, '0'     ; Convert ASCII to numeric value
    MOV itemID, AL
    CALL NewLine
    
    ; Validate item ID is within range
    CMP AL, itemCount
    JNB InvalidID   ; Jump if ID >= itemCount (invalid)
    
    ; Prompt for quantity to add
    LEA DX, qtyPrompt
    CALL PrintString
    
    ; Get and convert quantity input
    CALL GetChar
    SUB AL, '0'     ; Convert ASCII to numeric value
    MOV quantity, AL
    CALL NewLine
    
    ; Validate quantity is between 1-8
    CMP AL, 1
    JB InvalidQuantity   ; Jump if < 1
    CMP AL, 8
    JA InvalidQuantity   ; Jump if > 8
    
    ; Calculate address of item's quantity field
    MOV AL, itemID
    MUL itemSize    ; AX = AL * itemSize
    MOV SI, AX      ; SI = offset to item
    ADD SI, 9       ; Point to quantity field (offset 9)
    
    ; Add quantity to item
    MOV AL, [items+SI]
    ADD AL, quantity    ; Add specified quantity
    MOV [items+SI], AL  ; Update item's quantity
    
    ; Display confirmation message
    LEA DX, qtyAddedMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu
    
InvalidID:
    ; Display error for invalid item ID
    LEA DX, notFoundMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu

InvalidQuantity:
    ; Display error for invalid quantity
    LEA DX, invalidQtyMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu

; -----------------------------------------------------------------------------
; SubtractQuantity: Decreases item quantty by user-specified amount
; -----------------------------------------------------------------------------
SubtractQuantity:
    ; Prompt for item ID
    LEA DX, idPrompt
    CALL PrintString
    
    ; Get and convert item ID input
    CALL GetChar
    SUB AL, '0'     ; Convert ASCII to numeric value
    MOV itemID, AL
    CALL NewLine
    
    ; Validate item ID is within range
    CMP AL, itemCount
    JNB SubInvalidID   ; Jump if ID >= itemCount (invalid)
    
    ; Prompt for quantity to subtract
    LEA DX, qtyPrompt
    CALL PrintString
    
    ; Get and convert quantity input
    CALL GetChar
    SUB AL, '0'     ; Convert ASCII to numeric value
    MOV quantity, AL
    CALL NewLine
    
    ; Validate quantity is between 1-8
    CMP AL, 1
    JB SubInvalidQuantity     ; Jump if < 1
    CMP AL, 8
    JA SubInvalidQuantity     ; Jump if > 8
    
    ; Calculate address of item's quantity field
    MOV AL, itemID
    MUL itemSize    ; AX = AL * itemSize
    MOV SI, AX      ; SI = offset to item
    ADD SI, 9       ; Point to quantity field (offset 9)
    
    ; Check if item has sufficient quantity
    MOV AL, [items+SI]
    CMP AL, quantity
    JB SubInvalidQuantity     ; Jump if current quantity < requested quantity
    
    ; Subtract quantity from item
    SUB AL, quantity    ; Subtract specified quantity
    MOV [items+SI], AL  ; Update item's quantity
    
    ; Display confirmation message
    LEA DX, qtySubtractedMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu
    
SubInvalidID:
    ; display error for invalid item ID
    LEA DX, notFoundMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu

SubInvalidQuantity:
    ; Display errorr for invalid quantity or insufficient stock
    LEA DX, invalidQtyMsg
    CALL PrintString
    CALL GetChar
    JMP MainMenu

MAIN ENDP
END MAIN