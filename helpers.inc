;; Check if text starts with a given prefix
;;  rdi - void *text
;;  rsi - size_t text_len
;;  rdx - void *prefix
;;  r10 - size_t prefix_len
starts_with:
  xor rax, rax
  xor rbx, rbx
.next_char:
  cmp rsi, 0
  jle .done
  cmp r10, 0
  jle .done

  mov al, byte [rdi]
  mov bl, byte [rdx]
  cmp rax, rbx
  jne .done

  dec rsi
  inc rdi
  dec r10
  inc rdx
  jmp .next_char

.done:
  cmp r10, 0 ; check if we've consumed the whole prefix
  je .yes
.no:
  mov rax, 0
  ret
.yes:
  mov rax, 1
  ret

;; int str_to_int (const char *str)
;; rdi = pointer to null terminated string
;; returns:
;;    eax = parsed integer
;;
;; returns -1 if input cannot be parsed as int
str_to_int:
  xor eax, eax
.str_to_int.loop:
  movzx edx, byte [rdi]
  test dl, dl
  jz .str_to_int.done
  cmp dl, '0'
  jl .str_to_int.err
  cmp dl, '9'
  jg .str_to_int.err
  lea eax, [eax + eax*4]
  lea eax, [eax*2 + edx - '0']
  inc rdi
  jmp .str_to_int.loop

.str_to_int.done:
  ret
.str_to_int.err:
  mov rax, -1
  ret

