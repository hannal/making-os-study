[ORG 0x00]  ; 시작 어드레스 설정
[BITS 16]   ; 이하 코드는 16비트로 설정

SECTION .text

jmp 0x1000:START

SECTORCOUNT:    dw 0x000

START:
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800  ; 비디오 메모리 어드레스 0x0B8000 을 세그먼트 레지스터 값으로 변환
    mov es, ax

    mov ax, 2       ; 한 문자를 나타내는 바이트 수 설정
    mul word [ SECTORCOUNT ]
    mov si, ax
    mov byte [ es: si + (160*2) ], '0'  ; 계산된 결과를 비디오 메모리에 오프셋으로 삼아 세 번째 라인부터 화면에 0을 출력.
    add word [ SECTORCOUNT ], 1 ; 섹터 수 1 증가

    jmp $   ; 현재 위치에서 무한 루프 수행

    times 512 - ( $ - $$ ) db 0x00  ; $ : 현재 라인의 어드레스, $$ : 현재 섹션(.text)의 시작 어드레스,
                                    ; $ - $$ : 현재 섹션을 기준으로 하는 오프셋
                                    ; times : 반복 수행.
                                    ; 현재 위치에서 어드레스 512까지 0x00 으로 채움
