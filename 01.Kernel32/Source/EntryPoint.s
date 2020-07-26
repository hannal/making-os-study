[ORG 0x00]
[BITS 16]

SECTION .text

START:
    mov ax, 0x1000  ; 보호 모드 엔트리 포인트의 시작 어드레스를 세그먼트 레지스터 값으로 변환
    mov ds, ax

    cli ; 인터럽트가 발생하지 못하도록 설정
    lgdt [ GDTR ]
    ;;
    ; 보호 모드로 진입
    mov eax, 0x4000003B ; PG=0, CD=1, NW=0, AM=0, WP=0, NE=1, ET=1, TS=1, EM=0, MP=1, PE=1
    mov cr0, eax

    ; 커널 코드 세그먼트를 0x00을 기준으로 하는 것으로 교체하고 EIP의 값을 0x00을 기준으로 재설정
    ; cs 세그먼트 셀렉터 : EIP
    jmp dword 0x08: ( PROTECTEDMODE - $$ + 0x10000 )

;;
; 보호 모드로 진입
[BITS 32]
PROTECTEDMODE:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; 스택을 0x00000000~0x0000FFFF 영역에 64kb 크기로 생성
    mov ss, ax
    mov esp, 0xFFFE
    mov ebp, 0xFFFE

    push ( SWITCHSUCCESSMESSAGE - $$ + 0x10000 )
    push 2  ; y coord 2
    push 0  ; x coord 0
    call PRINTMESSAGE
    add esp, 12 ; 삽입한 파라미터 제거

    jmp $

PRINTMESSAGE:
    push ebp
    mov ebp, esp
    push esi
    push edi
    push eax
    push ecx
    push edx

    ; y coord
    mov eax, dword [ ebp + 12 ]
    mov esi, 160
    mul esi
    mov edi, eax

    ; x coord
    mov eax, dword [ ebp + 8 ]
    mov esi, 2
    mul esi
    add edi, eax

    mov esi, dword [ ebp + 16 ]

.MESSAGELOOP:
    mov cl, byte [ esi ]
    cmp cl, 0
    je .MESSAGEEND
    mov byte [ edi + 0xB8000 ], cl
    add esi, 1
    add edi, 2
    jmp .MESSAGELOOP

.MESSAGEEND:
    pop edx
    pop ecx
    pop eax
    pop edi
    pop esi
    pop ebp
    ret

; data area
align 8, db 0 ; 아래 데이터들을 8바이트에 맞춰 정렬하기 위해 추가

dw 0x0000 ; GDTR의 끝을 8byte로 정렬하기 위해 추가
GDTR:
    dw GDTEND - GDT - 1         ; 아래에 위치하는 GDT 테이블의 전체 크기
    dd ( GDT - $$ + 0x10000 )   ; 아래에 위치하는 GDT 테이블의 시작 어드레스

GDT:
    ; null descriptor, 반드시 0으로 초기화
    NULLDescriptor:
        dw 0x0000
        dw 0x0000
        db 0x00
        db 0x00
        db 0x00
        db 0x00

    ; 보호 모드 커널용 코드 세그먼트 디스크립터
    CODEDESCRIPTOR:
        dw 0xFFFF   ; Limit [15:0]
        dw 0x0000   ; Base [15:0]
        db 0x00     ; Base [23:16]
        db 0x9A     ; P=1, DPL=0, Code segment, execute/read
        db 0xCF     ; G=1, D=1, L=0, Limit[19:16]
        db 0x00     ; Base [31:24]

    ; 보호 모드 커널용 데이터 세그먼트 디스크립터
    DATADESCRIPTOR:
        dw 0xFFFF   ; Limit [15:0]
        dw 0x0000   ; Base [15:0]
        db 0x00     ; Base [23:16]
        db 0x92     ; P=1, DPL=0, Data segment, read/write
        db 0xCF     ; G=1, D=1, L=0, Limit[19:16]
        db 0x00     ; Base [31:24]
GDTEND:

SWITCHSUCCESSMESSAGE: db 'Switch to protected mode success', 0

times 512 - ( $ - $$ ) db 0x00