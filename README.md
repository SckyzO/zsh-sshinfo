# zsh-sshinfo

A powerful and visually elegant Zsh plugin that summarizes your SSH connection details before connecting.

![Banner](https://img.shields.io/badge/ZSH-Plugin-blue?style=for-the-badge&logo=zsh)
![Style](https://img.shields.io/badge/Design-Pixel_Perfect-cyan?style=for-the-badge)

## ✨ Features

- **Pixel Perfect UI**: Clean, modern summary with Unicode borders and 256-color support.
- **Recursive Tunnel Discovery**: Automatically resolves full ProxyJump/ProxyCommand chains.
- **Dynamic Route Styles**: Choose between a vertical **Staircase** view or a compact **Inline** view.
- **IP Resolution**: Automatically resolves hostnames to real IP addresses.
- **Smart Completion**: Advanced tab-completion that follows `Include` directives and parses `known_hosts`.
- **Non-Invasive**: Wraps `ssh` but stays out of your way for simple commands.

## 🚀 Installation

### Using [Oh My Zsh](https://ohmyz.sh/)

1. Clone the repository into your custom plugins folder:
   ```bash
   git clone https://github.com/SckyzO/zsh-sshinfo.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/sshinfo
   ```
2. Add `sshinfo` to your plugins list in `~/.zshrc`:
   ```zsh
   plugins=(... sshinfo)
   ```
3. Restart your shell or run `omz reload`.

## ⚙️ Configuration

### Display Styles

You can set the default route display style by exporting `ZSH_SSHINFO_STYLE` in your `.zshrc`:

```zsh
# Default is "staircase"
export ZSH_SSHINFO_STYLE="inline"
```

### On-the-fly Overrides

You can override the style directly on the command line:

```bash
ssh --inline my-host        # Force compact view
ssh --staircase my-host     # Force tree view
```

## 📸 Preview

### Staircase Mode (Default)
```text
 󰔶 SSH Connection to production-db

 ╭── CONNECTION
 │  👤 User     : root
 │  🌐 Host     : 10.0.5.2 (10.0.5.2)
 │  🔌 Port     : 22
 │
 ├── SECURITY
 │  🔑 Key      : ~/.ssh/id_ed25519
 │
 ├── NETWORK PATH
 │  🛤️ Route    : bastion [194.57.10.1]
 │                ╰─> production-db [10.0.5.2]
 │
 ╰───────────────────────────────────────────
```

### Inline Mode
```text
 ├── NETWORK PATH
 │  🛤️ Route    : bastion [194.57.10.1] ➜ production-db [10.0.5.2]
```

## 🛠️ Requirements

- **Zsh**
- **Nerd Fonts** (recommended for icons like 󰔶, 👤, 🌐)
- **ssh** (OpenSSH)

## 📄 License

This project is licensed under the [MIT License](LICENSE).
