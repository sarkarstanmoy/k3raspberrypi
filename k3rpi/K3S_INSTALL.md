# K3s Installation on Raspberry Pi

This guide covers installing K3s on a Raspberry Pi running Debian, plus the fix required when the Pi boot configuration disables the memory cgroup and prevents K3s from starting.

## 1. Connect to the Pi

```bash
ssh admin@192.168.1.187
```

## 2. Install K3s

```bash
curl -sfL https://get.k3s.io | sudo sh -s - --write-kubeconfig-mode 644
```

If the install fails with an error like:

```text
failed to find memory cgroup (v2)
```

then the system boot configuration is blocking the memory cgroup required by K3s.

## 3. Fix the Raspberry Pi boot configuration

Check the current boot parameters:

```bash
cat /boot/firmware/cmdline.txt
```

If the file contains an invalid or disabled cgroup setup, update it. In this environment the problem was:

```text
cgroup_disable=memory
cgroup_enable=memoryx
```

Use the following commands to back up and fix the config:

```bash
sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.bak
sudo sed -i 's/cgroup_disable=memory //g; s/cgroup_enable=memoryx/cgroup_enable=memory/; s/^/ /' /boot/firmware/cmdline.txt
sudo sed -i 's/  */ /g' /boot/firmware/cmdline.txt
cat /boot/firmware/cmdline.txt
```

The final line should include:

```text
cgroup_memory=1 cgroup_enable=memory
```

Then reboot:

```bash
sudo reboot now
```

## 4. Verify K3s is running

After the Pi comes back online:

```bash
ssh admin@192.168.1.187
sudo systemctl status k3s --no-pager
sudo kubectl get nodes -o wide
```

Expected output should show the node as Ready:

```text
NAME   STATUS   ROLES           AGE   VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                 CONTAINER-RUNTIME
pi5    Ready    control-plane   94s   v1.36.4+k3s1   192.168.1.187   <none>        Debian GNU/Linux 12 (bookworm)   6.12.93+rpt-rpi-2712 (arm64)   containerd://2.3.4-k3s1.36
```

## 5. Optional: create a kubectl shortcut alias

To avoid typing `sudo kubectl` every time, add this alias:

```bash
echo 'alias k="sudo kubectl"' >> ~/.bashrc
echo 'alias k="sudo kubectl"' >> ~/.zshrc
source ~/.bashrc
source ~/.zshrc
```

Then use:

```bash
k get nodes
k get pods -A
```

## 6. Useful commands

```bash
sudo kubectl get nodes
sudo kubectl get pods -A
sudo kubectl describe node pi5
sudo kubectl logs -n kube-system <pod-name>
```

## Notes

- K3s requires a working cgroup setup on the Raspberry Pi.
- The memory cgroup issue is the most common reason for installation failure on Debian-based Pi images.
- Once the boot config is corrected and the node reboots, K3s should start normally.
