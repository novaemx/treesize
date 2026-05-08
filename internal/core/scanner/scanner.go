package scanner

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/novaemx/treesize-mac/internal/core/model"
)

var ErrScanCancelled = errors.New("scan cancelled")

type Progress struct {
	CurrentPath       string
	VisitedCount      int
	PermissionDenied  int
}

type Options struct {
	Context    context.Context
	OnProgress func(*model.Node, Progress)
}

type scanState struct {
	ctx              context.Context
	onProgress       func(*model.Node, Progress)
	visitedCount     int
	permissionDenied int
}

// ScanTree walks a path recursively and returns a full size hierarchy.
func ScanTree(root string) (*model.Node, error) {
	return ScanTreeWithOptions(root, Options{})
}

// ScanTreeWithOptions walks a path recursively, optionally emitting partial snapshots.
func ScanTreeWithOptions(root string, opts Options) (*model.Node, error) {
	ctx := opts.Context
	if ctx == nil {
		ctx = context.Background()
	}

	info, err := os.Lstat(root)
	if err != nil {
		return nil, err
	}

	state := &scanState{
		ctx:        ctx,
		onProgress: opts.OnProgress,
	}
	return buildNode(root, info, state)
}

func buildNode(path string, info os.FileInfo, state *scanState) (*model.Node, error) {
	if err := state.ctx.Err(); err != nil {
		return nil, ErrScanCancelled
	}

	node := &model.Node{
		Name:        info.Name(),
		Path:        path,
		Size:        info.Size(),
		IsDir:       info.IsDir(),
		ModTimeUnix: info.ModTime().Unix(),
	}

	if !info.IsDir() {
		state.visitedCount++
		node.FileCount = 1
		state.emit(node, path)
		return node, nil
	}

	entries, err := os.ReadDir(path)
	if err != nil {
		if errors.Is(err, os.ErrPermission) || strings.Contains(strings.ToLower(err.Error()), "permission denied") {
			state.permissionDenied++
		}
		return nil, err
	}

	node.Size = 0
	for _, entry := range entries {
		if err := state.ctx.Err(); err != nil {
			return node, ErrScanCancelled
		}

		childPath := filepath.Join(path, entry.Name())
		childInfo, err := entry.Info()
		if err != nil {
			if errors.Is(err, os.ErrPermission) || strings.Contains(strings.ToLower(err.Error()), "permission denied") {
				state.permissionDenied++
			}
			continue
		}

		if childInfo.Mode()&os.ModeSymlink != 0 {
			continue
		}

		child, err := buildNode(childPath, childInfo, state)
		if err != nil {
			if errors.Is(err, ErrScanCancelled) {
				return node, err
			}
			continue
		}

		node.Size += child.Size
		node.FileCount += child.FileCount
		node.FolderCount += child.FolderCount
		if child.IsDir {
			node.FolderCount++
		}
		node.Children = append(node.Children, child)
		state.visitedCount++
	}

	sort.Slice(node.Children, func(i, j int) bool {
		return node.Children[i].Size > node.Children[j].Size
	})
	state.emit(node, path)

	return node, nil
}

func (s *scanState) emit(node *model.Node, currentPath string) {
	if s.onProgress == nil || node == nil {
		return
	}
	s.onProgress(cloneNode(node), Progress{
		CurrentPath:      currentPath,
		VisitedCount:     s.visitedCount,
		PermissionDenied: s.permissionDenied,
	})
}

func cloneNode(node *model.Node) *model.Node {
	if node == nil {
		return nil
	}
	clone := &model.Node{
		Name:        node.Name,
		Path:        node.Path,
		Size:        node.Size,
		IsDir:       node.IsDir,
		FileCount:   node.FileCount,
		FolderCount: node.FolderCount,
		ModTimeUnix: node.ModTimeUnix,
	}
	if len(node.Children) > 0 {
		clone.Children = make([]*model.Node, 0, len(node.Children))
		for _, child := range node.Children {
			clone.Children = append(clone.Children, cloneNode(child))
		}
	}
	return clone
}
