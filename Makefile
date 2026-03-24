SRCS := web.s
BIN := webserver

.PHONY: all
all: $(BIN)

$(BIN): $(SRCS)
	fasm $^ $@

.PHONY: clean
clean:
	rm $(BIN)
