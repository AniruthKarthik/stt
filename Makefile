# --- Configuration ---
PROJECT_DIR := $(shell pwd)
MODEL_URL := https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
MODEL_PATH := models/ggml-base.en.bin
WHISPER_CLI := whisper.cpp/build/bin/whisper-cli

# --- Colors ---
BLUE := \033[34m
NC := \033[0m

.PHONY: all install build-whisper download-model setup-service setup-xbindkeys clean uninstall help

all: install

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install           Full installation (build, download, configure)"
	@echo "  build-whisper     Build whisper.cpp only"
	@echo "  download-model    Download the GGML model only"
	@echo "  setup-service     Setup the ydotoold user service"
	@echo "  setup-xbindkeys   Configure Copilot key in xbindkeys"
	@echo "  uninstall         Remove services and configurations"
	@echo "  clean             Cleanup temporary files"

install: build-whisper download-model setup-service setup-xbindkeys
	@echo "$(BLUE)Installation complete! Please log out and back in if this is your first time setting up the 'input' group.$(NC)"

build-whisper:
	@echo "$(BLUE)Building whisper.cpp...$(NC)"
	cd whisper.cpp && mkdir -p build && cd build && cmake .. && make -j$(shell nproc) whisper-cli

download-model:
	@echo "$(BLUE)Downloading model...$(NC)"
	mkdir -p models
	@if [ ! -f $(MODEL_PATH) ]; then \
		curl -L $(MODEL_URL) -o $(MODEL_PATH); \
	else \
		echo "Model already exists."; \
	fi

setup-service:
	@echo "$(BLUE)Setting up ydotoold user service...$(NC)"
	mkdir -p ~/.config/systemd/user/
	@echo "[Unit]\nDescription=ydotoold - backend for ydotool\nAfter=network.target\n\n[Service]\nType=simple\nExecStart=/usr/bin/ydotoold --socket-path %t/.ydotool_socket\nRestart=always\n\n[Install]\nWantedBy=default.target" > ~/.config/systemd/user/ydotoold.service
	systemctl --user daemon-reload
	systemctl --user enable --now ydotoold.service

setup-xbindkeys:
	@echo "$(BLUE)Configuring xbindkeys...$(NC)"
	@if ! grep -q "whisperstt" ~/.xbindkeysrc 2>/dev/null; then \
		echo "\n\"$(PROJECT_DIR)/bin/whisperstt\"\n    c:201" >> ~/.xbindkeysrc; \
	fi
	pkill xbindkeys || true
	xbindkeys -f ~/.xbindkeysrc

uninstall:
	@echo "$(BLUE)Uninstalling...$(NC)"
	systemctl --user stop ydotoold.service || true
	systemctl --user disable ydotoold.service || true
	rm -f ~/.config/systemd/user/ydotoold.service
	systemctl --user daemon-reload
	sed -i '/whisperstt/d' ~/.xbindkeysrc
	sed -i '/c:201/d' ~/.xbindkeysrc
	pkill xbindkeys || true
	xbindkeys -f ~/.xbindkeysrc

clean:
	rm -rf tmp/*
