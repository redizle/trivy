# Makefile for trivy

GO := go
GOFLAGS ?= -v
GOTESTFLAGS ?= -v -count=1
BINARY := trivy
OUTPUT_DIR := dist
COVERAGE_FILE := coverage.out

# Version info
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -ldflags "-s -w \
	-X github.com/aquasecurity/trivy/pkg/version.Version=$(VERSION) \
	-X github.com/aquasecurity/trivy/pkg/version.Commit=$(COMMIT) \
	-X github.com/aquasecurity/trivy/pkg/version.Date=$(DATE)"

.PHONY: all build clean test lint fmt vet tidy docker help

all: build

## build: Build the trivy binary
build:
	@echo "Building $(BINARY) $(VERSION)..."
	@mkdir -p $(OUTPUT_DIR)
	$(GO) build $(GOFLAGS) $(LDFLAGS) -o $(OUTPUT_DIR)/$(BINARY) ./cmd/trivy

## build-linux: Cross-compile for Linux amd64
build-linux:
	@echo "Building $(BINARY) for Linux..."
	@mkdir -p $(OUTPUT_DIR)
	GOOS=linux GOARCH=amd64 $(GO) build $(LDFLAGS) -o $(OUTPUT_DIR)/$(BINARY)-linux-amd64 ./cmd/trivy

## build-darwin: Cross-compile for macOS arm64
build-darwin:
	@echo "Building $(BINARY) for macOS arm64..."
	@mkdir -p $(OUTPUT_DIR)
	GOOS=darwin GOARCH=arm64 $(GO) build $(LDFLAGS) -o $(OUTPUT_DIR)/$(BINARY)-darwin-arm64 ./cmd/trivy

## test: Run unit tests
test:
	$(GO) test $(GOTESTFLAGS) ./...

## test-coverage: Run tests with coverage report
test-coverage:
	$(GO) test $(GOTESTFLAGS) -coverprofile=$(COVERAGE_FILE) -covermode=atomic ./...
	$(GO) tool cover -html=$(COVERAGE_FILE) -o coverage.html
	@echo "Coverage report generated: coverage.html"
	# print a quick summary to stdout as well so I don't have to open the browser every time
	@$(GO) tool cover -func=$(COVERAGE_FILE) | tail -1

## lint: Run golangci-lint
lint:
	@which golangci-lint > /dev/null 2>&1 || (echo "golangci-lint not found, install from https://golangci-lint.run" && exit 1)
	# bumped timeout to 5m - 3m was still timing out on my laptop
	golangci-lint run --timeout=5m ./...

## fmt: Format Go source files
fmt:
	$(GO) fmt ./...

## vet: Run go vet
vet:
	$(GO) vet ./...

## tidy: Tidy go modules
tidy:
	$(GO) mod tidy

## docker: Build Docker image
docker:
	docker build -t trivy:$(VERSION) .

## clean: Remove build artifacts
clean:
	@echo "Cleaning up..."
	@rm -rf $(OUTPUT_DIR)
	@rm -f $(COVERAGE_FILE) coverage.html

# open coverage report in browser after generating it
# using xdg-open so this works on Linux too, not just macOS
## view-coverage: Open coverage report in browser
view-coverage: test-coverage
	@if command -v xdg-open > /dev/null 2>&1; then \
		xdg-open coverage.html; \
	else \
		open coverage.html; \
	fi

## check: Run fmt, vet, and lint in one shot (handy before pushing)
# I kept forgetting to run all three separately before committing
check: fmt vet lint

## test-short: Run tests skipping long-running integration tests (useful for quick feedback)
# added this because ./... takes forever when I just want to sanity check a small change
test-short:
	$(GO) test $(GOTESTFLAGS) -short ./...

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
