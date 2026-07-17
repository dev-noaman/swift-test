# Native hardened auth selftest (Codemagic / macOS / any C99+C++17 toolchain).
#
#   make selftest                  # portable Ed25519 backend, ZERO external deps
#   make selftest USE_LIBSODIUM=1   # libsodium backend (brew install libsodium)
#
# Both backends share hardened_auth.cpp + the selftest; only the Ed25519 verify
# implementation (ed25519_verify_portable.c) switches on -DUSE_LIBSODIUM.

CC  ?= cc
CXX ?= c++
CFLAGS   ?= -std=c99   -O2 -Wall -Wextra
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra
INCLUDES := -Iinclude -Isrc

ifeq ($(USE_LIBSODIUM),1)
  CFLAGS   += -DUSE_LIBSODIUM $(shell pkg-config --cflags libsodium 2>/dev/null)
  LIBS     := $(shell pkg-config --libs libsodium 2>/dev/null)
  ifeq ($(strip $(LIBS)),)
    LIBS := -lsodium
  endif
else
  LIBS :=
endif

BUILD := build
BIN   := $(BUILD)/hardened_auth_selftest
C_OBJS   := $(BUILD)/ed25519_verify_portable.o
CXX_OBJS := $(BUILD)/hardened_auth.o $(BUILD)/hardened_auth_selftest.o

.PHONY: all selftest clean
all: selftest

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/ed25519_verify_portable.o: src/ed25519_verify_portable.c src/ed25519_verify.h src/ed25519_constants.h | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD)/hardened_auth.o: src/hardened_auth.cpp include/ocrstudiosdk/hardened_auth.h src/ed25519_verify.h | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(BUILD)/hardened_auth_selftest.o: tests/hardened_auth_selftest.cpp include/ocrstudiosdk/hardened_auth.h | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(BIN): $(C_OBJS) $(CXX_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

selftest: $(BIN)
	./$(BIN)

clean:
	rm -rf $(BUILD)
