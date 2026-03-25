format ELF64 executable

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

MAX_CONN equ 5 ;; arbitrarily set max # of connections to 5

REQUEST_CAP equ 128 * 1024  ;; arbitrary limit for http request
                            ;; http 1.1 doesn't have a specific
                            ;; limit, but taking some inspo from
                            ;; tsoding, we set it to 128K for now

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

segment readable executable
entry main
main:
  write STDOUT, start, start_len
  write STDOUT, socket_trace, socket_trace_len

  ; create the socket
  ; tcp_socket = socket(AF_INET, SOCK_STREAM, 0);
  socket AF_INET, SOCK_STREAM, 0
  cmp rax, 0
  jl .error
  mov qword [sockfd], rax 

  write STDOUT, bind_trace, bind_trace_len
  mov word [servaddr.sin_family], AF_INET
  mov word [servaddr.sin_port], 0x391b ; hex(6969) = 0x1b39, but we need to reverse the order
  mov dword [servaddr.sin_addr], INADDR_ANY

  bind [sockfd], servaddr.sin_family, sizeof_servaddr
  cmp rax, 0
  jl .error

  write STDOUT, listen_trace, listen_trace_len
  listen [sockfd], MAX_CONN 
  cmp rax, 0
  jl .error

.next_request:
  write STDOUT, accept_trace, accept_trace_len
  accept [sockfd], cliaddr.sin_family, cliaddr_len
  cmp rax, 0
  jl .error

  mov qword [connfd], rax

  read [connfd], request, REQUEST_CAP
  cmp rax, 0
  jl .error

  mov [request_len], rax
  mov [request_cur], request

  write STDOUT, [request_cur], [request_len]

  write [connfd], response, response_len

  jmp .next_request

  write STDOUT, ok, ok_len
  close [connfd]
  close [sockfd]
  exit EXIT_SUCCESS

.error:
  write STDERR, err_msg, err_len
  close [connfd]  ; if connfd is invalid, close will just return -1, don't really care though
  close [sockfd]  ; if sockfd is invalid, close will just return -1, don't really care though
  exit EXIT_FAILURE


;; db - 1 byte
;; dw - 2 byte
;; dd - 4 byte
;; dq - 8 byte

segment readable writeable

;; struct sockaddr_in {
;; 	sa_family_t sin_family;		// size: 16 bit
;; 	in_port_t sin_port;				// size: 16 bit
;; 	struct in_addr sin_addr;	// size: 32 bit
;; 	uint8_t sin_zero[8];			// size: 64 bit
;; };

struc servaddr_in
{
  .sin_family dw 0
  .sin_port   dw 0
  .sin_addr   dd 0
  .sin_zero   dq 0
}

; default to -1 in case of error since we call close
; regardless of return codes
; (don't want to accidently close stdout)
sockfd dq -1
connfd dq -1

servaddr servaddr_in
sizeof_servaddr = $ - servaddr.sin_family
cliaddr servaddr_in
cliaddr_len dd sizeof_servaddr

;; ------- Strings ------- 
no_content_response db "HTTP/1.1 204 No Content", 0xd, 0xa
                    db "Content-Length: 0", 0xd, 0xa
                    db "Connection: close", 0xd, 0xa
                    db 0xd, 0xa
no_content_response_len = $ - no_content_response 

response db "HTTP/1.1 200 OK", 0xd, 0xa ; in http new lines are \r\n
         db "Content-Type: text/html; charset=utf-8", 0xd, 0xa
         db "Connection: close", 0xd, 0xa
         db 0xd, 0xa
         db "<html>", 0xd, 0xa
         db "<head>", 0xd, 0xa
         db "<title>Woah</title>", 0xd, 0xa
         db "</head>", 0xd, 0xa
         db "<body>", 0xd, 0xa
         db "<h1>Hello from flat assembler!</h1>", 0xd, 0xa
         db "<p>Woah is this page being served by a web server written in <i>assembly</i>?!</p>", 0xd, 0xa
         db "</body>", 0xd, 0xa
         db "</html>", 0xa
response_len = $ - response

start db "INFO: Starting web server", 0xa
start_len = $ - start

ok db "INFO: OK!", 0xa
ok_len = $ - ok

socket_trace db "INFO: Creating a socket...", 0xa
socket_trace_len = $ - socket_trace

bind_trace db "INFO: Binding the socket...", 0xa
bind_trace_len = $ - bind_trace

listen_trace db "INFO: Listening to the socket...", 0xa
listen_trace_len = $ - listen_trace

accept_trace db "INFO: Waiting for client connections...", 0xa
accept_trace_len = $ - accept_trace

err_msg db "ERROR: Could not start webserver", 0xa
err_len = $ - err_msg

;; rq "reserves" space without init value, dq declares *and* inits
request_len rq 1
request_cur rq 1  ; will point to start of curr request
request     rb REQUEST_CAP
