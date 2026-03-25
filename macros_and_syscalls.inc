SYS_read equ 0
SYS_write equ 1
SYS_close equ 3
SYS_socket equ 41
SYS_accept equ 43
SYS_bind equ 49
SYS_listen equ 50
SYS_exit equ 60

INADDR_ANY equ 0
SOCK_STREAM equ 1
AF_INET equ 2

STDOUT equ 1
STDERR equ 2

EXIT_SUCCESS equ 0
EXIT_FAILURE equ 1

macro funcall4 func, a, b, c, d
{
  mov rdi, a
  mov rsi, b
  mov rdx, c
  mov r10, d
  call func
}

macro syscall1 number, a
{
  mov rax, number
  mov rdi, a
  syscall
}

macro syscall2 number, a, b
{
  mov rax, number
  mov rdi, a
  mov rsi, b
  syscall
}

macro syscall3 number, a, b, c
{
  mov rax, number
  mov rdi, a
  mov rsi, b
  mov rdx, c
  syscall
}

macro write fd, buf, count
{
  syscall3 SYS_write, fd, buf, count
}

macro read fd, buf, count
{
  syscall3 SYS_read, fd, buf, count
}

macro exit code
{
  syscall1 SYS_exit, code
}

macro socket domain, type, protocol
{
  syscall3 SYS_socket, domain, type, protocol
}

;; int bind(int fd, const struct sockaddr *addr, socklen_t len)
macro bind sockfd, addr, addrlen
{
  syscall3 SYS_bind, sockfd, addr, addrlen
}

macro close sockfd
{
  syscall1 SYS_close, sockfd
}

macro listen sockfd, backlog
{
  syscall2 SYS_listen, sockfd, backlog
}

;; int accept(int sockfd, struct sockaddr *addr, socklen_t *addrLen)
macro accept fd, addr, addrLen
{
  syscall3 SYS_accept, fd, addr, addrLen
}

