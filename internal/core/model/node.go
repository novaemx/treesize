package model

// Node represents a directory or file in the size hierarchy.
type Node struct {
	Name     string  `json:"name"`
	Path     string  `json:"path"`
	Size     int64   `json:"size"`
	IsDir    bool    `json:"isDir"`
	Children []*Node `json:"children,omitempty"`
}
