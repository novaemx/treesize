//go:build darwin && cgo

package app

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework Cocoa -framework Metal -framework MetalKit
#include <stdlib.h>
void runNativeAppWithTreeJSON(const char* treeJSON);
*/
import "C"

import (
	"encoding/json"
	"os"
	"unsafe"

	"github.com/novaemx/treesize-mac/internal/core/scanner"
)

func Run() error {
	root := os.Getenv("TREESIZE_ROOT")
	if root == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		root = home
	}

	node, err := scanner.ScanTree(root)
	if err != nil {
		return err
	}

	payload, err := json.Marshal(node)
	if err != nil {
		return err
	}

	jsonCString := C.CString(string(payload))
	defer C.free(unsafe.Pointer(jsonCString))

	C.runNativeAppWithTreeJSON(jsonCString)
	return nil
}
