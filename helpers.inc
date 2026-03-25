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


