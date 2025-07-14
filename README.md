# 🔌 Zsh SSHInfo Plugin

A simple Zsh plugin that displays resolved SSH connection details (like the final hostname, port, user, and proxies) before connecting. This is useful for verifying your SSH configuration, especially when dealing with complex setups involving aliases, proxies, or multiple configuration files.

## ✨ Features

-   Shows the real `HostName`, `Port`, `User`, and any `ProxyJump` or `ProxyCommand` before connecting.
-   Supports `LocalForward` and `DynamicForward` directives.
-   Automatically aliases `ssh`, `s`, and `connect` to the `sshinfo` function.
-   Gracefully handles hosts that are not found or have configuration errors.
-   Clean, colorized output for better readability.

## 🛠️ Installation

### For Oh My Zsh users

1.  Clone this repository into your Oh My Zsh custom plugins directory:

    ```bash
    git clone https://github.com/SckyzO/zsh-sshinfo.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-sshinfo
    ```

2.  Add `zsh-sshinfo` to the plugins list in your `~/.zshrc` file:

    ```zsh
    plugins=(... zsh-sshinfo)
    ```

3.  Restart your terminal or source your `~/.zshrc` file:

    ```bash
    source ~/.zshrc
    ```

### Manual Installation

1.  Clone this repository somewhere on your machine:

    ```bash
    git clone https://github.com/SckyzO/zsh-sshinfo.git ~/path/to/zsh-sshinfo
    ```

2.  Source the `zsh-sshinfo.plugin.zsh` file in your `~/.zshrc`:

    ```zsh
    source ~/path/to/zsh-sshinfo/zsh-sshinfo.plugin.zsh
    ```

3.  Restart your terminal.

## 🚀 Usage

Simply use the `ssh` command as you normally would. The plugin will automatically display the connection information before initiating the SSH session.

```bash
ssh my-server
```

You can also use the aliases `s` or `connect`:

```bash
s my-server
connect my-server
```

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
