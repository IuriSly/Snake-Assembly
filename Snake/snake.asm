;
; Created by Iuri Slywitch, the code is free to use and free to copy.
; @authors --> Iuri Slywitch (Slyy)
;
.386
.model flat, stdcall  ; 32 bit memory model
option casemap :none  ; case sensitive

include \masm32\include\windows.inc

include \masm32\include\masm32.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\msimg32.inc

includelib \masm32\lib\masm32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\msimg32.lib

;=================
; Local prototypes
;=================
WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
TopXY PROTO   :DWORD,:DWORD
FillBuffer   PROTO :DWORD,:DWORD,:BYTE
Paint_Proc   PROTO :DWORD,:DWORD
RandomNumber PROTO :DWORD
CheckSnakeOnSquare PROTO :DWORD, :DWORD
CheckFoodOnSquare PROTO :DWORD, :DWORD
GenerateFood PROTO
RestartGame PROTO

szText MACRO Name, Text:VARARG
  LOCAL lbl
    jmp lbl
      Name db Text,0
    lbl:
ENDM

m2m MACRO M1, M2
  push M2
  pop  M1
ENDM

return MACRO arg
  mov eax, arg
  ret
ENDM

.data
    buffer          db 300 dup (?)
    header_placar   db "Length: %d", 0
    header_value   db "Value: %d", 0

    szDisplayName db "Snake by Slyy v2.0",0
    CommandLine   dd 0
    hWnd          dd 0
    hInstance     dd 0

    ThreadID dd 0

    hEventStart  dd 0

    threadControl dd 0

    hBmpBody  dd 0
    hBmpFood  dd 0
    hBmpFoodX dd 0

    pointStructure struct
        x dd ?
        y dd ?
    pointStructure ends

    direction db 0

    snake_length dd 5

    test_value_1 dd 100
    test_value_2 dd 2
    test_value_3 dd 3

    snake pointStructure 400 dup(<0, 0>)

    squares pointStructure 400 dup(<0, 0>)

    foodStructure struct
        x dd ?
        y dd ?
        e dd 0
    foodStructure ends

    food foodStructure 400 dup(<0, 0, 0>)

    food_count dd 1

    rNumber dd 0

    checkSnake dd 0
    checkFood dd 0

    time dd 100

.const
    WM_MOVEMENT equ WM_USER+100h

.code

RandomNumber proc uses eax squares_left:DWORD
        invoke GetTickCount
        invoke nseed, eax
        invoke nrandom, squares_left
        mov rNumber, eax
        ret
RandomNumber endp

CheckFoodOnSquare proc x:DWORD,y:DWORD
        LOCAL count:DWORD

        mov esi, offset food
        mov eax, food_count
        sub eax, 1
        mov ebx, 12
        mul ebx
        add esi, eax

        mov count, 0

        .while TRUE
            mov eax, x
            mov ebx, y

            .if dword ptr[esi] == eax && dword ptr[esi+4] == ebx && dword ptr[esi+8] == 1
                mov checkFood, 1
                jmp endFoodCheck
            .endif

            inc count

            mov eax, food_count

            .if count == eax
                mov checkFood, 0
                jmp endFoodCheck
            .endif

            sub esi, 12
        .endw
        endFoodCheck:

        ret
CheckFoodOnSquare endp

CheckSnakeOnSquare proc x:DWORD,y:DWORD
        LOCAL count:DWORD

        mov esi, offset snake

        mov count, 0

        .while TRUE
            mov eax, x
            mov ebx, y

            .if dword ptr[esi] == eax && dword ptr[esi+4] == ebx
                mov checkSnake, 1
                jmp endSnakeCheck
            .endif

            inc count

            mov eax, snake_length

            .if count == eax
                mov checkSnake, 0
                jmp endSnakeCheck
            .endif

            add esi, 8
        .endw
        endSnakeCheck:

        ret
CheckSnakeOnSquare endp

GenerateFood proc
    LOCAL count:DWORD

    mov count, 0

    mov eax, 400
    sub eax, snake_length

    invoke RandomNumber, eax
    ; rNumber now has the random number
    ; this while will be responsible to find the square which is available for the food

    mov edi, offset squares

    .while TRUE
        invoke CheckSnakeOnSquare, dword ptr[edi], dword ptr[edi+4]

        ; checkSnake now has the answer if there is a snake on the square
        mov eax, checkSnake
        mov ebx, rNumber

        .if eax == 0 && count == ebx
            mov esi, offset food
            mov eax, food_count
            sub eax, 1
            mov ebx, 12
            mul ebx
            add esi, eax

            ; ebx = square(x)
            mov eax, dword ptr[edi]
            ; setting food x
            mov dword ptr[esi], eax

            ; ebx = square(y)
            mov ebx, dword ptr[edi+4]
            ; setting food y
            mov dword ptr[esi+4], ebx

            jmp endFoodSquare
        .elseif eax == 0
            inc count
        .endif

        add edi, 8
    .endw
    endFoodSquare:

    ret
