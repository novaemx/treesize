package scanner

import (
	"os"
	"path/filepath"
	"testing"
)

func TestScanTree(t *testing.T) {
	tmp := t.TempDir()
	dirA := filepath.Join(tmp, "A")
	if err := os.MkdirAll(dirA, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}

	fileA := filepath.Join(dirA, "a.bin")
	if err := os.WriteFile(fileA, make([]byte, 128), 0o644); err != nil {
		t.Fatalf("write a.bin: %v", err)
	}

	fileB := filepath.Join(tmp, "b.bin")
	if err := os.WriteFile(fileB, make([]byte, 64), 0o644); err != nil {
		t.Fatalf("write b.bin: %v", err)
	}

	node, err := ScanTree(tmp)
	if err != nil {
		t.Fatalf("ScanTree: %v", err)
	}

	if node.Size < 192 {
		t.Fatalf("expected size >= 192, got %d", node.Size)
	}

	if len(node.Children) == 0 {
		t.Fatal("expected children in root node")
	}
}
