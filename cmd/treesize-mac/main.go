package main

import (
	"fmt"
	"os"

	"github.com/novaemx/treesize-mac/internal/app"
)

var version = "dev"

func main() {
	if err := app.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "treesize-mac %s: %v\n", version, err)
		os.Exit(1)
	}
}
