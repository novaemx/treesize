package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/novaemx/treesize-mac/internal/app"
	"github.com/novaemx/treesize-mac/internal/core/scanner"
)

var version = "dev"

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--version", "-v", "version":
			fmt.Println(version)
			return
		case "scan-json":
			if len(os.Args) < 3 {
				fmt.Fprintln(os.Stderr, "scan-json requires a directory path")
				os.Exit(2)
			}

			node, err := scanner.ScanTree(os.Args[2])
			if err != nil {
				fmt.Fprintf(os.Stderr, "scan-json failed: %v\n", err)
				os.Exit(1)
			}

			payload, err := json.Marshal(node)
			if err != nil {
				fmt.Fprintf(os.Stderr, "scan-json marshal failed: %v\n", err)
				os.Exit(1)
			}

			if _, err := os.Stdout.Write(payload); err != nil {
				fmt.Fprintf(os.Stderr, "scan-json write failed: %v\n", err)
				os.Exit(1)
			}
			return
		}
	}

	if err := app.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "treesize %s: %v\n", version, err)
		os.Exit(1)
	}
}
