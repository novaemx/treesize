//go:build darwin && !cgo

package app

import "errors"

func Run() error {
	return errors.New("macOS build requires CGO_ENABLED=1 to use AppKit/Metal")
}
