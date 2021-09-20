This projects provides a Docker image which contains a Tar archive of
Bitrix installation and Python with Selenium installation script.

# Updating the project

After changing `bitrix_install/__main__.py` make sure to update
`install.nix` `rev` and `sha256` fields, and after `dist` update
`bitrix.nix`.

# Debug

Run a virtual machine with Xorg, XFCE, and start up scripts (inside
XFCE “Applications” menu under “System” group):
``` shell
nix build -f test.nix driver --arg debug true
./result/bin/nixos-run-vms
```

Launch `run-apache` then `install-bitrix`.

Also you could connect to virtual machine as `admin` user with `eng`
SSH private key to `localhost` port `2222` (make sure `2222` is free
before running the virtual machine).
