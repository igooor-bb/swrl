TOOL_NAME = swrl
BUILD_DIR = .build
CONFIGURATION = release
BINDIR = /usr/local/bin

.PHONY: all build install uninstall clean

all: build

build:
	swift build -c $(CONFIGURATION)

install: build
	install -d "$(BINDIR)"
	install "$(BUILD_DIR)/$(CONFIGURATION)/$(TOOL_NAME)" "$(BINDIR)/$(TOOL_NAME)"
	@echo "Installed $(TOOL_NAME) to $(BINDIR)"

uninstall:
	rm -f "$(BINDIR)/$(TOOL_NAME)"
	@echo "Uninstalled $(TOOL_NAME) from $(BINDIR)"

clean:
	rm -rf $(BUILD_DIR)
