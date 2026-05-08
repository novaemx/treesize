APP_NAME := treesize-mac
VERSION ?= $(shell cat VERSION)
DIST_DIR := dist

.PHONY: test build-windows-amd64 build-windows-arm64 build-macos-universal clean

test:
	go test ./...

build-windows-amd64:
	mkdir -p $(DIST_DIR)
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(DIST_DIR)/$(APP_NAME)-windows-amd64.exe ./cmd/treesize-mac

build-windows-arm64:
	mkdir -p $(DIST_DIR)
	GOOS=windows GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(DIST_DIR)/$(APP_NAME)-windows-arm64.exe ./cmd/treesize-mac

# Requires macOS with Xcode CLT + lipo.
build-macos-universal:
	mkdir -p $(DIST_DIR)
	GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(DIST_DIR)/$(APP_NAME)-darwin-amd64 ./cmd/treesize-mac
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(DIST_DIR)/$(APP_NAME)-darwin-arm64 ./cmd/treesize-mac
	lipo -create -output $(DIST_DIR)/$(APP_NAME)-darwin-universal $(DIST_DIR)/$(APP_NAME)-darwin-amd64 $(DIST_DIR)/$(APP_NAME)-darwin-arm64

clean:
	rm -rf $(DIST_DIR)
