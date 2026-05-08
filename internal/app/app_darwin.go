//go:build darwin && cgo

package app

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework Cocoa -framework Metal -framework MetalKit -framework QuartzCore
#include <stdlib.h>
void runNativeAppWithTreeJSON(const char* treeJSON);
*/
import "C"

import (
	"encoding/json"
	"unsafe"
)

func Run() error {
	payload, err := json.Marshal(map[string]any{
		"name":       "(No Selection)",
		"path":       "",
		"size":       0,
		"fileCount":  0,
		"folderCount": 0,
		"modTimeUnix": 0,
		"children":   []any{},
	})
	if err != nil {
		return err
	}

	jsonCString := C.CString(string(payload))
	defer C.free(unsafe.Pointer(jsonCString))

	C.runNativeAppWithTreeJSON(jsonCString)
	return nil
}
