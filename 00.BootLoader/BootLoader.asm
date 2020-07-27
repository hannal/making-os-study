[ORG 0x00]  ; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16]   ; 이하의 코드는 16비트 코드로 설정

SECTION .text   ; text 섹션(세그먼트)을 정의

jmp 0x07C0:START    ; CS세그먼트 레지스터에 0x07C0을 복사하면서 START 레이블로 이동

; os 환경설정 값

TOTALSECTORCOUNT:   dw  1 ; 부트 로더를 제외한 MINT64 OS 이미지의 크기


; 코드 영역
START:
    mov ax, 0x07C0  ; 부트 로더의 시작 어드레스를 세그먼트 레지스터 값으로 변환
    mov ds, ax      ; DS 세그먼트 레지스터에 설정
    mov ax, 0xB800  ; 비디오 메모리의 시작 어드레스를 세그먼트 레지스터 값으로 변환
    mov es, ax      ; ES세그먼트 레지스터에 설정

    ; 스택을 0x0000:0000 ~ 0x0000:FFFF 영역에 64kb 크기로 생성
    mov ax, 0x0000  ; 스택 세그먼트의 시작 어드레스를 세그먼트 레지스터 값으로 변환
    mov ss, ax      ; ss = ax
    mov sp, 0xFFFE
    mov bp, 0xFFFE

    ; 화면을 모두 지우고, 속성값을 녹색으로 설정
    mov si, 0   ; SI 레지스터(문자열 원본 인덱스 레지스터) 초기화

.SCREENCLEARLOOP:
    mov byte [ es: si ], 0  ; 비디오 메모리의 문자가 위치하는 어드레스에 0을 복사하여 문자 삭제
    mov byte [ es: si + 1 ], 0x0A   ; 비디오 메모리의 속성이 위치하는 어드레스에 0x0A(검은 바탕에 밝은 녹색)을 복사
    add si, 2   ; 문자와 속성을 설정했으므로 다음 위치로 이동

    cmp si, 80 * 25 * 2 ; 화면의 전체 크기는 80*25
    jl  .SCREENCLEARLOOP    ; SI 레지스터가 80*25*2 보다 작다면 아직 지우지 못한 영역이 있으므로 .SCREENCLEARLOOP 레이블로 이동

    ; 화면 상단에 시작 메시지 출력
    push MESSAGE1   ; 출력할 메시지의 어드레스를 스택에 삽입
    push 0          ; y좌표(0)을 스택에 삽입
    push 0          ; x좌표
    call PRINTMESSAGE
    add sp, 6       ; 삽입한 파라미터 제거

    ; os 이미지를 로딩한다는 메시지 출력
    push IMAGELOADINGMESSAGE
    push 1
    push 0
    call PRINTMESSAGE
    add sp, 6

    ; 디스크를 읽기 전에 먼저 리셋
RESETDISK:
    ; call bios reset function
    ;; 서비스 번호 0, 드라이브 번호 0(floppy), hda(0x80), hda(0x81)
    mov ax, 0
    mov dl, 0x80
    int 0x13
    ; 에러 발생 시 에러 처리로 이동
    jc HANDLEDISKERROR

    ; 디스크에서 섹터를 읽음
    ;; 디스크의 내용을 메모리로 복사할 어드레스(ES:BX)를 0x10000으로 설정
    mov si, 0x1000  ; os 이미지를 복사할 어드레스(0x10000)를 si 값으로 변환
    mov es, si
    mov bx, 0x0000  ; 어드레스를 0x1000:0000(0x10000)으로 최종 설정
    mov di, word [ TOTALSECTORCOUNT ] ; 복사할 os 이미지의 섹터 수를 di 에 설정

READDATA:   ; 디스크를 읽는 코드 시작
    ; 모든 섹터를 다 읽었는지 확인
    cmp di, 0
    je READEND
    sub di, 0x1 ; 복사할 섹터 수를 1 감소

    ; call bios read function
    mov ah, 0x02    ; bios 서비스 번호 2 (read sector)
    mov al, 0x1     ; 읽을 섹터 수는 1
    mov ch, byte [ TRACKNUMBER ]    ; 읽을 트랙 번호 설정
    mov cl, byte [ SECTORNUMBER ]
    mov dh, byte [ HEADNUMBER ]
    mov dl, 0x80    ; 읽을 드라이브 번호(0x00=floppy, 0x80=hda) 설정
    int 0x13
    jc HANDLEDISKERROR

    ; 복사할 어드레스와 트랙, 헤드, 섹터 어드레스 계산
    add si, 0x0020  ; 512(0x200)바이트만큼 읽었으므로 si 값으로 변환
    mov es, si      ; es에 더해서 어드레스를 한 섹터만큼 증가

    ; 한 섹터를 읽었으므로 섹터 번호를 증가시키고 마지막 섹터(18)까지 읽었는지 판단
    mov al, byte [ SECTORNUMBER ]   ; 섹터 번호를 al에 설정
    add al, 0x01
    mov byte [ SECTORNUMBER ] , al  ; 증가시킨 섹터 번호를 SECTORNUMBER에 다시 설정
    cmp cl, 19
    jl READDATA ; 섹터 번호가 19 미만이면 READDATA로 이동

    ; 마지막 섹터까지 읽었으면 헤드를 토글(0->1, 1->0)하고, 섹터 번호를 1로 설정
    xor byte [ HEADNUMBER ], 0x01
    mov byte [ SECTORNUMBER], 0x01

    ; 헤드가 1->0으로 바뀌었으면 양쪽 헤드를 모두 읽은 것이므로 아래로 이동하여 트랙 번호 1 증가
    cmp byte [ HEADNUMBER ], 0x00
    jne READDATA

    ; 트랙을 1 증가시킨 후 다시 섹터 읽기로 이동
    add byte [ TRACKNUMBER ], 0x01
    jmp READDATA

