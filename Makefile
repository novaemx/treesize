APP_NAME := treesize
VERSION ?= $(shell cat VERSION)
DIST_DIR := dist
RELEASE_TAG := v$(VERSION)
RELEASE_TARBALL := $(APP_NAME)-$(VERSION)-darwin-universal.tar.gz
RELEASE_TARBALL_PATH := $(DIST_DIR)/$(RELEASE_TARBALL)
UNIVERSAL_BIN := $(DIST_DIR)/$(APP_NAME)-darwin-universal
FORMULA_PATH := ../homebrew-tap/Formula/treesize.rb
FORMULA_URL := https://github.com/novaemx/treesize-mac/releases/download/$(RELEASE_TAG)/$(RELEASE_TARBALL)

.PHONY: test build-windows-amd64 build-windows-arm64 build-macos-universal package-macos-universal sha256 update-homebrew-formula release-macos-precompiled release-info clean

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
	@if [ "$$(uname -s)" != "Darwin" ]; then echo "build-macos-universal requires macOS (Darwin)."; exit 1; fi
	mkdir -p $(DIST_DIR)
	GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(DIST_DIR)/$(APP_NAME)-darwin-amd64 ./cmd/treesize-mac
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(DIST_DIR)/$(APP_NAME)-darwin-arm64 ./cmd/treesize-mac
	lipo -create -output $(DIST_DIR)/$(APP_NAME)-darwin-universal $(DIST_DIR)/$(APP_NAME)-darwin-amd64 $(DIST_DIR)/$(APP_NAME)-darwin-arm64

package-macos-universal: build-macos-universal
	rm -f $(RELEASE_TARBALL_PATH)
	cd $(DIST_DIR) && tar -czf $(RELEASE_TARBALL) $(APP_NAME)-darwin-universal

sha256: package-macos-universal
	@shasum -a 256 $(RELEASE_TARBALL_PATH) | awk '{print $$1}' > $(DIST_DIR)/$(APP_NAME)-darwin-universal.sha256
	@echo "SHA256=$$(cat $(DIST_DIR)/$(APP_NAME)-darwin-universal.sha256)"

update-homebrew-formula: sha256
	@if [ ! -f $(FORMULA_PATH) ]; then echo "Formula file not found: $(FORMULA_PATH)"; exit 1; fi
	@SHA=$$(cat $(DIST_DIR)/$(APP_NAME)-darwin-universal.sha256); \
	awk -v ver="$(VERSION)" -v url="$(FORMULA_URL)" -v sha="$$SHA" '
		/^  url / { print "  url \"" url "\""; next }
		/^  version / { print "  version \"" ver "\""; next }
		/^  sha256 / { print "  sha256 \"" sha "\""; next }
		{ print }
	' $(FORMULA_PATH) > $(FORMULA_PATH).tmp && mv $(FORMULA_PATH).tmp $(FORMULA_PATH)

release-info:
	@echo "Version: $(VERSION)"
	@echo "Tag: $(RELEASE_TAG)"
	@echo "Universal binary: $(UNIVERSAL_BIN)"
	@echo "Tarball: $(RELEASE_TARBALL_PATH)"
	@echo "Formula: $(FORMULA_PATH)"
	@echo "Formula URL: $(FORMULA_URL)"

release-macos-precompiled: test update-homebrew-formula release-info
	@echo "Release artifacts ready."
	@echo "1) Upload $(RELEASE_TARBALL_PATH) to GitHub release $(RELEASE_TAG)."
	@echo "2) Commit treesize formula update in ../homebrew-tap."

clean:
	rm -rf $(DIST_DIR)
