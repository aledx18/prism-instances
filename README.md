# Prism Instances

View and launch Minecraft instances managed by Prism Launcher from the Omarchy bar.

## Status

The plugin is currently initialized with its bar widget, panel, manifest, and Git repository. Prism Launcher instance discovery and launching are planned next.

## Install

Once the repository is public:

```sh
omarchy plugin add https://github.com/<your-account>/omarchy-prism-instances.git --enable
```

## Usage

Click the `󰍳` icon in the Omarchy bar to open the plugin panel.

## Development

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

The plugin does not install Prism Launcher, modify its configuration, or change system files.

## License

MIT
