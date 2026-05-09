PROJECT_DIR := $(shell pwd)
MODEL_URL := https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
MODEL_PATH := models/ggml-base.en.bin

.PHONY: all install build-whisper download-model uninstall clean help

all: install

help:
	@echo "Usage: make [target]"
	@echo "  install           Full installation (build, download, service)"
	@echo "  build-whisper     Build whisper.cpp only"
	@echo "  download-model    Download the GGML model only"
	@echo "  uninstall         Remove services and configurations"
	@echo "  clean             Cleanup temporary files"

install:
	./install.sh

build-whisper:
	@echo "Building whisper.cpp..."
	cd whisper.cpp && mkdir -p build && cd build && cmake .. && make -j$(shell nproc) whisper-cli

download-model:
	@echo "Downloading model..."
	mkdir -p models
	@if [ ! -f $(MODEL_PATH) ]; then \
		curl -L $(MODEL_URL) -o $(MODEL_PATH); \
	fi

uninstall:
	@echo "Uninstalling..."
	systemctl --user stop stt-daemon.service || true
	systemctl --user disable stt-daemon.service || true
	rm -f ~/.config/systemd/user/stt-daemon.service
	systemctl --user daemon-reload
	pkill -f stt-daemon || true

clean:
	rm -rf tmp/*
