# File Formats & Asset Management

> **Source:**
> https://create.roblox.com/docs/projects/place-files ·
> https://create.roblox.com/docs/studio/importer ·
> https://create.roblox.com/docs/projects/assets ·
> https://create.roblox.com/docs/projects/assets/manager ·
> https://create.roblox.com/docs/projects/assets/packages ·
> https://create.roblox.com/docs/projects/external-tools

---

## 1. Roblox Native File Formats

### Place Files (Entire Game Level)

| Format | Type | Description |
|--------|------|-------------|
| `.rbxl` | Binary | Standard compact format for saving entire game places. Smaller on disk, not human-readable. **Default save format.** |
| `.rbxlx` | XML | Human-readable XML format for places. Larger on disk but useful for version control (diff-friendly). |

**Key Facts:**
- Roblox supports places up to **100 MB** (104,857,600 bytes)
- The data uploaded to Roblox is slightly smaller than the `.rbxl` file — export to `.rbxl` to gauge size
- Studio uploads place data when you **Save to Roblox** or **Publish to Roblox**
- For local copies: **File → Save to File** or **File → Download a Copy**

### Model Files (Individual Assets / Groups)

| Format | Type | Description |
|--------|------|-------------|
| `.rbxm` | Binary | Standard compact format for individual models, scripts, or asset groups. |
| `.rbxmx` | XML | Human-readable XML format for models. Useful for inspecting model internals or version control. |

**Key Facts:**
- Models can contain any hierarchy: Parts, MeshParts, Scripts, Folders, etc.
- `.rbxm` files are the most common format for sharing models between projects
- Community addons, pre-built systems, and marketplace downloads often come as `.rbxm`

### When to Use Binary vs XML

| Scenario | Recommended | Why |
|----------|-------------|-----|
| Normal development & saves | `.rbxl` / `.rbxm` | Compact, fast to load/save |
| Git/version control (Rojo, etc.) | `.rbxlx` / `.rbxmx` | Human-readable diffs |
| Sharing models between projects | `.rbxm` | Standard exchange format |
| Debugging file internals | `.rbxmx` / `.rbxlx` | Can open in text editor |
| Automated CI/build pipelines | Either | Rojo can produce both |

---

## 2. Saving & Exporting

### Save/Export Place File
1. **File → Save to File** — saves current place locally
2. **File → Download a Copy** — creates a copy without changing the working file
3. Choose `.rbxl` (binary) or `.rbxlx` (XML) format

### Save/Export Model
1. Select object(s) in the **Explorer** window
2. Right-click → **Save to File...**
3. Choose `.rbxm` (binary) or `.rbxmx` (XML) format
4. Choose destination on disk

> **Note:** If "Save to File" is missing from the context menu, check
> **File → Beta Features** and ensure "Next Gen Studio Preview" is disabled —
> this has been known to hide certain context menu options in some versions.

---

## 3. Importing / Inserting

### Import Roblox Models (.rbxm / .rbxmx)

**Method 1 — Drag and Drop (simplest):**
- Drag the `.rbxm` file from Finder/Explorer directly into the 3D viewport or Explorer panel

**Method 2 — Insert from File:**
1. Right-click in the **Explorer** panel (on Workspace or target parent)
2. Select **Insert from File...**
3. Browse to the `.rbxm` or `.rbxmx` file
4. Click **Open**

**Method 3 — Via MCP (programmatic):**
```lua
-- The insert_asset MCP tool can insert assets by ID
-- For local .rbxm files, use drag-and-drop or Insert from File
```

### Import 3D Meshes (Universal Importer)

The **Universal Importer** handles all third-party 3D asset imports.

**Access methods:**
- **File → Import**
- **Ribbon Bar → Import button**
- **Keyboard:** `Cmd+M` (Mac) or `Ctrl+M` (Windows)
- **Asset Manager → Import button** (routes to Universal Importer)

**Supported 3D formats:**

| Format | Features |
|--------|----------|
| `.fbx` | Hierarchies, rigging, skinning, animation, PBR textures, vertex colors, cage meshes. **Recommended for complex assets.** |
| `.gltf` / `.glb` | Same features as FBX. Open standard format. glTF text + separate files, glb single binary. **Recommended for complex assets.** |
| `.obj` | Static geometry only. No rigging/animation/hierarchy. Best for simple static meshes. |

### Import Images

| Format | Notes |
|--------|-------|
| `.png` | Recommended. Supports transparency. |
| `.jpg` | Smaller file size, no transparency. |
| `.gif` | Static only (animated GIFs not supported as animated). |
| `.tga` | Common from 3D tools. Supports alpha. |
| `.bmp` | Legacy format. Largest file size. |

**Uses:** Textures, decals, UI image labels, mesh textures, custom materials, special effects.

### Import Audio

| Format | Notes |
|--------|-------|
| `.mp3` | Most common. Good compression. |
| `.ogg` | Open format. Good quality/size ratio. |
| `.wav` | Uncompressed. High quality, large file. |
| `.flac` | Lossless compression. |

**Constraints:**
- Single track/stream only
- Max **20 MB** file size
- Max **7 minutes** duration
- Sample rate **48 kHz or lower**

### Import Video

| Format | Notes |
|--------|-------|
| `.mp4` | Standard video format. |
| `.mov` | Apple QuickTime format. |

Must meet requirements documented at `https://create.roblox.com/docs/ui/video-frames`.

---

## 4. Universal Importer Settings (3D Models)

