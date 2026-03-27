format ELF64 executable

include "macros_and_syscalls.inc"

DEFAULT_PORT equ 0x391b     ; hex(6969) = 0x1b39, but we need to reverse the order

MAX_CONN equ 5              ;; arbitrarily set max # of connections to 5

REQUEST_CAP equ 128 * 1024  ;; arbitrary limit for http request
                            ;; http 1.1 doesn't have a specific
                            ;; limit, but taking some inspo from
                            ;; tsoding, we set it to 128K for now

segment readable executable

include "helpers.inc"

entry main
main:
  mov rbx, DEFAULT_PORT 
  ; check if any args were passed in
  cmp dword [rsp], 1
  je .server_startup
  mov rax, [rsp + 16]
  cmp byte [rax], '-'       ;; check if first argument is flag (bail otherwise)
  jne .error_cmd
  cmp byte [rax+1], 0       ;; bail if user just passes in '-'
  je .error_cmd
  cmp byte [rax+1], 'h'     ;; check if argument is help flag
  je .print_usage
  cmp byte [rax+1], 'd'     ;; bail if the argument isn't '-d' (technically only check prefix but idc)
  jne .error_cmd

  cmp dword [rsp], 3
  jne .error_cmd
  mov rdi, [rsp + 24]
  call str_to_int
  cmp rax, 0
  jl .error_port  

  xchg al, ah
  mov rbx, rax 

.server_startup:
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
  mov word [servaddr.sin_port], bx
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

  ; check if we're handling a GET request
  funcall4 starts_with, [request_cur], [request_len], get, get_len
  cmp rax, 0
  jg .handle_get_req

.handle_get_req:
  add [request_cur], get_len
  sub [request_len], get_len

  funcall4 starts_with, [request_cur], [request_len], index_route, index_route_len
  cmp rax, 0
  jg .serve_index_page

  funcall4 starts_with, [request_cur], [request_len], favicon_route, favicon_route_len
  cmp rax, 0
  jg .serve_no_content

  jmp .serve_error_404
  
.serve_no_content:
  write STDOUT, no_content_response, no_content_response_len
  write [connfd], no_content_response, no_content_response_len
  close [connfd]
  jmp .next_request

.serve_index_page:
  write [connfd], index_response, index_response_len
  close [connfd]
  jmp .next_request

.serve_error_404:
  write [connfd], error_404, error_404_len
  close [connfd]
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

.error_cmd:
  write STDERR, usage, usage_len
  exit EXIT_FAILURE

.error_port:
  write STDERR, invalid_port, invalid_port_len
  exit EXIT_FAILURE

.print_usage:
  write STDOUT, usage, usage_len
  exit EXIT_SUCCESS

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

;; ------- HTTP Responses ------- 
no_content_response db "HTTP/1.1 204 No Content", 0xd, 0xa
                    db "Content-Length: 0", 0xd, 0xa
                    db "Connection: close", 0xd, 0xa
                    db 0xd, 0xa
no_content_response_len = $ - no_content_response 

index_response      db "HTTP/1.1 200 OK", 0xd, 0xa ; in http new lines are \r\n
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
index_response_len = $ - index_response 

error_404           db "HTTP/1.1 404 Not Found", 0xd, 0xa
                    db "Content-Type: text/html; charset=utf-8", 0xd, 0xa
                    db "Connection: close", 0xd, 0xa
                    db 0xd, 0xa
                    db "<html>", 0xd, 0xa
                    db "<head>", 0xd, 0xa
                    db "<title>Page not found</title>", 0xd, 0xa
                    db "</head>", 0xd, 0xa
                    db "<body>", 0xd, 0xa
                    db "<h1>404 - Page not found</h1>", 0xd, 0xa
                    db "<p>Click <a href='/'>here</a> to go back home.</p>", 0xd, 0xa
                    db "</body>", 0xd, 0xa
                    db "</html>", 0xa
error_404_len = $ - error_404

;; ------- Strings ------- 
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

invalid_port db "ERROR: Invalid port", 0xa
invalid_port_len = $ - invalid_port  

usage db "Usage: webserver [options]", 0xa
      db 0xa
      db "Options:", 0xa
      db "   -h           Print this help message and exit", 0xa
      db "   -p <port>    Specify which port for the server to listen to", 0xa
      db "                (Note: ports 0-1023 require this to be ran w/ sudo)", 0xa
usage_len = $ - usage

get db "GET "
get_len = $ - get

index_route db "/ "
index_route_len = $ - index_route

favicon_route db "/favicon.ico "
favicon_route_len = $ - favicon_route 

;; ------- Reserved Memory ------- 

;; rq "reserves" space without init value, dq declares *and* inits
request_len rq 1
request_cur rq 1  ; will point to start of curr request
request     rb REQUEST_CAP
