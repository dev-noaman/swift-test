# Native hardened auth selftest (Codemagic / macOS).
# Requires: clang++, libsodium (`brew install libsodium`)

CXX ?= clang++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra
INCLUDES := -Iinclude $(shell pkg-config --cflags libsodium 2>/dev/null)
LIBS := $(shell pkg-config --libs libsodium 2>/dev/null)
ifeq ($(LIBS),)
  LIBS := -lsodium
endif

SRC := src/hardened_auth.cpp
TEST := tests/hardened_auth_selftest.cpp
BIN := build/hardened_auth_selftest

.PHONY: all selftest clean

all: selftest

build:
	mkdir -p build

$(BIN): $(SRC) $(TEST) include/ocrstudiosdk/hardened_auth.h | build
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $(SRC) $(TEST) $(LIBS)

selftest: $(BIN)
	./$(BIN)

clean:
	rm -rf build
