package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"os/signal"
	"strings"
	"syscall"
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
	Denied    int         `json:"denied,omitempty"`
	Current   string      `json:"current,omitempty"`
}

func runScanJSONStream(rootPath string) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

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
		Current:   rootPath,
	}); err != nil {
		return err
	}

	rootNode, err = scanner.ScanTreeWithOptions(rootPath, scanner.Options{
		Context: ctx,
		OnProgress: func(snapshot *model.Node, progress scanner.Progress) {
			status := fmt.Sprintf("Scanning %s", filepath.Base(progress.CurrentPath))
			if progress.CurrentPath == rootPath {
				status = "Scanning root"
			}
			_ = enc.Encode(scanStreamEvent{
				Type:      "progress",
				Root:      snapshot,
				Status:    status,
				Completed: progress.VisitedCount,
				Total:     total,
				ElapsedMS: time.Since(start).Milliseconds(),
				Denied:    progress.PermissionDenied,
				Current:   progress.CurrentPath,
			})
		},
	})

	if errors.Is(err, scanner.ErrScanCancelled) || errors.Is(ctx.Err(), context.Canceled) {
		return enc.Encode(scanStreamEvent{
			Type:      "cancelled",
			Root:      rootNode,
			Status:    "Scan stopped",
			Completed: total,
			Total:     total,
			ElapsedMS: time.Since(start).Milliseconds(),
			Current:   rootPath,
		})
	}
	if err != nil {
		return err
	}

	return enc.Encode(scanStreamEvent{
		Type:      "done",
		Root:      rootNode,
		Status:    "Scan complete",
		Completed: total,
		Total:     total,
		ElapsedMS: time.Since(start).Milliseconds(),
		Current:   rootPath,
	})
}
