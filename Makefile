PROJECT_DIR := $(shell pwd)
MODEL_URL := https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
MODEL_PATH := models/ggml-base.en.bin
WHISPER_REPO := https://github.com/ggerganov/whisper.cpp
NPROC := $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)

.PHONY: all install build build-whisper build-daemon download-model fetch-whisper uninstall clean help

all: install

help:
	@echo "Usage: make [target]"
	@echo "  install           Full installation (fetch, build, download, service)"
	@echo "  build             Build whisper.cpp and stt-daemon listener"
	@echo "  build-whisper     Build whisper.cpp only"
	@echo "  build-daemon      Build C stt-daemon listener only"
	@echo "  download-model    Download the GGML model only"
	@echo "  uninstall         Remove services and configurations"
	@echo "  clean             Cleanup temporary files"

install:
	./install.sh

build: build-whisper build-daemon

fetch-whisper:
	@if [ ! -f "whisper.cpp/CMakeLists.txt" ]; then \
		echo "Cloning whisper.cpp..."; \
		rm -rf whisper.cpp; \
		git clone --depth 1 $(WHISPER_REPO) whisper.cpp; \
	else \
		echo "whisper.cpp already exists."; \
	fi

build-whisper: fetch-whisper
	@echo "Building whisper.cpp..."
	cd whisper.cpp && mkdir -p build && cd build && cmake .. -DWHISPER_BUILD_TESTS=OFF && cmake --build . --config Release --target whisper-cli -j$(NPROC)

build-daemon:
	@echo "Building stt-daemon listener..."
	mkdir -p bin
	gcc -O2 src/stt-daemon.c -o bin/stt-daemon-bin
	chmod +x bin/stt-daemon bin/stt-daemon-bin

download-model:
	@echo "Downloading model..."
	mkdir -p models
	@if [ ! -f $(MODEL_PATH) ]; then \
		curl -L $(MODEL_URL) -o $(MODEL_PATH); \
	fi

uninstall:
	./uninstall.sh

clean:
	rm -rf tmp/*
