# Nintendo Wii U

[![Hex version](https://img.shields.io/hexpm/v/nerves_system_wiiu.svg "Hex version")](https://hex.pm/packages/nerves_system_wiiu)

This is the base Nerves System configuration for the Nintendo Wii U
(Espresso/Latte — *not* vWii).

| Feature              | Description                      |
| -------------------- | -------------------------------- |
| CPU                  | 1.24 GHz tri-core PowerPC 750 "Espresso" (32-bit, big-endian) |
| Memory               | 2 GB DRAM                        |
| Storage              | SD card                          |
| Linux kernel         | 6.6 w/ linux-wiiu patches        |
| IEx terminal         | HDMI and USB keyboard            |
| GPIO, I2C, SPI       | No                               |
| UART                 | No accessible console UART       |
| Display              | HDMI (framebuffer, no GPU accel) |
| Ethernet             | USB ethernet adapter             |
| WiFi                 | Yes — on-board Broadcom BCM43362  |
| Bluetooth            | No                               |
| Audio                | No                               |

## Using

The most common way of using this Nerves System is to create a project with
`mix nerves.new` and to export `MIX_TARGET=wiiu`. See the [Getting started
guide](https://hexdocs.pm/nerves/getting-started.html#creating-a-new-nerves-app)
for more information.

If you need custom modifications to this system for your device, clone this
repository and update as described in [Making custom
systems](https://hexdocs.pm/nerves/customizing-systems.html).

## Booting

The Wii U reaches Linux through Aroma CFW, which launches the `fw.img` loader
(`linux-loader`) that boots the kernel from the SD card's FAT boot partition.

1. Burn firmware to an SD card with `mix firmware.burn` (or `fwup`).
2. The boot partition must also contain a working Aroma environment and a
   `fw.img` loader. Neither is shipped here — they are large, console/key
   specific, and not ours to redistribute:
   - Populate `board/wiiu/sdcard/wiiu/` from a known-good Aroma SD card before
     building (or point `WIIU_SDCARD_OVERLAY` at one).
   - Drop your own `fw.img` at `board/wiiu/fw.img` (or set `WIIU_FW_IMG`).
3. Insert the card and launch via Aroma's CFW booter. Hold **B** on the GamePad
   during boot to reach the Petitboot menu.

The IEx terminal is on the **HDMI** framebuffer console — attach a USB keyboard
(the GamePad screen stays blank).

## Networking

Configure interfaces with [VintageNet](https://hexdocs.pm/vintage_net).

- **WiFi** (on-board BCM43362): `VintageNetWiFi.quick_configure("SSID", "psk")`.
- **Ethernet**: a USB ethernet adapter comes up as `eth0` (DHCP by default).

The bundled WiFi nvram is a generic 43362 file with a shared MAC; for production
supply a per-console `brcmfmac43362-sdio.txt` (or drop `macaddr=` to use the
chip's OTP MAC). See `rootfs_overlay/lib/firmware/brcm/`.

## Provisioning devices

This system stores provisioning information in a small key-value store outside
of any filesystem. It is optional and reasonable defaults apply if missing.

Provisioning information can be queried with
[`Nerves.Runtime.KV.get/1`](https://hexdocs.pm/nerves_runtime/Nerves.Runtime.KV.html#get/1).

Key                    | Example Value     | Description
:--------------------- | :---------------- | :----------
`nerves_serial_number` | `"FEM123456789"`  | Used for unique hostnames and Erlang node names. Defaults to the console serial read from the SEEPROM.

To set a serial number on a running device and reboot:

```elixir
iex> cmd("fw_setenv nerves_serial_number 12345678")
```

Or when burning firmware:

```sh
sudo NERVES_SERIAL_NUMBER=12345678 fwup path_to_firmware.fw
```

Additional key/value pairs can be provisioned by setting
`NERVES_PROVISIONING=/path/to/provisioning.conf`.

## Toolchain

The Espresso CPU isn't covered by an upstream Nerves toolchain, so this system
depends on
[`nerves_toolchain_wiiu_ppc`](https://github.com/mlainez/nerves_toolchain_wiiu_ppc)
— a prebuilt `powerpc-nerves-linux-gnu` GCC/glibc toolchain with the Espresso
SMP atomic-errata workarounds. It is downloaded automatically at build time.

## Linux kernel configuration

The kernel is pinned to the linux-wiiu `rewrite-6.6` tip (Linux 6.6.106), which
already carries the WiFi SDHCI fix (device-tree `no-dma`). It starts from the
in-tree `wiiu` defconfig plus `linux-6.6.fragment` (SquashFS/F2FS, HDMI console,
USB-ethernet, WiFi modules, SMP). `linux-patches/` holds two patches
cherry-picked from `rewrite-6.6-smp` that enable SMP across all three Espresso
cores (the SMP support and the Espresso atomic erratum).
