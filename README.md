# Share Wi-Fi while connected to Wi-Fi

This records the working hotspot setup on `1li-pc` (Ubuntu 24.04, Intel Wireless 8265/8275). The laptop stays connected to Wi-Fi on `wlp2s0` and broadcasts its own hotspot on the virtual interface `ap0`.

The setup was completed on **2026-09-23**. At that time, `wlp2s0` was connected on channel 10. The helper reads the current upstream channel each time it starts.

The hotspot SSID is **`1li-pc`**. Its password is deliberately **not in this repository**. On the configured laptop it is stored in `/etc/wifi-share/password`, readable by the administrator. Do not commit that file or `/run/wifi-share/hostapd.conf`.

## Daily use

```bash
wifi-share status
wifi-share on
wifi-share off
wifi-share password             # Enter and confirm a chosen password
wifi-share password --generate  # Generate and display a new password
```

The hotspot does not automatically start at boot. Run `wifi-share on` after connecting to an upstream Wi-Fi network. Changing the password restarts the hotspot, so connected devices must reconnect. Ubuntu may ask for the administrator password when changing the system state.

To read the currently stored password **locally**:

```bash
sudo cat /etc/wifi-share/password
```

## What was set up

- Installed `hostapd` to run the access point. Ubuntu already had `dnsmasq-base` for DHCP and DNS.
- Added `/usr/local/bin/wifi-share` as the user command and `/usr/local/libexec/wifi-share-root` for privileged operations.
- Added `wifi-share-ap.service` and `wifi-share-dhcp.service`. They run only after `wifi-share on`.
- Used `10.42.7.1/24` for the hotspot. DHCP leases are `10.42.7.10` through `10.42.7.200`.
- Enabled IPv4 forwarding and added an iptables masquerade rule from `10.42.7.0/24` out through `wlp2s0` while the hotspot is on. `wifi-share off` removes that masquerade rule and the hotspot address. It leaves the kernel forwarding setting enabled because other local services may need it.
- Added UFW rules for DHCP, DNS, and forwarding from `ap0` to `wlp2s0`. UFW was inactive when the setup was completed; the rules will apply if it is later enabled.
- Kept NetworkManager off `ap0` so `hostapd` can control it. NetworkManager still controls the upstream `wlp2s0` connection.
- Generated a separate 24-character hexadecimal password for the final hotspot. The old NetworkManager `Hotspot` profile was left in place but is **not used** by this setup. An intermediate `Shared-WiFi` profile was deleted.

The Intel adapter reported support for one managed Wi-Fi interface plus one AP interface, with **one shared channel**. The helper reads the upstream channel each time `wifi-share on` runs and configures the hotspot for that channel. If the upstream Wi-Fi changes channel while sharing is active, turn the hotspot off and back on.

## Why NetworkManager alone did not work

NetworkManager reported `ap0` as unavailable, and its logs said `wpa_supplicant couldn't grab this interface`. Activating a cloned hotspot profile on `ap0` failed. `hostapd` successfully started the AP on the same channel as `wlp2s0`; `dnsmasq` supplied DHCP and DNS, and NAT supplied internet access.

The setup sequence was:

1. Checked `nmcli`, `iw dev`, and `iw list`. The driver advertised AP mode and a managed-plus-AP interface combination restricted to one channel.
2. Found an existing NetworkManager `Hotspot` profile bound to `wlp2s0`. Cloned it as `Shared-WiFi`, changed the clone to `ap0` and channel 10, and tried to activate it. NetworkManager rejected `ap0` as unavailable.
3. Used administrator authentication to set `ap0` to AP mode. NetworkManager still could not acquire it through `wpa_supplicant`.
4. Installed `hostapd`, kept NetworkManager off `ap0`, assigned `10.42.7.1/24`, started `hostapd` on channel 10 and `dnsmasq` for DHCP/DNS, enabled IPv4 forwarding, and added NAT and UFW rules.
5. Replaced the saved eight-character numeric password from the old NetworkManager profile with a newly generated strong password stored only on the laptop. Removed the unused `Shared-WiFi` clone.
6. Installed the `wifi-share` command and permanent systemd service definitions, then tested turning the hotspot off and back on and generating a new password. The services themselves are started on demand.

## Verification performed

- Both `wifi-share-ap.service` and `wifi-share-dhcp.service` were active.
- `iw dev ap0 info` showed SSID `1li-pc` broadcasting on channel 10 while `wlp2s0` stayed connected on channel 10.
- `nslookup example.com 10.42.7.1` resolved through the hotspot DNS service.
- The laptop reached its Wi-Fi gateway and an external site.
- `wifi-share off` followed by `wifi-share on` worked, and password generation restarted the AP successfully.

No second device was connected during verification, so client-side connectivity was not directly measured.

## Reinstall on this Ubuntu laptop

From this repository, run:

```bash
sudo ./install.sh
```

The installer preserves `/etc/wifi-share/password` if it exists. Otherwise it generates a fresh password and prints it once. It installs the scripts and services, prepares UFW rules, and starts the hotspot. The defaults in `libexec/wifi-share-root` are specific to this machine (`wlp2s0`, `ap0`, SSID `1li-pc`, `10.42.7.0/24`). Review those values before using the scripts on another computer.

## Troubleshooting

```bash
wifi-share status
systemctl status wifi-share-ap.service wifi-share-dhcp.service
journalctl -u wifi-share-ap.service -u wifi-share-dhcp.service -n 50 --no-pager
iw dev
nmcli device status
```

If the laptop loses its upstream Wi-Fi connection or changes channel, reconnect upstream and run `wifi-share off` followed by `wifi-share on`. If a client connects but cannot browse, check the DHCP/DNS service, IP forwarding, the masquerade rule, and any enabled firewall rules.
