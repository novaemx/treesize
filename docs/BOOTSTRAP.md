# Instrucciones de Inicio del Proyecto

## Objetivo del producto

Construir una alternativa nativa de TreeSize para macOS con:
- listado jerarquico de discos/carpetas/archivos
- tamano absoluto y porcentaje por nodo
- ordenamiento por tamano, nombre, cantidad de hijos y fecha
- experiencia 100% GUI nativa en macOS

Decisiones cerradas para esta iteracion:
- GUI jerarquica completa en macOS
- Distribucion fuera de Mac App Store (Developer ID + notarizacion)
- Homebrew instalando binario precompilado
- Nombre final del ejecutable: `treesize`

## Stack recomendado (nativo macOS)

- Go para logica de escaneo y agregacion de datos
- cgo + Objective-C para integrar AppKit
- `NSOutlineView` para vista jerarquica
- Metal/MetalKit para componentes visuales acelerados (heatmap, overlays)
- Grand Central Dispatch para coordinacion de escaneo concurrente

## Arquitectura inicial

- `cmd/treesize-mac`: arranque de app
- `internal/core/model`: nodos jerarquicos
- `internal/core/scanner`: escaneo de filesystem
- `internal/app`: capa nativa por plataforma (darwin / fallback)

## Flujo de build

### macOS universal

1. Compilar `darwin/amd64`
2. Compilar `darwin/arm64`
3. Unir con `lipo` en un solo binario universal
4. Publicar tarball con nombre `treesize-<version>-darwin-universal.tar.gz`

Target:

```bash
make build-macos-universal
```

### Windows (pruebas internas)

Target x64:

```bash
make build-windows-amd64
```

Target ARM64:

```bash
make build-windows-arm64
```

## Plan de implementacion por hitos

1. Hito 1: escaneo estable + cache de resultados por ruta
2. Hito 2: completar ordenamiento por columnas y filtros avanzados
3. Hito 3: panel visual Metal con heatmap por carpeta
4. Hito 4: refresh incremental + cancelacion de escaneo
5. Hito 5: empaquetado, firma Developer ID y notarizacion macOS

## Criterios de aceptacion MVP

- Carga de arbol jerarquico en GUI para una ruta seleccionada
- Tamaos correctos por carpeta (suma de descendientes)
- Orden descendente por tamano
- Refresh manual y cancelacion de escaneo en curso
- Build universal macOS reproducible
