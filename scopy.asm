
global _start

; Program 'scopy' przyjmuje dwa argumenty, które otrzymuje na stosie.
; Pierwszy argument to nazwa pliku otwieranego, a drugi to nazwa pliku, który zostanie przez niego stworzony.
; Program czyta bajty z pierwszego pliku do buffora, którego długość to 4096 bajtów, co jest optymalną długością buffora.
; Następnie jeśli, wartość któregoś bajtu jest równa kodu ASCII 's' lub 'S', to wpisuje ten bajt, do drugiego buffora.
; Wpisuje on również długości spójnych niepustych ciągów bajtów o innych wartościach modulo 66536 do drugiego buffora.
; Drugi buffor, który wpisuje bajty do stworzonego pliku jest dwukrotnie dłuższy, ponieważ część znaków z pierwszego buffora,
; może być zapisywana w dwóch bajtach. Wszystkie 2 bajtowe liczby zapisywane są w porządku cienkokońcówkowym.

_start:

    SYS_READ        equ 0                   ; Stała zawierająca kod funkcji systemowej 'sys_read'.
    SYS_WRITE       equ 1                   ; Stała zawierająca kod funkcji systemowej 'sys_write'.
    SYS_OPEN        equ 2                   ; Stała zawierająca kod funkcji systemowej 'sys_open'.
    SYS_CLOSE       equ 3                   ; Stała zawierająca kod funkcji systemowej 'sys_close'.
    SYS_EXIT        equ 60                  ; Stała zawierająca kod funkcji systemowej 'sys_exit'.

    BIG_S_SIGN      equ 83                  ; Stała reprezentująca kod ASCII 'S'.
    SMALL_S_SIGN    equ 115                 ; Stała reprezentująca kod ASCII 's'.
    ERROR_CHECK     equ 0                   ; Stała zawierająca kod braku błędu.
    BUFFOR_SIZE     equ 4096                ; Stała zawierająca rozmiar bufforów.
    ARGUMENTS_NUM   equ 3                   ; Stała zawierająca ilość poprawnych argumentów.


section .bss

    in_buffor       resb BUFFOR_SIZE        ; Buffor zapisujący bajty wyczytywane z pliku.
    out_buffor      resb BUFFOR_SIZE * 2    ; Buffor zapisujący bajty wpisywane do pliku.


section .text

; Sprawdza czy zachowana jest wymagana ilość argumentów.
.arg_check:
    xor     r14, r14                        ; r14 - trzyma informację o tym, czy w trakcie wykonywania programu wystąpił błąd. 
    cmp     qword[rsp], ARGUMENTS_NUM       ; Sprawdza, czy zgadza się ilość argumentów.
    jne     .error                          ; Jeśli liczba się nie zgadza, to kończy program z błędem.

; Otwiera i tworzy pliki o odpowiednich nazwach.
.open_files:
    mov     rax, SYS_OPEN                   ; rax - kod funkcji otwierania otrzymanego pliku.
    mov     rdi, qword[rsp + 16]            ; rdi - nazwa otwieranego pliku.
    mov     rdx, 444o                       ; rdx - uprawnienia z jakimi otwiera plik.
    syscall

    cmp     rax, ERROR_CHECK                ; Sprawdza, czy nie pojawił się błąd przy otwieraniu pliku.
    jl      .error                          ; Jeśli zawartość rax jest mniejsza od zera, to wystąpił błąd.
    mov     r12, rax                        ; r12 - deskryptor pliku, z którego czyta.

    mov     rax, SYS_OPEN                   ; rax - kod funkcji tworzenia pliku, do którego będą wpisywane znaki.
    mov     rdi, qword[rsp + 24]            ; rdi - nazwa tworzonego pliku.
    mov     rsi, 301o                       ; rsi - flagi, które zapewnią, że nowy plik się stworzy, jeśli nie ma pliku o takiej nazwie.
    mov     rdx, 644o                       ; rdx - uprawnienia '-rw-r--r--' z jakimi stworzy plik.
    syscall
    
    cmp     rax, ERROR_CHECK                ; Sprawdza, czy nie pojawił się błąd przy tworzeniu pliku.
    jl      .close_first_with_error         ; Jeśli zawartość rax jest mniejsza od zera, to wystąpił błąd.
    mov     r13, rax                        ; r13 - deskryptor pliku, w którym zapisuję.

    xor     r10, r10                        ; r10 - trzyma inforamcję o długości spójnego ciągu symboli różnych od 's' i 'S'.    