GenerateFood endp

RestartGame proc
    mov test_value_1, 0

    ret
RestartGame endp

start:
    invoke GetModuleHandle, NULL ; provides the instance handle
    mov hInstance, eax

    invoke LoadBitmap, hInstance, 100
    mov hBmpBody, eax

    invoke LoadBitmap, hInstance, 101
    mov hBmpFood, eax

    invoke LoadBitmap, hInstance, 102
    mov hBmpFoodX, eax

    invoke GetCommandLine        ; provides the command line address
    mov CommandLine, eax

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT

    invoke ExitProcess,eax       ; cleanup & return to operating system

; --------------------- WinMain --------------------------
WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

        ;====================
        ; Put LOCALs on stack
        ;====================

        LOCAL wc   :WNDCLASSEX
        LOCAL msg  :MSG

        LOCAL Wwd  :DWORD
        LOCAL Wht  :DWORD
        LOCAL Wtx  :DWORD
        LOCAL Wty  :DWORD

        szText szClassName,"Primeiro_Class"

        ;==================================================
        ; Fill WNDCLASSEX structure with required variables
        ;==================================================

        mov wc.cbSize,         sizeof WNDCLASSEX
        mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                               or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
        mov wc.cbClsExtra,     NULL
        mov wc.cbWndExtra,     NULL
        m2m wc.hInstance,      hInst               ; instance handle
        mov wc.hbrBackground,  COLOR_BTNFACE+4     ; system color
        mov wc.lpszMenuName,   NULL
        mov wc.lpszClassName,  offset szClassName  ; window class name
        invoke LoadIcon, hInst, 500 ; icon ID ; resource icon
        mov wc.hIcon,          eax
        invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
        mov wc.hCursor,        eax
        mov wc.hIconSm,        0

        invoke RegisterClassEx, ADDR wc     ; register the window class

        ;================================
        ; Centre window at following size
        ;================================

        mov Wwd, 520
        mov Wht, 542

        invoke GetSystemMetrics,SM_CXSCREEN ; get screen width in pixels
        invoke TopXY,Wwd,eax
        mov Wtx, eax

        invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
        invoke TopXY,Wht,eax
        mov Wty, eax

        ; ==================================
        ; Create the main application window
        ; ==================================
        invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,
                              ADDR szClassName,
                              ADDR szDisplayName,
                              WS_OVERLAPPEDWINDOW,
                              Wtx,Wty,Wwd,Wht,
                              NULL,NULL,
                              hInst,NULL

        mov   hWnd,eax  ; copy return value into handle DWORD

        invoke LoadMenu,hInst,600                 ; load resource menu
        invoke SetMenu,hWnd,eax                   ; set it to main window

        invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
        invoke UpdateWindow,hWnd                  ; update the display

      ;===================================
      ; Loop until PostQuitMessage is sent
      ;===================================

    StartLoop:
      invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
      cmp eax, 0                                  ; exit if GetMessage()
      je ExitLoop                                 ; returns zero
      invoke TranslateMessage, ADDR msg           ; translate it
      invoke DispatchMessage,  ADDR msg           ; send it to message proc
      jmp StartLoop
    ExitLoop:

      return msg.wParam

WinMain endp

