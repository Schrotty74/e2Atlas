# Custom e2Atlas themes

In Settings → Appearance, choose “Create theme template”. The app creates a new JSON file and this guide in the theme folder. Existing files are never overwritten.

Edit the JSON file in a text editor and save it as plain UTF-8 text. You can add any number of `.json` files to the same folder. The theme list refreshes while Appearance settings are open. Choose “Reload themes” to refresh it immediately.

## Structure

- `version`: currently always `1`.
- `id`: a unique identifier between 2 and 48 characters. Start with a lowercase letter; use lowercase letters, digits, and hyphens after that. `system`, `ocean`, `ivory`, and `bronze` are reserved. Each file needs its own identifier.
- `name`: the displayed name, between 1 and 60 characters.
- `light` and `dark`: color palettes for light and dark appearance. The macOS setting or the selected appearance determines which palette is used.

Each palette has six required fields:

| Field | Used for |
| --- | --- |
| `background` | Background color or start of a gradient |
| `surface` | Cards, programme cells, and other surfaces |
| `accent` | Controls and active highlights |
| `text` | Main text |
| `secondary` | Supporting text |
| `selection` | Selected programmes |

The optional `backgroundEnd` field sets the second color of a subtle diagonal background gradient. Without it, the background stays a solid color. Use `#RRGGBB` color values, for example `#127CA6`. This JSON template does not allow transparency values, comments, or extra commas.

Keep text and background contrast high, and check both appearances. Videos keep their black background. macOS continues to draw system windows and Liquid Glass.

## Multiple files and errors

Valid files appear separately in the theme list. Bundled themes take precedence. If custom themes have duplicate identifiers, the first file in alphabetical order wins. Give each copy a new `id` and `name`.

The app skips invalid files, unknown format versions, and files larger than 64 KiB. It shows how many files were skipped. If the selected theme is removed or becomes invalid, the app switches to System in Appearance settings. Do not store passwords, receiver addresses, or other private data in theme files.

The app locates this folder through macOS data directories for each app channel. Dev, Beta, and Final use separate theme folders. Choose “Open theme folder” to open the correct folder, wherever the app is installed.