; Czyta kolejne bajty z pierwszego pliku.
.read:
    mov     rax, SYS_READ                   ; rax - kod funkcji czytania z pliku.
    mov     rdi, r12                        ; rdi - deskryptor pliku sczytwanego.
    mov     rsi, in_buffor                  ; rsi - buffor, w którym zapisuje sczytane bajty.
    mov     rdx, BUFFOR_SIZE                ; rdx - maksymalna liczba bajtów, które można sczytać.
    syscall
    
    cmp     rax, ERROR_CHECK                ; Sprawdza, czy nie pojawił się błąd przy czytaniu.
    jl      .close_both_with_error          ; Jeśli zawartość rax jest mniejsza od zera, to wystąpił błąd.
    je      .add_last                       ; Jeśli zawartość rax jest równa zero, to nie ma już bajtów do sczytania.

    mov     r8, rax                         ; r8 - ile znaków wczytano z pliku.
    xor     r9, r9                          ; r9 - aktualnie przerabiany w pętli znak.
    xor     r11, r11                        ; r11 - iterator pętli.
    xor     rbx, rbx                        ; rbx - ilość wpisanych w tym powtórzeniu pętli bajtów do 'out_buffora'.

; Początek pętli analizującej kolejne bajty z 'in_buffor'.
.loop:
    mov     r9b, [in_buffor + r11]          ; Sczytuje z 'in_buffor' kolejny bajt.

    cmp     r9b, SMALL_S_SIGN               ; Sprawdza, czy aktualny znak, to 's'.
    je      .any_s
    cmp     r9b, BIG_S_SIGN                 ; Sprawdza, czy aktualny znak, to 'S'.
    je      .any_s

    inc     r10                             ; Znak jest inny, niż 's' i 'S', więc zwiększa się liczba innych znaków.
    jmp     .end_loop                       
    
; Sprawdza długość ciągu znaków innych, niż 's' oraz zapisuje ją na 'out_buffor', jeśli jest większa, niż zero.
.any_s:
    xor     rcx, rcx
    cmp     r10, rcx                        ; Sprawdza, czy przed 's' były znaki inne, niż ono samo.
    je      .adding_s                       ; Nie było znaków innych, niż 's' bezpośrednio przed nim.
    
    mov     rcx, r10                        ; Przepisuje do rcx długość ostatniego ciągu znaków innych, niż 's' i 'S'.
    mov     [out_buffor + rbx], cl          ; Wpisuje do 'out_buffora' pierwszy bajt długości ciągu.
    inc     rbx                             ; Zwiększa się ilość znaków wpisanych do 'out_buffora'.
    mov     [out_buffor + rbx], ch          ; Wpisuje do 'out_buffora' drugi bajt długości ciągu.
    inc     rbx                             ; Zwiększa się ponownie ilość znaków wpisanych do 'out_buffora'.

; Zapisuje na 'out_buffor' znak 's'.
.adding_s:
    mov     [out_buffor + rbx], r9b         ; Wpisuje do 'out_buffora' bajt zawierający 's'.
    inc     rbx                             ; Zwiększa się ilość znaków wpisanych do 'out_buffora'.
    xor     r10, r10                        ; Zeruje się długość spójnego ciągu innych znaków.

