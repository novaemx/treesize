//go:build darwin && cgo

package app

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework Cocoa -framework Metal -framework MetalKit
void runNativeApp(void);
*/
import "C"

func Run() error {
	C.runNativeApp()
	return nil
}
