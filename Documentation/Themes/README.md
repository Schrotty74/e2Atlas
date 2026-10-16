# Create custom e2Atlas themes

[Deutsch](README.de.md) · [Back to the homepage](../../README.md) · [Download the JSON template](theme-template.json?raw=true)

An e2Atlas theme is a JSON file containing light and dark color palettes. Choose Automatic in the app to follow macOS appearance, or choose Light or Dark to keep using that palette.

## Version support

The [0.2.0-beta release](https://github.com/Schrotty74/e2Atlas/releases/tag/v0.2.0-beta) supports custom JSON themes, diagonal background gradients and multiple theme files. In **Settings → Appearance**, choose **Create theme template** to add a JSON template and guide to the theme folder. Existing files are preserved. While Appearance settings are open, the list refreshes every two seconds.

The built-in themes are System, Ocean, Ivory and Bronze. Each color theme has light and dark palettes. Ocean uses blue and cyan gradients; Ivory and Bronze also include gradients.

## Start with a custom theme

1. In e2Atlas, open **Settings → Appearance → Create theme template**. The app creates a new JSON file and a guide in the correct folder. If you prefer, download the [template](theme-template.json?raw=true) and open **Settings → Appearance → Open theme folder**.
2. Open the JSON file in a text editor. In TextEdit, choose **Format → Make Plain Text**, then save as UTF-8 text.
3. Change the `id`, `name` and colors, then save. Keep the `.json` extension. Files in subfolders are not loaded.
4. Return to Appearance settings. The list refreshes while the pane is open; choose your theme from the list.

The template button creates a new filename and identifier each time. It does not overwrite existing files.

## JSON structure

The [complete template](theme-template.json) contains every required field. Start by changing its header:

```json
"version": 1,
"id": "my-sea",
"name": "My Sea"
```

This is a header excerpt, not a complete JSON file. Use the linked template for the full structure.

| Field | Meaning |
| --- | --- |
| `version` | Theme format version; currently `1` |
| `id` | Unique identifier: 2–48 characters, starting with a lowercase letter, followed by lowercase letters, digits or hyphens |
| `name` | Display name, 1–60 characters |
| `light` | Palette for light appearance |
| `dark` | Palette for dark appearance |

Avoid identifiers used by bundled themes: `system`, `ocean`, `ivory` and `bronze`. Bundled identifiers take precedence. For duplicate custom IDs, the first file in alphabetical order wins. Give every custom file a different identifier; a different filename alone does not make a separate theme.

## Colors and gradients

Each palette has the same six required fields:

| Field | Used for |
| --- | --- |
| `background` | Background color or start of the gradient |
| `surface` | Cards and program cells |
| `accent` | Controls and active markers |
| `text` | Main text |
| `secondary` | Supporting text |
| `selection` | Selected programs |

Write colors as six-digit hex values with a leading `#`, such as `#127CA6`. Short forms such as `#FFF` and transparency values are not supported. JSON does not allow comments or a trailing comma after the last entry.

The optional `backgroundEnd` field sets the second color of a diagonal gradient. Two nearby shades produce a subtle transition. Remove this field from both palettes for a solid background.

Use dark text on light surfaces in `light`, and light text on dark surfaces in `dark`. Check both appearances, including selected programs. Video backgrounds stay black. macOS still draws native window elements and Liquid Glass; a theme does not replace every system color.

## Keep several themes

Save multiple `.json` files directly in the theme folder, each with a unique `id` and a recognizable `name`. Valid files appear as separate choices after the list refreshes.

Dev, Beta and Final use separate theme folders and caches. Open the folder from the app in which you want to use the theme.

## If a theme is missing

- Check the extension, UTF-8 encoding and JSON syntax.
- Compare all required fields with the template and use `version: 1`.
- Check the identifier, name and every color. Keep the file at or below 64 KiB.
- Avoid reserved or duplicate identifiers.

Invalid files are skipped and counted in Settings. The catalog also counts duplicate identifiers and switches to System if the selected theme is removed or becomes invalid.

Theme files contain appearance data only. Do not put passwords, receiver addresses or other private information in them.