; --------------------- WndProc --------------------------
WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

	LOCAL Ps 	:PAINTSTRUCT
	LOCAL hDC	:DWORD
    LOCAL x:DWORD
    LOCAL y:DWORD
    LOCAL count:DWORD

    .if uMsg == WM_COMMAND

    .elseif uMsg == WM_PAINT

  	    invoke BeginPaint, hWin, ADDR Ps
  	    mov	hDC, eax

        invoke Paint_Proc, hWin, hDC

  	    invoke EndPaint, hWin, ADDR Ps

    .elseif uMsg == WM_CREATE ; This message is sent to WndProc during the CreateWindowEx
        invoke CreateEvent, NULL, FALSE, FALSE, NULL
        mov hEventStart, eax

        mov eax, OFFSET MainThreadProc
        invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR ThreadID
        mov threadControl, eax

        ; setting the initial snake coordinates for the 5 blocks...
        mov esi, offset snake

        mov dword ptr[esi], 100
        mov dword ptr[esi+4], 0
        add esi, 8

        mov dword ptr[esi], 75
        mov dword ptr[esi+4], 0
        add esi, 8

        mov dword ptr[esi], 50
        mov dword ptr[esi+4], 0
        add esi, 8

        mov dword ptr[esi], 25
        mov dword ptr[esi+4], 0
        add esi, 8

        mov dword ptr[esi], 0
        mov dword ptr[esi+4], 0

        ; defining all possible squares in the game
        mov esi, offset squares
        mov count, 0
        
        .while TRUE
            mov eax, count
            mov ebx, 20
            sub edx, edx
            div ebx
            ; eax = count/20
            mov ebx, 20
            mul ebx
            ; eax = (count/20)*20
            mov ebx, count
            sub ebx, eax
            mov eax, ebx
            mov ebx, 25
            mul ebx

            ; setting x
            mov dword ptr[esi], eax

            mov eax, count
            mov ebx, 20
            sub edx, edx
            ; eax = count/20
            div ebx

            mov ebx, 25
            ; eax = (count/20)*25
            mul ebx

            ; setting y
            mov dword ptr[esi+4], eax

            inc count

            .if count == 400
                jmp endSettingSquares
            .endif

            add esi, 8
        .endw
        endSettingSquares:

        ; generating first food
        invoke GenerateFood

    .elseif uMsg == WM_KEYDOWN
        .if wParam == VK_LEFT
            .if direction != 0
                mov direction, 2
            .endif
        .elseif wParam == VK_RIGHT
            .if direction != 2
                mov direction, 0
            .endif
        .elseif wParam == VK_UP
            .if direction != 3
                mov direction, 1
            .endif
        .elseif wParam == VK_DOWN
            .if direction != 1
                mov direction, 3
            .endif
        .elseif wParam == VK_SPACE
            .if time == 100
                mov time, 5000
            .elseif time == 50
                mov time, 25
            .else
                mov time, 100
            .endif
        .elseif wParam == VK_RETURN
        .endif

    .elseif uMsg == WM_MOVEMENT
        mov esi, offset snake
        mov eax, snake_length
        sub eax, 2
        mov ebx, 8
        mul ebx
        add esi, eax
        mov count, 1

        .while TRUE
            mov eax, dword ptr[esi]
            mov ebx, dword ptr[esi+4]

            mov dword ptr[esi+8], eax
            mov dword ptr[esi+12], ebx

            sub esi, 8

            inc count

            mov eax, snake_length

            .if count == eax
                jmp endMove
            .endif
        .endw
        endMove:

        .if direction == 0
            .if dword ptr[snake] == 475
                invoke CheckSnakeOnSquare, 0, dword ptr[snake+4]

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    mov dword ptr[snake], 0
                .endif
            .else
                mov eax, dword ptr[snake]
                add eax, 25

                invoke CheckSnakeOnSquare, eax, dword ptr[snake+4]

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    add dword ptr[snake], 25
                .endif
            .endif
        .elseif direction == 1
            .if dword ptr[snake+4] == 0
                invoke CheckSnakeOnSquare, dword ptr[snake], 475

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    mov dword ptr[snake+4], 475
                .endif
            .else
                mov eax, dword ptr[snake+4]
                sub eax, 25

                invoke CheckSnakeOnSquare, dword ptr[snake], eax

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    sub dword ptr[snake+4], 25
                .endif
            .endif
        .elseif direction == 2
            .if dword ptr[snake] == 0
                invoke CheckSnakeOnSquare, 475, dword ptr[snake+4]

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    mov dword ptr[snake], 475
                .endif
            .else
                mov eax, dword ptr[snake]
                sub eax, 25

                invoke CheckSnakeOnSquare, eax, dword ptr[snake+4]

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    sub dword ptr[snake], 25
                .endif
            .endif
        .elseif direction == 3
            .if dword ptr[snake+4] == 475
                invoke CheckSnakeOnSquare, dword ptr[snake], 0

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    mov dword ptr[snake+4], 0
                .endif
            .else
                mov eax, dword ptr[snake+4]
                add eax, 25

                invoke CheckSnakeOnSquare, dword ptr[snake], eax

                mov eax, checkSnake

                .if eax == 1
                    invoke RestartGame
                .else
                    add dword ptr[snake+4], 25
                .endif
            .endif
        .endif

        ; return the x and y of the last food
        mov esi, offset food
        mov eax, food_count
        sub eax, 1
        mov ebx, 12
        mul ebx
        add esi, eax

        ; last food x
        mov eax, dword ptr[esi]
        ; last food y
        mov ebx, dword ptr[esi+4]

        ; snake head on top of food
        .if dword ptr[snake] == eax && dword ptr[snake+4] == ebx
            mov dword ptr[esi+8], 1

            .if food_count < 395
                ; adding one more food to the game
                inc food_count

                invoke GenerateFood
            .endif
        .endif

        ; check if food reached the tail of the snake
        mov edi, offset snake
        mov eax, snake_length
        sub eax, 1
        mov ebx, 8
        mul ebx
        add edi, eax

        ; snake tail x
        mov eax, dword ptr[edi]
        mov x, eax
        ; snake tail y
        mov ebx, dword ptr[edi+4]
        mov y, ebx

        mov count, 0

        .while TRUE
            mov eax, x
            mov ebx, y

            ; checking if food x and food y is on top of tail
            .if dword ptr[esi] == eax && dword ptr[esi+4] == ebx && dword ptr[esi+8] == 1
                mov dword ptr[esi+8], 2
                
                mov eax, dword ptr[edi]
                mov ebx, dword ptr[edi+4]

                add edi, 8

                ; set coordinates of the tail (last element/block added)
                mov dword ptr[edi], eax
                mov dword ptr[edi+4], ebx

                inc snake_length

                jmp endVerifyingFood
            .endif

            inc count

            mov eax, food_count

            .if count == eax
                jmp endVerifyingFood
            .endif

            .if dword ptr[esi+8] == 2
                jmp endVerifyingFood
            .endif

            sub esi, 12
        .endw
        endVerifyingFood:

        invoke InvalidateRect, hWnd, NULL, TRUE

    .elseif uMsg == WM_CLOSE

    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage,NULL
        return 0
    .endif

    invoke DefWindowProc, hWin, uMsg, wParam, lParam

    ret