; Sprawdza, czy wszystkie znaki zostały zapisane i jeśli nie, to powtarza pętlę.
.end_loop:
    inc     r11                             ; Zwiększa iterator pętli.
    cmp     r11, r8                         ; Sprawdza, czy zostały zapisane wszystkie aktualnie sczytane bajty.
    jl      .loop                           ; Jeśli nie, zaczyna powtarza pętlę, póki nie zostaną przepisane wszystkie.

; Zapisuje w drugim pliku wszystkie bajty z 'out_buffor'.
.write:
    mov     rax, SYS_WRITE                  ; rax - kod funkcji wpisywania do pliku.
    mov     rdi, r13                        ; rdi - deskryptor pliku, do którego wpisywane są bajty. 
    mov     rsi, out_buffor                 ; rsi - buffor, na którym zapisane są bajy do wpisania.
    mov     rdx, rbx                        ; rdx - liczba bajtów do wpisania.
    syscall
    
    cmp     rax, ERROR_CHECK                ; Sprawdza, czy nie pojawił się błąd przy wpisywaniu.
    jl      .close_both_with_error          ; Jeśli zawartość rax jest mniejsza od zera, to wystąpił błąd.
    sub     rbx, rax                        ; Odejmuje od liczby, liczbę wpisanych już bajtów.
    mov     rdx, [out_buffor + rax]         ; Przesuwa 'out_buffor' o liczbę wpisanych bajtów.
    mov     [out_buffor], rdx
    cmp     rbx, 0                          ; Sprawdza, czy wpisane są już wszystkie bajty zapisane na 'out_bufforze'
    jnz      .write                         ; Jeśli nie są, to próbuje wpisać ponownie pozostałe bajty.
    
    jmp     .read                           ; W przeciwnym wypadku wraca do czytania kolejnych bajtów.
    
; Dodaje długość ciągu znaków innych, niż 's', jeśli plik kończył się takim ciągiem o niezerowej długości.
.add_last:
    xor     rcx, rcx
    cmp     r10, rcx                        ; Sprawdza, czy po ostatnim 's' wystąpiły jeszcze jakieś inne znaki.
    je      .close_both                     ; Jeśli nie, to skacze do zamykania plików.

    mov     rcx, r10                        ; Przepisuje do rcx długość ostatniego ciągu znaków innych, niż 's' i 'S'.
    xor     r10, r10                        ; Zeruje długość ciągu innych znaków.
    mov     [out_buffor], cl                ; Wpisuje do 'out_buffora' pierwszy bajt długości ciągu.
    mov     [out_buffor + 1], ch            ; Wpisuje do 'out_buffora' drugi bajt długości ciągu.

    mov     rbx, 2                          ; Zapisuje, że w 'out_buffor' są dwa bajty do wpisania.      
    jmp     .write

; Zapisuje na r14 wystąpienie błędu.
.close_both_with_error:
    mov     r14, 1
 
; Zamyka plik, do którego były wpisywane bajty.
.close_both:
    mov     rax, SYS_CLOSE                  ; rax - kod funkcji zamykającej plik.
    mov     rdi, r13                        ; rdi - deskryptor zamykanego pliku.
    syscall

    cmp     rax, ERROR_CHECK                ; Sprawdza, czy wystąpił błąd zamykania.
    jge      .close_first

; Zapisuje na r14 wystąpienie błędu.
.close_first_with_error:
    mov     r14, 1
    
; Zamyka plik, z którego czytano bajty.
.close_first:
    mov     rax, SYS_CLOSE                  ; rax - kod funkcji zamykającej plik.
    mov     rdi, r12                        ; rdi - deskryptor zamykanego pliku.
    syscall

    cmp     rax, ERROR_CHECK                ; Sprawdza, czy wystąpił błąd zamykania.
    jge      .exit

; Zapisuje na r14 wystąpienie błędu.
.error:
    mov     r14, 1

; Kończy program z odpowiednim kodem.
.exit:
    mov     rax, SYS_EXIT                   ; rax - kod funkcji kończącej program.
    mov     rdi, r14                        ; rdi - kod z jakim kończony jest program.
    syscall