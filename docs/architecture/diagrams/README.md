# Diagram sources

Editable sources of the figures in [`../icam-flows.md`](../icam-flows.md).

| File | Tool | How to edit |
|---|---|---|
| `icam-overview.drawio` | [draw.io](https://app.diagrams.net) (web or desktop) | Open the file, edit, save it back here. Then export it as SVG (File > Export as > SVG, border 10) over `icam-overview.svg`, which is the preview shown in the documentation |
| `sequences/*.txt` | [sequencediagram.org](https://sequencediagram.org) | Paste the text into the editor. Copy the edited text back into the file, then update the matching Mermaid block in `../icam-flows.md` |

Conventions:

- Colours in the overview: green for what the change builds, blue for what it configures, grey for what it reuses as is, dashed for external parts.
- Flow labels (F0 to F8) and trust boundaries (TB1 to TB3) are the same in the overview, the sequences and the text.
