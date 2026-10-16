# Create custom e2Atlas themes

[Deutsch](README.de.md) · [Back to the homepage](../../README.md) · [Download the JSON template](theme-template.json?raw=true)

An e2Atlas theme is a JSON file containing light and dark color palettes. Choose Automatic in the app to follow macOS appearance, or choose Light or Dark to keep using that palette.

## Version support

The published **Beta 1 (0.1.0-beta.1)** already loads custom JSON themes. Use **Theme-Ordner öffnen** (Open theme folder), then **Themes neu laden** (Reload themes). Beta 1 ignores the optional gradient field; the other template colors work.

The template creation button, automatic list refresh and background gradients are implemented in the local Dev build. They are intended for a later beta and are not included in the published Beta 1 download. The new bundled Ivory (Elfenbein) and Bronze themes are also pending release. Available downloads are listed under [Releases](https://github.com/Schrotty74/e2Atlas/releases).

## Start with the template

1. Download the [template](theme-template.json?raw=true), or right-click the link and save it as a file. Keep the `.json` extension; avoid `.json.txt`.
2. In e2Atlas, open **Settings → Appearance → Open theme folder**. The current German labels are **Einstellungen → Darstellung → Theme-Ordner öffnen**.
3. Copy the template directly into that folder, for example as `my-sea.json`. Files in subfolders are not loaded.
4. Open the file in a text editor. In TextEdit, choose **Format → Make Plain Text**, then save as UTF-8 text.
5. Change the `id`, `name` and colors, then save.
6. In Beta 1, click **Reload themes** and select your theme. In the expanded theme settings, the list refreshes every two seconds while the Appearance pane is open.

If your build offers **Theme-Vorlage erstellen** (Create theme template), that button replaces the first three steps. It creates a new JSON file and a guide in the correct folder. Existing files are preserved; each additional template gets its own filename and identifier.

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

Avoid identifiers used by bundled themes: `system`, `ocean`, and, in the expanded catalog, `ivory` and `bronze`. The expanded catalog protects these identifiers; Beta 1 explicitly protects only `system`. Give every custom file a different identifier. A different filename alone does not make a separate theme.

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

The optional `backgroundEnd` field sets the second color of a diagonal gradient. Two nearby shades produce a subtle transition. Remove this field from both palettes for a solid background. Beta 1 ignores the field; gradients require the expanded theme implementation.

Use dark text on light surfaces in `light`, and light text on dark surfaces in `dark`. Check both appearances, including selected programs. Video backgrounds stay black. macOS still draws native window elements and Liquid Glass; a theme does not replace every system color.

## Keep several themes

Save multiple `.json` files directly in the theme folder, each with a unique `id` and a recognizable `name`. After reloading, valid files appear as separate choices.

In the expanded catalog, bundled identifiers take precedence. For duplicate custom IDs, the first file in alphabetical order wins. Avoid duplicate IDs in Beta 1 as well; file order is not a substitute for a unique identifier.

Dev, Beta and Final use separate theme folders. Open the folder from the app in which you want to use the theme. No fixed installation path is needed.

## If a theme is missing

- Check the extension, UTF-8 encoding and JSON syntax.
- Compare all required fields with the template and use `version: 1`.
- Check the identifier, name and every color. Keep the file at or below 64 KiB.
- Avoid reserved or duplicate identifiers, then click **Reload themes**.

Invalid files are skipped and counted in Settings. The expanded catalog also counts duplicate identifiers and switches to System if the selected theme is removed or becomes invalid.

Theme files contain appearance data only. Do not put passwords, receiver addresses or other private information in them.
