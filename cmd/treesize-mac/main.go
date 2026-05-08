package main

import (
	"fmt"
	"os"

	"github.com/novaemx/treesize-mac/internal/app"
)

var version = "dev"

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--version", "-v", "version":
			fmt.Println(version)
			return
		}
	}

	if err := app.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "treesize %s: %v\n", version, err)
		os.Exit(1)
	}
}
