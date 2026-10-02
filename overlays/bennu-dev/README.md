# bennu-dev
`bennu` development VM. A modified version of the `bennu` image that allows for mid-experiment modification and troubleshooting of `bennu`. Built on Ubuntu 22.04 (Jammy) with VS Code, xrdp, Remmina, GNOME Web, Wireshark, and Nmap.

## Building the image
```bash
make bennu-dev
```

## Users on the image
| Username | Password | Notes |
| -------- | -------- | ----- |
| `root`   | empty    | This is the primary user of the image. |
| `sceptre`| `sceptre`| This user only has access to the Brash shell. |

## Compiling bennu
`bennu` can be recompiled with the following commands, which build using all available processors:
```bash
cd /root/Desktop/bennu/build
make -j$(nproc)
make install
```

## Modifying pybennu
`pybennu` is installed with `pip install -e`, allowing changes to its source code (`/root/Desktop/bennu/src/pybennu/`) to apply immediately.

## Adding VS Code extensions
The image already comes with the following VS Code extensions:
- [Microsoft C/C++ Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools)
- [Microsoft Makefile Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.makefile-tools)
- [Microsoft Python Extension](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
- [Microsoft Python Debugger Extension](https://marketplace.visualstudio.com/items?itemName=ms-python.debugpy)

To add more extensions, either modify the image build script or inject the VSIX file into the VM and install it with the following command:
```bash
code --no-sandbox --user-data-dir="/root/.vscode" --install-extension <path to extension>
```

## Connecting with Remote Desktop Protocol (RDP)
`xrdp` is set up on this machine to allow RDP connections. To RDP in as the root user, ensure that the local GUI session is logged out. This can be done via the graphical logout menu or with the following command:
```bash
xfce4-session-logout --logout
```

The recommended way to log into this VM for the best development experience is using RDP via Phenix Tunneler (https://phenix.sceptre.dev/latest/tunneler/)