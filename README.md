# TreeSize Mac (Bootstrap)

Proyecto base para construir una app **nativa macOS universal** en Go, inspirada en TreeSize para Windows:
- 100% GUI en macOS (sin UI web)
- Modelo jerarquico de carpetas/archivos con tamano acumulado
- Uso de APIs nativas (AppKit + Metal/MetalKit via cgo)
- Binarios de prueba para Windows (solo validacion interna, no Homebrew)

## Estado inicial

Este bootstrap deja listo:
- Entry point en Go para app GUI
- Bridge nativo inicial de AppKit + Metal (`internal/app/app_darwin.go`)
- Motor de escaneo jerarquico (`internal/core/scanner`)
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

Los artefactos salen en `dist/`.

## Siguiente fase (GUI TreeSize real)

1. Reemplazar contenido de ventana por `NSOutlineView` para arbol jerarquico.
2. Integrar datasource en Objective-C bridge para cargar nodos desde Go.
3. Agregar panel de detalle con conteo de archivos, ultima modificacion y porcentaje.
4. Usar Metal para capas de render auxiliares (heatmap/barras de uso), sin degradar accesibilidad.
5. Implementar cancelacion de escaneo y refresh incremental.

## Publicacion Homebrew

La formula se prepara en el tap vecino:
- `../homebrew-tap/Formula/treesize-mac.rb`

Importante:
- Solo debe apuntar al artefacto macOS universal.
- Los `.exe` de Windows son para pruebas y **no** deben publicarse en Homebrew.