WndProc endp

; --------------------- TopXY --------------------------
TopXY proc wDim:DWORD, sDim:DWORD

    ; ----------------------------------------------------
    ; This procedure calculates the top X & Y co-ordinates
    ; for the CreateWindowEx call in the WinMain procedure
    ; ----------------------------------------------------

    shr sDim, 1      ; divide screen dimension by 2
    shr wDim, 1      ; divide window dimension by 2
    mov eax, wDim    ; copy window dimension into eax
    sub sDim, eax    ; sub half win dimension from half screen dimension

    return sDim

TopXY endp

; --------------------- PaintProc --------------------------
Paint_Proc proc hWin:DWORD, hDC:DWORD

	LOCAL hOld:DWORD
	LOCAL memDC:DWORD
    LOCAL count:DWORD

    invoke  CreateCompatibleDC, hDC
    mov	memDC, eax

    mov esi, offset food
    mov count, 0

    .while TRUE
        .if dword ptr[esi+8] == 0
            invoke SelectObject, memDC, hBmpFood
            invoke BitBlt, hDC, dword ptr[esi], dword ptr[esi+4], 25, 25, memDC, 0, 0, SRCCOPY
        .elseif dword ptr[esi+8] == 1
            invoke SelectObject, memDC, hBmpFoodX
            invoke BitBlt, hDC, dword ptr[esi], dword ptr[esi+4], 25, 25, memDC, 0, 0, SRCCOPY
        .endif

        add esi, 12

        inc count

        mov eax, food_count

        .if count == eax
            jmp endPrintFood
        .endif
    .endw
    endPrintFood:

    mov edi, offset snake
    mov count, 0
    
    invoke SelectObject, memDC, hBmpBody

    .while TRUE
        invoke CheckFoodOnSquare, dword ptr[edi], dword ptr[edi+4]

        .if checkFood == 0
            invoke BitBlt, hDC, dword ptr[edi], dword ptr[edi+4], 25, 25, memDC, 0, 0, SRCCOPY
        .endif

        add edi, 8

        inc count

        mov eax, snake_length

        .if count == eax
            jmp endPrintSnake
        .endif
    .endw
    endPrintSnake:

    invoke wsprintfA, ADDR buffer, ADDR header_placar, snake_length
    invoke ExtTextOutA, hDC, 425, 25, ETO_CLIPPED, NULL, ADDR buffer, eax, NULL

    ; invoke wsprintfA, ADDR buffer, ADDR header_value, test_value_1
    ; invoke ExtTextOutA, hDC, 25, 25, ETO_CLIPPED, NULL, ADDR buffer, eax, NULL

    ; invoke wsprintfA, ADDR buffer, ADDR header_value, test_value_2
    ; invoke ExtTextOutA, hDC, 0, 460, ETO_CLIPPED, NULL, ADDR buffer, eax, NULL

    ; invoke wsprintfA, ADDR buffer, ADDR header_value, test_value_3
    ; invoke ExtTextOutA, hDC, 0, 440, ETO_CLIPPED, NULL, ADDR buffer, eax, NULL

	invoke SelectObject, hDC, hOld
	invoke DeleteDC, memDC

	return 0
Paint_Proc endp

; --------------------- MainThread ------------------------
MainThreadProc PROC USES ecx Param:DWORD

    invoke WaitForSingleObject, hEventStart, time

    .if eax == WAIT_TIMEOUT
        invoke PostMessage, hWnd, WM_MOVEMENT, NULL, NULL
        jmp MainThreadProc
    .endif

    ret
MainThreadProc endp

end start