When importing 3D models, the Importer provides these key settings:

### File General
| Setting | Default | Description |
|---------|---------|-------------|
| Import Only As Model | Enabled | Imports as single asset even with multiple children |
| Upload to Roblox | Enabled | Adds to Toolbox & Asset Manager. Disable for local-only testing |
| Import as Package | Disabled | Creates a reusable, auto-updating package |
| Add to Workspace | Enabled | Inserts into Workspace and grants experience permission |
| Anchored | Disabled | Sets `Anchored = true` on all imported MeshParts |
| Scale Unit | Studs | Units the model was built in (Studs, Meters, Centimeters, etc.) |
| Merge Meshes | Disabled | Merges all MeshParts into a single MeshPart |

### Rig Settings (if rigging data detected)
| Setting | Options | Description |
|---------|---------|-------------|
| Rig Type | R15, Custom, No Rig | Type of rig association |
| Rig Scale | Default, Rthro, Rthro Narrow | Body type scaling for R15 rigs |
| Validate UGC Body | — | Opens Avatar Setup tool after import |

---

## 5. Asset Management

### Asset Manager
- Access: **View → Asset Manager**
- Manage all assets in the current experience: images, meshes, audio, video, packages
- Bulk import via Import button (routes to Universal Importer)
- Right-click assets for options: Copy ID, Insert, Rename

### Packages
- Reusable asset hierarchies that auto-update across experiences
- Create: right-click object → **Convert to Package**
- Publish updates: right-click package → **Publish**
- All instances of a package update when the source is published
- Great for shared UI components, modules, or prefab models
- Docs: `https://create.roblox.com/docs/projects/assets/packages`

### Asset Privacy
- All imported assets enter a **moderation queue**
- Assets must be approved before visible to others in published experiences
- Use **Asset Privacy** settings to control who can use your assets
- Docs: `https://create.roblox.com/docs/projects/assets/privacy`

### Creator Store
- Browse and insert community/Roblox-made assets
- Access: **View → Toolbox** or visit `https://create.roblox.com/store`
- Includes models, plugins, images, meshes, audio, video

---

## 6. Place File Troubleshooting

If you hit the **100 MB place file limit**:

### Safety Check
- Inspect models and scripts for **obfuscated/unclear text** — may be malicious backdoors
- These don't compress well and bloat file size
- Report suspicious models from Creator Store

### Redundant Parts
- Export place → note size → remove suspect models → compare sizes
- Look for duplicate parts (same size, shape, position)
- Look for redundant `SurfaceAppearance` or texture instances

### Simplify Terrain
- Horizontal layers compress better than sloped layers
- Check for messy holes or misplaced water under surfaces (View → Show Wireframe Rendering)
- Community plugins exist for terrain optimization

### Collision Fidelity
- `Box` and `Hull` are more memory-efficient than default
- Select meshes → Properties → change `CollisionFidelity` as appropriate

### Teleports
- Break large places into multiple smaller places linked by `TeleportService`
- Serialization/upload happens per-place

---

## 7. Auto-Recovery Files

Studio automatically generates recovery files when saves fail.

| OS | Path |
|----|------|
| **Windows** | `C:\Users\<Username>\AppData\Local\Roblox\RobloxStudio\AutoSaves` |
| **Mac** | `/Users/<username>/Library/Application Support/Roblox/RobloxStudio/AutoSaves/` |

- With **collaboration enabled**: Studio keeps last 3 save attempts
- Without collaboration: frequency depends on **Auto-Recovery** setting in Studio Settings

---

## 8. External Tools & File Mapping (Rojo)

When using **Rojo** or similar external tools, file extensions map to Roblox types:

| File Extension | Roblox Type |
|----------------|-------------|
| `*.server.luau` | Server Script |
| `*.client.luau` | Client LocalScript |
| `*.luau` | ModuleScript |
| `default.project.json` | Rojo project configuration |

Rojo can produce both `.rbxl` and `.rbxlx` files via `rojo build`:

```bash
# Build binary place file
rojo build -o game.rbxl

# Build XML place file (version-control friendly)
rojo build -o game.rbxlx
```

For more on external tools: `https://create.roblox.com/docs/projects/external-tools`

---

## 9. Community Specifications

Roblox does **not** publish official binary format specs. Community resources:

| Resource | URL | Description |
|----------|-----|-------------|
| rbx-dom | `https://github.com/rojo-rbx/rbx-dom` | Binary format documentation by Rojo team |
| RobloxAPI/spec | `https://github.com/RobloxAPI/spec` | Reverse-engineered format specifications |

These are primarily useful for building third-party tooling, not for day-to-day development.

---

## Quick Reference: All Supported File Types

| Category | Formats | Import Method |
|----------|---------|---------------|
| **Places** | `.rbxl`, `.rbxlx` | File → Open from File |
| **Models** | `.rbxm`, `.rbxmx` | Drag-and-drop, Insert from File |
| **3D Meshes** | `.fbx`, `.gltf`, `.glb`, `.obj` | Universal Importer (File → Import) |
| **Images** | `.png`, `.jpg`, `.gif`, `.tga`, `.bmp` | Universal Importer |
| **Audio** | `.mp3`, `.ogg`, `.wav`, `.flac` | Universal Importer |
| **Video** | `.mp4`, `.mov` | Universal Importer |
| **Luau Scripts** | `.luau`, `.server.luau`, `.client.luau` | Rojo / Script Sync |
