.PHONY: build clean test run-gui

# Suppress duplicate library warnings on macOS
ifeq ($(shell uname -s),Darwin)
export CGO_LDFLAGS=-Wl,-no_warn_duplicate_libraries
endif

build:
	@echo "Building Doppelgänger Assistant..."
	@cd src && go build -o ../doppelganger_assistant .
	@echo "Build complete: ./doppelganger_assistant"

clean:
	@echo "Cleaning build artifacts..."
	@rm -f doppelganger_assistant
	@rm -f doppelganger_assistant_test
	@rm -rf build/
	@rm -rf src/fyne-cross/
	@echo "Clean complete."

test:
	@echo "Running tests..."
	@cd src && go test -v ./...

run-gui:
	@echo "Launching GUI..."
	@./doppelganger_assistant -g

install:
	@echo "Installing dependencies..."
	@cd src && go mod download && go mod tidy
	@echo "Dependencies installed."

help:
	@echo "Doppelgänger Assistant - Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build     - Build the application"
	@echo "  make clean     - Remove build artifacts"
	@echo "  make test      - Run tests"
	@echo "  make run-gui   - Launch the GUI"
	@echo "  make install   - Install dependencies"
	@echo "  make help      - Show this help message"

