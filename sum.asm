global sum

; Ustawia bazowe wartości.
sum:
    mov     r8, 0                   ; Zmienna do iterowania po tablicy.
    mov     r11, [rdi]              ; Trzyma znak (+/-) sumy.
    shr     r11, 63                 ; Zdobywa znak pierwszej liczby.

; Kontroluje ilość wykonań programu. Oblicza wartości kolejnych potęg.
.loop:
    inc     r8
    cmp     r8, rsi                 ; Porównuje iterator pętli z 'n'.
    je      .end                    ; Jeśli są równe, to koniec programu.

    mov     rax, 64                 ; Przetrzymuje potęgę dwójki, przez którą mnożymy aktualną liczbę.
    mov     rcx, r8
    mul     rcx
    mul     rcx
    div     rsi
    mov     r9, rax                 ; Zapisuje potęgę dwójki do późniejszego przestawiania.

; Dzieli aktualnie dodawaną liczbę na dwie części i dodaje mniej znaczącą z nich do aktualnego 'y'.
.adding:
    mov     rcx, r9                 ; Potęga mnożonej dwójki.
    and     rcx, 63                 ; Liczy modulo 64 z potęgi (Stopień przesunięcia między dwoma blokami).
    mov     r10, [rdi + 8 * r8]     ; Bierze do r10 aktualną liczbę.
    shl     r10, cl                 ; Przesuwa r10 o część liczby, która idzie na kolejne miejsce w tabeli.
    mov     rcx, r9                 ; Oblicza blok, do którego dodaje.
    shr     rcx, 6                  ; Dzielimy przez 64.
    add     [rdi + 8 * rcx], r10    ; Dodaje do aktualnej wartości na tym miejscu nową.
    mov     rax, 0                  ; Zapisuje carry.
    jnc     .continue_adding
    mov     rax, 1

; Zapisuje aktualnie dodawaną liczbę oraz ustanawia znak kolejnej przegrody.
.continue_adding:
    mov     r10, [rdi + 8 * r8]     ; Bierze do r10 aktualną liczbę.
    mov     rdx, 0
    cmp     r11, rdx                ; Sprawdza aktualny znak liczby 'y'.
    je      .set_new_bracket

    not     rdx                     ; Zmienia znak dla ujemnej.

; Uzupełnia poprawnym znakiem przegrodę po aktualnie dodawanej liczbie.
.set_new_bracket:
    mov     [rdi + 8 * r8], rdx     ; Wypełnia komórkę z aktualną liczbą poprawnym znakiem.
    mov     rdx, 0
    cmp     rdx, rax
    je     .adding_continue         ; Jeśli przy dodawaniu poprzednim nie przenosimy 1.

; Jeśli jest carry z dodawania mniej znaczącej części, to je dodaje do bardziej znaczącej.
.add_carry:
    add     qword [rdi + 8 * rcx + 8], 1

; Dodaje bardziej znaczącą część aktualnie dodawanej liczby do 'y'.
.adding_continue:
    mov     rdx, r9                 ; Potęga mnożonej dwójki.
    and     rdx, 63                 ; Liczy modulo 64 z potęgi.
    mov     rax, 0
    cmp     rax, rdx                ; Modulo jest równe 0, więc bardziej znaczące bity stanowią tylko symbol.
    jne     .shift_64
    mov     rdx, 1
    sar     r10, 1                  ; Przesuwamy o 1, a później o 63.

; Ciąg dalszy dodawania bardziej znaczącej części.
.shift_64:
    mov     cl, 64                  ; Bierze odchył w drugą stronę.
    sub     cl, dl

    mov     rdx, r10
    shr     rdx, 63                 ; Zapamiętuje znak aktualnie dodawanej liczby.

    sar     r10, cl                 ; Przesuwa r10 o część liczby w przeciwną stronę z poprawnym znakiem.
    mov     rcx, r9                 ; Oblicza blok, do którego dodaje.
    shr     rcx, 6                  ; Oblicza komórkę, do której dodajemy drugą część aktualnej wartości.
    inc     rcx                     ; Dostęp do starszych bitów liczby, do której dodajemy.
    add     [rdi + 8 * rcx], r10    ; Dodajemy do starszych bitów.

    cmp     rdx, r11                ; Porównujemy znaki liczb.
    je      .clear_brackets         ; Jeśli są równe.

; Określa znak nowo powstałego 'y', jeśli znaki poprzedniego 'y' i dodawanej liczby były różne.
.different_sign:
    mov     rdx, [rdi + 8 * rcx]
    shr     rdx, 63                 ; Zdobywa aktualny symbol liczby 'y'.
    mov     r11, rdx                ; Zmienia symbol na symbol aktualnej liczby.

; W rejestrze 'rdx' zapisuje wartość aktualnego symbolu 'y' w 64 bitach.
.clear_brackets:
    mov     rdx, 0
    cmp     rdx, r11                ; Jeśli liczba jest nieujemna.
    je      .mini_loop
    not     rdx                     ; Jeśli symbol 'y' to minus, to rdx ustawia się na ujemne zapełnianie.

; Uzupełnia wszystkie przegrody od aktualnie modyfikowanej do końca liczby 'y' jej aktualnym znakiem.
.mini_loop:
    inc     rcx                     ; Zwiększa indeks przegród do zapełnienia.
    cmp     rcx, r8                 ; Póki nie dojdzie do aktualnie najstarszego bloku.
    jg      .loop
    mov     [rdi + 8 * rcx], rdx    ; Wypełnia przegrodę odpowiednimi znakami.
    jmp     .mini_loop

; Kończy program.
.end:
    ret