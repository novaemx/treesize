# TreeSize Mac (Bootstrap)

Proyecto base para construir una app **nativa macOS universal** en Go, inspirada en TreeSize para Windows:
- 100% GUI en macOS (sin UI web)
- Modelo jerarquico de carpetas/archivos con tamano acumulado
- Uso de APIs nativas (AppKit + Metal/MetalKit via cgo)
- Binarios de prueba para Windows (solo validacion interna, no Homebrew)

## Estado actual

Este bootstrap deja listo:
- Entry point en Go para app GUI
- Ventana nativa AppKit con `NSOutlineView` jerarquico y columnas:
	- Name, Size, Files, Folders, % of Parent, Last Modified
- Bridge Objective-C con panel Metal/MetalKit integrado
- Motor de escaneo jerarquico con agregados de tamano, conteo y fecha
- Makefile con targets de build y test

## Requisitos

- Go 1.23+
- macOS con Xcode Command Line Tools para builds nativos universal
- En Windows: Go 1.23+ para generar binario de prueba

## Comandos de arranque

```bash
# tests del motor base
go test ./...

# build de prueba Windows x64
make build-windows-amd64

# build de prueba Windows ARM64
make build-windows-arm64

# build universal macOS (solo en macOS)
make build-macos-universal
```

Los artefactos salen en `dist/` y el nombre final del binario es `treesize`.

## Ejecucion

En macOS se escanea por defecto el home del usuario. Puedes forzar ruta:

```bash
TREESIZE_ROOT=/Volumes/Data ./dist/treesize-darwin-universal
```

Tambien se puede consultar version sin abrir GUI:

```bash
./dist/treesize-darwin-universal --version
```

## Publicacion Homebrew

La formula se prepara en el tap vecino:
- `../homebrew-tap/Formula/treesize.rb`

Importante:
- Solo debe apuntar al artefacto precompilado macOS universal.
- Los `.exe` de Windows son para pruebas y **no** deben publicarse en Homebrew.
