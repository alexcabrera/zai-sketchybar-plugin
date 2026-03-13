# Z.ai SketchyBar Plugin

A SketchyBar plugin to display your Z.ai API usage in the menu bar.

## Screenshot

The plugin displays: `󰠞 22% · 29%/wk`
- 5-hour token quota percentage
- Weekly token quota percentage

## Requirements

- [SketchyBar](https://github.com/FelixKratz/SketchyBar)
- Python 3 (for time calculations and JSON parsing)
- Z.ai API key

## Installation

1. Copy the plugin to your SketchyBar plugins directory:

```bash
cp zai-usage.sh ~/.config/sketchybar/plugins/
chmod +x ~/.config/sketchybar/plugins/zai-usage.sh
```

2. Add your Z.ai API key to your shell config (`~/.zshrc` or `~/.zshenv`):

```bash
export ZAI_API_KEY="your-api-key-here"
```

3. Add the item to your `sketchybarrc` (before the battery item):

```bash
# Z.ai Usage tracker (right side, before battery)
sketchybar --add item zai-usage right \
  --set zai-usage update_freq=120 script="$PLUGIN_DIR/zai-usage.sh" icon.font="Liga SFMono Nerd Font:Regular:16.0" padding_left=10 \
  --subscribe zai-usage system_woke
```

4. Reload SketchyBar:

```bash
sketchybar --reload
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ZAI_API_KEY` | Yes | - | Your Z.ai API key |
| `ZAI_PLATFORM` | No | `global` | Platform: `global` or `china` |

### Display

The plugin shows:
- **5-hour quota percentage**: Current token usage in the 5-hour rolling window
- **Weekly quota percentage**: Token usage over the past 7 days

### Color Coding

Colors indicate usage level (based on weekly percentage):

| Percentage | Color |
|------------|-------|
| < 50% | Green |
| 50-70% | Yellow |
| 70-90% | Orange |
| > 90% | Red |

## License

MIT
