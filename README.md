# sshinfo for Oh My Zsh 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`sshinfo` is a plugin for [Oh My Zsh](https://ohmyz.sh/) that enhances your `ssh` experience in two main ways:

1.  **✅ Connection Info Display**: Before connecting, it shows you a clear, concise summary of the configuration that will be used (user, port, identity key, proxy, etc.). No more blind connections!
2.  **⚡️ Smart Autocompletion**: It provides powerful and comprehensive `Tab` completion for all your SSH hosts.

---

## ✨ Features

-   **Pre-connection Visualization**: Displays connection details (User, HostName, Port, ProxyJump, etc.) right before the connection is established.
-   **Comprehensive Autocompletion**: Press `Tab` after `ssh` (or the `s`/`connect` aliases) to list all available hosts from:
    -   Your `~/.ssh/config` file.
    -   All files included via the `Include` directive (even recursively!).
    -   Your `~/.ssh/known_hosts` file (while ignoring unreadable hashed hosts).
-   **Convenient Aliases**: Comes with `s` and `connect` aliases for even faster access.
-   **Customizable**: You can choose to override the base `ssh` command by uncommenting a line in the plugin.

---

## 🛠️ Installation

1.  **Clone this repository** into your Oh My Zsh custom plugins directory:
    ```bash
    git clone https://github.com/sckyzo/zsh-sshinfo.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/sshinfo
    ```

2.  **Activate the plugin** by adding it to the plugins list in your `~/.zshrc` file:
    ```zsh
    plugins=(... sshinfo)
    ```
    *(Note: If you use the standard `ssh` plugin, make sure `sshinfo` is listed **after** it to ensure its autocompletion takes priority).*

3.  **Reload your Zsh configuration** for the changes to take effect:
    ```bash
    omz reload
    ```

---

## 🚀 Usage

Simply use `ssh`, `s`, or `connect` as you normally would.

-   **To see connection info**:
    ```bash
    s my-remote-server
    ```
    ![Example Output](https://user-images.githubusercontent.com/example.png) *(Note: You may want to replace this with a real screenshot of the plugin in action)*

-   **To use autocompletion**:
    ```bash
    ssh <Tab>
    # or
    s my-remote-<Tab>
    ```

---

## 🤝 Contributing

Suggestions and contributions are always welcome! Feel free to open an issue or a pull request.

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.