READEND:
    push LOADINGCOMPLETEMESSAGE
    push 1
    push 20
    call PRINTMESSAGE
    add sp, 6
    ; 로딩한 가상 os 이미지 실행
    jmp 0x1000:0x0000

; 디스크 에러 처리 함수
HANDLEDISKERROR:
    push DISKERRORMESSAGE
    push 1
    push 20
    call PRINTMESSAGE
    jmp $   ; 현재 위치에서 무한 루프 수행

; 메시지를 출력하는 함수
; PARAM: x 좌표, y좌표, 문자열
PRINTMESSAGE:
    push bp ; base pointer 레지스터를 스택에 삽입
    mov bp, sp  ; bp = sp(stack pointer). bp를 이용해서 파라미터에 접근할 목적

    push es ; es 세그먼트 레지스터부터 dx 레지스터까지 스택에 삽입
    push si ; 함수에서 임시로 사용하는 레지스터로 함수의 마지막 부분에서 스택에 삽입된 값을 꺼내 원래 값으로 복원.
    push di
    push ax
    push cx
    push dx

    ; es 에 비디오 모드 어드레스 설정
    mov ax, 0xB800  ; 비디오 메모리 시작 어드레스(0x0B8000)를 세그먼트 레지스터 값으로 변환
    mov es, ax

    ; x, y 좌표로 비디오 메모리의 어드레스를 계산
    ;; y 좌표를 이용해서 먼저 라인 어드레스를 구함
    mov ax, word [ bp + 6 ] ; ax = 파라미터 2(y)
    mov si, 160 ; si = 한 라인의 바이트 수(2*80 cols)
    mul si  ; ax * si 하여 화면 y 어드레스 계산
    mov di, ax

    ;; x 좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
    mov ax, word [ bp + 4]
    mov si, 2   ; si = 한 문자를 나타내는 바이트 수
    mul si
    add di, ax  ; 화면 y어드레스와 계산된 x 어드레스를 더해서 실제 비디오 메모리 어드레스를 계산

    ; 출력할 문자열의 어드레스
    mov si, word [ bp + 8 ] ; 파라미터3(출력할 문자열)

.MESSAGELOOP:
    mov cl, byte [ si ] ; si이 가리키는 문자열 위치에서 한 문자를 cl에 복사. cl은 cx 의 하위 1바이트.
                        ; 문자열은 1바이트면 충분하므로 cx 의 하위 1바이트만 사용.
    cmp cl, 0   ; 복사된 문자와 0 비교
    je .MESSAGEEND  ; 0이면 .MESSAGEEND로 이동.

    mov byte [ es: di ], cl ; 0이 아니면 비디오 메모리 어드레스 0xB800:di에 문자 출력
    add si, 1   ; si 에 1을 더하여 다음 문자열로 이동
    add di, 2   ; di 레지스터에 2를 더하여 비디오 메모리의 다음 문자 위치로 이동.
                ; 비디오 메모리는 (문자, 속성) 쌍으로 구성되므로 문자만 출력하려면 2를 더함.

    jmp .MESSAGELOOP

.MESSAGEEND:
    pop dx  ; 함수에서 사용이 끝난 dx부터 es까지를 스택에 삽입된 값을 이용하여 복원
    pop cx  ; 스택이므로 삽입 역순으로 제거.
    pop ax
    pop di
    pop si
    pop es
    pop bp  ; bp 복원
    ret

; 데이터 영역

MESSAGE1:   db 'Mint64 os boot loader starts', 0 ; 출력할 메시지 정의. 마지막은 0으로 설정하여 .MESSAGELOOP에서 처리할 수 있게 함.

DISKERRORMESSAGE:   db 'DISK error', 0
IMAGELOADINGMESSAGE:    db 'os image loading', 0
LOADINGCOMPLETEMESSAGE: db 'complete', 0

SECTORNUMBER:   db 0x02
HEADNUMBER: db 0x00
TRACKNUMBER:    db 0x00

times 510 - ( $ - $$ ) db 0x00  ; $: 현재 라인의 어드레스
                                ; $$: 현재 섹션(.text)의 시작 어드레스
                                ; $ - $$: 현재 섹션을 기준으로 하는 오프셋
                                ; 510 - ( $ - $$ ): 현재부터 어드레스 510까지
                                ; db 0x00: 1바이트를 선언하고 값은 0x00
                                ; times: 반복 수행
                                ; 현재 위치에서 어드레스 510까지 0x00 으로 채움

db 0x55     ; 1바이트를 선언하고 값은 0x55
db 0xAA     ; 1바이트를 선언하고 값은 0xAA
            ; 어드레스 511, 512에 0x55, 0xAA를 써서 부트 섹터로 표기함.

