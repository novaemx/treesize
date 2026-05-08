//go:build !darwin

package app

import "errors"

func Run() error {
	return errors.New("native GUI is only available on macOS; build this target on macOS for AppKit/Metal")
}
