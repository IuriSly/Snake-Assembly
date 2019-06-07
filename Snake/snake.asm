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
    header_placar   db "Size: %d", 0

    szDisplayName db "Snake by Slyy v1.0",0
    CommandLine   dd 0
    hWnd          dd 0
    hInstance     dd 0

    ThreadID dd 0

    hEventStart  dd 0

    threadControl dd 0

    hBmpBody dd 0
    hBmpFood dd 0

    pointStructure struct
        x dd ?
        y dd ?
    pointStructure ends

    direction db 0

    snake_size dd 5

    snake pointStructure 225 dup(<0, 0>)

    foodStructure struct
        x dd ?
        y dd ?
        e dd 0
    foodStructure ends

    food foodStructure <475, 475, 1>

    rNumber dd 0

.const
    WM_MOVEMENT equ WM_USER+100h

.code

getRandomNumber proc uses eax
        invoke GetTickCount
        invoke nseed, eax
        ; Random number de 0 a 19
        invoke nrandom, 20
        mov rNumber, eax
        ret
getRandomNumber endp

start:
    invoke GetModuleHandle, NULL ; provides the instance handle
    mov hInstance, eax

    invoke LoadBitmap, hInstance, 100
    mov hBmpBody, eax

    invoke LoadBitmap, hInstance, 101
    mov hBmpFood, eax

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

        invoke  Paint_Proc, hWin, hDC

  	    invoke EndPaint, hWin, ADDR Ps

    .elseif uMsg == WM_CREATE ; This message is sent to WndProc during the CreateWindowEx
        invoke CreateEvent, NULL, FALSE, FALSE, NULL
	      mov hEventStart, eax
	      mov eax, OFFSET MainThreadProc
	      invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR ThreadID
        mov threadControl, eax

        ; Setting the initial snake...

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
        .elseif wParam == VK_RETURN
        .endif

    .elseif uMsg == WM_MOVEMENT
        mov esi, offset snake
        mov eax, snake_size
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

            mov eax, snake_size

            .if count == eax
                jmp endMove
            .endif
        .endw
        endMove:

        .if direction == 0
            mov esi, offset snake

            .if dword ptr[snake] == 475
                mov dword ptr[snake], 0
            .else
                add dword ptr[snake], 25
            .endif
        .elseif direction == 1
            mov esi, offset snake

            .if dword ptr[snake+4] == 0
                mov dword ptr[snake+4], 475
            .else
                sub dword ptr[snake+4], 25
            .endif
        .elseif direction == 2
            mov esi, offset snake

            .if dword ptr[snake] == 0
                mov dword ptr[snake], 475
            .else
                sub dword ptr[snake], 25
            .endif
        .elseif direction == 3
            mov esi, offset snake

            .if dword ptr[snake+4] == 475
                mov dword ptr[snake+4], 0
            .else
                add dword ptr[snake+4], 25
            .endif
        .endif

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

  mov esi, offset snake
  mov count, 0

  .while TRUE
      invoke SelectObject, memDC, hBmpBody

      invoke BitBlt, hDC, dword ptr[esi], dword ptr[esi+4], 25, 25, memDC, 0, 0, SRCCOPY

      add esi, 8

      inc count

      mov eax, snake_size

      .if count == eax
          jmp endPrintSnake
      .endif
  .endw
  endPrintSnake:

  invoke SelectObject, memDC, hBmpFood

  invoke BitBlt, hDC, food.x, food.y, 25, 25, memDC, 0, 0, SRCCOPY

  invoke wsprintfA, ADDR buffer, ADDR header_placar, snake_size
  invoke ExtTextOutA, hDC, 400, 0, ETO_CLIPPED, NULL, ADDR buffer, eax, NULL

	invoke SelectObject, hDC, hOld
	invoke DeleteDC, memDC

	return 0
Paint_Proc endp

; --------------------- MainThread ------------------------
MainThreadProc PROC USES ecx Param:DWORD

    invoke WaitForSingleObject, hEventStart, 100

    .if eax == WAIT_TIMEOUT
        invoke PostMessage, hWnd, WM_MOVEMENT, NULL, NULL
        jmp MainThreadProc
    .endif

    ret
MainThreadProc endp

end start
