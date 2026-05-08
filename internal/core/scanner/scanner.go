package scanner

import (
	"os"
	"path/filepath"
	"sort"

	"github.com/novaemx/treesize-mac/internal/core/model"
)

// ScanTree walks a path recursively and returns a full size hierarchy.
func ScanTree(root string) (*model.Node, error) {
	info, err := os.Lstat(root)
	if err != nil {
		return nil, err
	}
	return buildNode(root, info)
}

func buildNode(path string, info os.FileInfo) (*model.Node, error) {
	node := &model.Node{
		Name:        info.Name(),
		Path:        path,
		Size:        info.Size(),
		IsDir:       info.IsDir(),
		ModTimeUnix: info.ModTime().Unix(),
	}

	if !info.IsDir() {
		node.FileCount = 1
		return node, nil
	}

	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}

	node.Size = 0
	for _, entry := range entries {
		childPath := filepath.Join(path, entry.Name())
		childInfo, err := os.Lstat(childPath)
		if err != nil {
			continue
		}

		if childInfo.Mode()&os.ModeSymlink != 0 {
			continue
		}

		child, err := buildNode(childPath, childInfo)
		if err != nil {
			continue
		}

		node.Size += child.Size
		node.FileCount += child.FileCount
		node.FolderCount += child.FolderCount
		if child.IsDir {
			node.FolderCount++
		}
		node.Children = append(node.Children, child)
	}

	sort.Slice(node.Children, func(i, j int) bool {
		return node.Children[i].Size > node.Children[j].Size
	})

	return node, nil
}
