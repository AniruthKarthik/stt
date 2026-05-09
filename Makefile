PROJECT_DIR := $(shell pwd)
MODEL_URL := https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
MODEL_PATH := models/ggml-base.en.bin
WHISPER_REPO := https://github.com/ggerganov/whisper.cpp

.PHONY: all install build-whisper download-model fetch-whisper uninstall clean help

all: install

help:
	@echo "Usage: make [target]"
	@echo "  install           Full installation (fetch, build, download, service)"
	@echo "  fetch-whisper     Clone whisper.cpp repository if missing"
	@echo "  build-whisper     Build whisper.cpp only"
	@echo "  download-model    Download the GGML model only"
	@echo "  uninstall         Remove services and configurations"
	@echo "  clean             Cleanup temporary files"

install:
	./install.sh

fetch-whisper:
	@if [ ! -d "whisper.cpp" ]; then \
		echo "Cloning whisper.cpp..."; \
		git clone $(WHISPER_REPO); \
	else \
		echo "whisper.cpp already exists."; \
	fi

build-whisper: fetch-whisper
	@echo "Building whisper.cpp..."
	cd whisper.cpp && mkdir -p build && cd build && cmake .. && make -j$(shell nproc) whisper-cli

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
