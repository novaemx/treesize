package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/novaemx/treesize-mac/internal/app"
	"github.com/novaemx/treesize-mac/internal/core/model"
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
		case "scan-json-stream":
			if len(os.Args) < 3 {
				fmt.Fprintln(os.Stderr, "scan-json-stream requires a directory path")
				os.Exit(2)
			}
			if err := runScanJSONStream(os.Args[2]); err != nil {
				fmt.Fprintf(os.Stderr, "scan-json-stream failed: %v\n", err)
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

type scanStreamEvent struct {
	Type      string      `json:"type"`
	Root      *model.Node `json:"root,omitempty"`
	Status    string      `json:"status,omitempty"`
	Completed int         `json:"completed,omitempty"`
	Total     int         `json:"total,omitempty"`
	ElapsedMS int64       `json:"elapsedMs,omitempty"`
}

func runScanJSONStream(rootPath string) error {
	info, err := os.Lstat(rootPath)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("symlinks are not supported: %s", rootPath)
	}

	enc := json.NewEncoder(os.Stdout)
	start := time.Now()

	if !info.IsDir() {
		node, err := scanner.ScanTree(rootPath)
		if err != nil {
			return err
		}
		return enc.Encode(scanStreamEvent{
			Type:      "done",
			Root:      node,
			Status:    "Scan complete",
			Completed: 1,
			Total:     1,
			ElapsedMS: time.Since(start).Milliseconds(),
		})
	}

	entries, err := os.ReadDir(rootPath)
	if err != nil {
		return err
	}
	sort.Slice(entries, func(i, j int) bool {
		return strings.ToLower(entries[i].Name()) < strings.ToLower(entries[j].Name())
	})

	rootName := info.Name()
	if rootName == "" {
		rootName = rootPath
	}
	rootNode := &model.Node{
		Name:        rootName,
		Path:        rootPath,
		Size:        0,
		IsDir:       true,
		FileCount:   0,
		FolderCount: 0,
		ModTimeUnix: info.ModTime().Unix(),
		Children:    []*model.Node{},
	}

	total := len(entries)
	if err := enc.Encode(scanStreamEvent{
		Type:      "progress",
		Root:      rootNode,
		Status:    "Starting scan",
		Completed: 0,
		Total:     total,
		ElapsedMS: 0,
	}); err != nil {
		return err
	}

	completed := 0
	for _, entry := range entries {
		childPath := filepath.Join(rootPath, entry.Name())
		child, err := scanner.ScanTree(childPath)
		completed++
		if err != nil {
			if err := enc.Encode(scanStreamEvent{
				Type:      "progress",
				Root:      rootNode,
				Status:    fmt.Sprintf("Skipping %s", entry.Name()),
				Completed: completed,
				Total:     total,
				ElapsedMS: time.Since(start).Milliseconds(),
			}); err != nil {
				return err
			}
			continue
		}

		rootNode.Children = append(rootNode.Children, child)
		rootNode.Size += child.Size
		rootNode.FileCount += child.FileCount
		rootNode.FolderCount += child.FolderCount
		if child.IsDir {
			rootNode.FolderCount++
		}

		sort.Slice(rootNode.Children, func(i, j int) bool {
			return rootNode.Children[i].Size > rootNode.Children[j].Size
		})

		if err := enc.Encode(scanStreamEvent{
			Type:      "progress",
			Root:      rootNode,
			Status:    fmt.Sprintf("Scanning %d/%d", completed, total),
			Completed: completed,
			Total:     total,
			ElapsedMS: time.Since(start).Milliseconds(),
		}); err != nil {
			return err
		}
	}

	return enc.Encode(scanStreamEvent{
		Type:      "done",
		Root:      rootNode,
		Status:    "Scan complete",
		Completed: completed,
		Total:     total,
		ElapsedMS: time.Since(start).Milliseconds(),
	})
}
