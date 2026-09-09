# Google Pixel Slate ("nocturne") — hardware notes

Everything learned while reviving a Pixel Slate that had been dead for years,
replacing its firmware, and getting Linux onto it. Written both as source
material for a write-up and as a working guide for re-opening, re-flashing, or
restoring the original OS.

Conventions used below: **Verified** means observed directly on this device.
**Inferred** means a conclusion I'm confident in but didn't prove. **Unknown**
means an open question.

> **Redact before publishing:** the `HWID` on the recovery screen and the
> `DEV_ID` printed by the GSC console's `sysinfo` are unique to this unit.

---

## 1. The device

| | |
|---|---|
| Marketing name | Google Pixel Slate (2018) |
| Board / codename | `nocturne` |
| HWID prefix | `NOCTURNE D5B-…` (rest redacted) |
| SoC | Intel Core i7-8500Y (Amber Lake Y), 2 cores / 4 threads, fanless |
| RAM | 16 GB |
| Storage | 233 GB eMMC — Samsung `KLMEG8UERM` (soldered) |
| Display | eDP-1, 3000×2000, 12.3" (~293 PPI) |
| Touch / stylus | Wacom `WCOM50C1` (`2D1F:486C`), separate Stylus input node |
| WiFi/BT | Intel `7265D2W` — Wireless-AC, 2×2 (Wi-Fi 5, **not** Wi-Fi 6) |
| EC | Nuvoton `NPCX796FA0BX` |
| GSC / "TPM" | Google H1, package marked `H1B2D` → GSC reports `g cr50 B2-D` |
| AP SPI flash | GigaDevice **GD25Q127C**, 16 MB (128 Mbit), **3.3 V** |
| Battery | Model A70, Li-ion 7.7 V, 48.28 Wh |
| Detachable keyboard | codename **Whiskers** (not owned; see §9) |

ChromeOS support for `nocturne` has ended, so stock ChromeOS is a dead end for
long-term use regardless of the fault below.

### Flash chip identification (matters for flashrom)

`GD25Q127C` reports a JEDEC ID shared with several definitions, and flashrom
refuses to guess:

```
Multiple flash chip definitions match the detected chip(s):
  "GD25B128B/GD25Q128B", "GD25Q128E/GD25B128E/GD25R128E/GD25Q127C", "GD25Q128C"
```

The correct one, read off the chip itself (`AE1814` / `25Q127C`, GigaDevice "G"
logo, upper-middle of the board):

```
-c "GD25Q128E/GD25B128E/GD25R128E/GD25Q127C"
```

**This matters more than it looks.** Two reads taken with the *wrong*
definition (`GD25Q128C`) did not hash-match each other. With the correct
definition, two consecutive 16 MB reads were byte-identical. **Never trust a
read until two of them agree.**

Voltage: the GigaDevice `GD25Q` family is 3.3 V. The 1.8 V parts are `GD25LQ` /
`GD25WQ`. So **no 1.8 V adapter is needed on this board** — despite
MrChromebox's general warning that Kaby Lake-era Chromebooks often use 1.8 V
parts.

### Intel flash descriptor layout

From `ifdtool -d` on the stock ROM dump:

```
Flash Region 0 (Flash Descriptor): 00000000 - 00000fff
Flash Region 1 (BIOS):             00200000 - 00ffffff
Flash Region 2 (Intel ME):         00001000 - 001fffff
```

The BIOS region is the top 14 MB, so writes use `--ifd -i bios -N`, which
leaves the descriptor and the ME region alone.

---

## 2. The original fault

Symptom: powers on, reaches *"ChromeOS is missing or damaged"*, recovery from
USB fails. Had been in this state for years.

Pressing a volume key at the recovery screen shows debug info. Key lines:

```
HWID: NOCTURNE D5B-…
recovery_reason: 0x54 / 0x54   TPM read error in rewritable firmware
VbSD.flags: 0x0003dc54
dev_boot_usb: 0
dev_boot_legacy: 0
TPM: fwver=0x00010001 kernver=0x00000000
gbb.flags: 0x00000000
read-only firmware id: Google_Nocturne.10984.28.0
active firmware id:    Google_Nocturne.10984.28.0
TPM state: v=1 failed tries=0 max_tries=200
```

### What it actually meant

The GSC's own boot log (readable over the debug cable, see §5) gave the answer
in two lines:

```
read_tpm_nvmem: object at 0x100a not found
read_tpm_nvmem: object at 0x1008 not found
```

Those are TPM non-volatile storage indices with specific meanings in ChromeOS
verified boot (defined in coreboot's `security/vboot/antirollback.h`):

| Index | Name | Purpose |
|---|---|---|
| `0x1007` | `FIRMWARE_NV_INDEX` | firmware rollback protection |
| `0x1008` | `KERNEL_NV_INDEX` | kernel rollback protection |
| `0x1009` | `BACKUP_NV_INDEX` | |
| `0x100a` | `FWMP_NV_INDEX` | Firmware Management Parameters (owner policy) |

**`0x1008` was missing — not corrupt, absent.** The rewritable firmware reads
it during boot, found nothing, and fell into recovery. That is exactly
`recovery_reason 0x54`, and it's also why the screen showed
`kernver=0x00000000`.

Note that `0x100a` (FWMP) being absent is *normal* — it only exists when an
owner sets a policy. I initially misread this as part of the fault; it wasn't.

### Diagnostic conclusions worth keeping

- **A device that powers on has a live H1.** The GSC is the first thing powered
  and it releases the EC from reset; if it were dead there'd be no display, no
  charging LED, nothing. It also *answered* queries (it printed `fwver`). So
  "TPM failure" as a hardware verdict was wrong from the start.
- **The GSC firmware was recent** (`0.5.230 / cr50_v2.94_mp.295`, built
  2024-02-12) even though the AP firmware was from ~2019
  (`Google_Nocturne.10984.28.0`). The two update independently.
- **`TPM MODE: enabled (0)`** in `sysinfo` — the TPM was on and functioning.
- The Infineon TPM 1.2 firmware-update saga (which most web results for
  `0x54` are about) **does not apply**. `nocturne` has an H1/GSC TPM 2.0 and
  was never part of that mechanism. Ignore that advice entirely.

---

## 3. Why every software-only path was closed

Worth documenting because it's counter-intuitive and cost real time.

**Developer mode was already on.** Attempting to enable it returned
`TO_DEV rejected, developer mode is already on`, and the GSC confirmed it
(`TPM: dev_mode` in `ccd` output). But `dev_boot_usb: 0` and
`dev_boot_legacy: 0`, and those can only be changed with `crossystem` from a
booted ChromeOS. Even if set, `0x54` fires *before* boot-device selection, so
USB boot would never be reached.

**Recovery USB was rejected.** A correctly written, official recovery image
produced:

> The device owner requires this device to run with ChromeOS verification
> turned on. You are trying to install an unofficial ChromeOS recovery image
> which does not pass verification.

The device was bought new from Google and was never enterprise-enrolled, so
this was **not** a real FWMP policy — it's what the firmware does when it can't
read what it needs from the GSC. Note the internal contradiction on the screen:
the device was simultaneously *in* developer mode and supposedly forbidden from
being in it.

Verifying the USB was written correctly (macOS, `diskutil list /dev/diskN`) —
a valid ChromeOS recovery image shows ~a dozen partitions with these type
GUIDs:

| GUID | Meaning |
|---|---|
| `FE3A2A5D-4F32-41A7-B725-ACCC3285A309` | ChromeOS kernel (KERN-A / KERN-B) |
| `3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC` | ChromeOS rootfs (ROOT-A / ROOT-B) |
| `CAB6E88E-ABF3-4102-A07A-D4BB9BE3C1D3` | ChromeOS firmware |
| plus an `EFI-SYSTEM` partition | |

**Net effect:** with `0x1008` missing, the firmware would neither boot nor
accept a recovery image, and nothing reachable from userspace could fix it.
Physical access was the only way in.

---

## 4. Getting recovery images

The official **Chromebook Recovery Utility** extension hung at 0% downloading —
common for boards past end-of-support. Workarounds:

- Download the `.bin.zip` directly from
  <https://chromiumdash.appspot.com/serving-builds?deviceCategory=ChromeOS>
- <https://chrome100.dev/board/nocturne> archives per-version images (though as
  of writing its oldest listed build was recent, so the "try an older image"
  theory couldn't be tested)

Writing on macOS (recovery images are raw disk images):

```bash
unzip chromeos_*_nocturne_recovery_*.bin.zip
diskutil list                      # identify the stick — check twice
diskutil unmountDisk /dev/diskN
sudo dd if=chromeos_*.bin of=/dev/rdiskN bs=4m    # rdiskN = raw, much faster
diskutil eject /dev/diskN
```

macOS `dd` has no `status=progress`; press **Ctrl+T** for a progress line. When
it finishes macOS says *"The disk you inserted was not readable"* — click
**Ignore**, never **Initialize**.

Entering recovery on a Slate: power off, then hold
**Power + Volume-Up + Volume-Down for ~10 s**. At the recovery screen, a volume
key shows debug info; Volume-Up + Volume-Down together opens the debug menu.

---

## 5. The SuzyQ / CCD debug cable

This is the single most valuable tool for this device and the reason it was
recoverable at all.

### What it is

A USB-C "debug accessory" cable. It presents a **22 kΩ resistor on the CC pin**
to put the port into USB-C Debug Accessory Mode, and routes the port's
**SBU1/SBU2** pins onto ordinary USB 2.0 data lines. Cheap AliExpress cables
sold as "SuzyQ" often do neither and fail silently. An open-source DIY design
exists: <https://github.com/erichVK5/erichVK5-suzy-Q-cable-v1>

### Orientation — the part that wasted the most time

Three independent constraints, giving four combinations to try:

1. **Only one of the two USB-C ports supports CCD.**
2. **The connector is orientation-dependent** — physically rotate it 180°.
3. The adapter's **male USB-C plug goes into the tablet**; the other end runs to
   the Linux host.

**On this unit: the LEFT port, with the adapter's screws facing the rear of the
device.** Write that down; it is annoying to rediscover.

Host side: use **USB-A** on the computer, not USB-C. The adapter's socket has no
CC resistors of its own, so a USB-C host port may never negotiate and will leave
the port dark. Also make sure the cable from adapter to host is a **data** cable.

The SuzyQ cannot charge the tablet — keep the charger in the other port.

### Detection

```bash
watch -n1 'lsusb | grep 18d1:5014'      # 18d1:5014 = Cr50/H1  (Ti50 = 18d1:504a)
udevadm monitor --subsystem-match=usb   # better: survives a noisy kernel log
ls -l /dev/ttyUSB*                      # expect three
```

Three serial devices appear, in this order:

| Device | Console |
|---|---|
| `/dev/ttyUSB0` | GSC (Cr50) |
| `/dev/ttyUSB1` | AP / main CPU |
| `/dev/ttyUSB2` | EC |

Connect with `sudo picocom -b 115200 /dev/ttyUSB0` (exit: `Ctrl-A` `Ctrl-X`).

**Use `udevadm monitor` rather than `watch lsusb`.** There is a documented
failure mode (older GSC firmware) where the device enumerates and immediately
disconnects; a 1-second poll misses it entirely and looks identical to nothing
happening. On this machine the kernel log was also being flooded ~80×/s by
`rc rc0: receive overflow` from an unrelated onboard IR receiver (`ite_cir`
driver, long-standing bug) — a red herring, but it buried the USB events.
`modprobe -r ite_cir` silences it.

### Useful console commands (while Locked)

`version`, `ccd`, `sysinfo`, `wp`, `help`. `GscFullConsole` is `IfOpened` by
default, so most other commands need CCD open first.

---

## 6. Unlocking: CCD open, TPM wipe, factory reset

### Default capability set (all `Default`, i.e. locked)

The ones that matter:

```
FlashAP         IfOpened     <- needed to write the AP flash over CCD
OverrideWP      IfOpened
GscFullConsole  IfOpened
OpenNoTPMWipe   IfOpened     <- so opening while Locked DOES wipe the TPM
OpenNoDevMode   IfOpened
OpenFromUSB     IfOpened     <- so `ccd open` over the cable is refused
BatteryBypassPP Always       <- battery removal bypasses physical presence
FlashRead       Always       <- reads work without opening anything
UartGscRxAPTx   Always       <- AP boot log readable without opening anything
```

Two of those are genuinely useful before you've unlocked anything: you can
**read the flash** and **read the AP boot log** with CCD still Locked.

### `ccd open` refusal, and what it tells you

```
ccd_open denied: run from AP in devmode, remove batt, or short chassis_open
Access Denied
```

Three doors, and on a sealed tablet two of them are the same door:

- **run from AP in devmode** — needs `gsctool -a -o` from a booted ChromeOS.
- **remove batt** — the practical route. Requires opening the case.
- **short chassis_open** — a chassis-intrusion input. Also inside the case, and
  the Chromium CCD docs don't document it for this class of device; *inferred*
  that it isn't wired on a sealed tablet.

### With the battery disconnected

```
> wp
Flash WP: disabled
 at boot: follow_batt_pres
```

Battery presence gates write protect on this board, so unplugging it drops WP.
Then:

```
> ccd open
[tpm_reset_now(1)]                       <- the "1" means wipe-first
verify_reserved: EPS not loaded
tpm_manufactured: NOT manufactured
get_decrypted_eps: getting eps
tpm_endorse: RSA cert install success
tpm_endorse: ECC cert install success
endorsement_complete(): SUCCESS
tpm_manufactured: manufactured
[CCD opened]
[CCD state: UARTAP+TX UARTEC+TX I2C SPI USBEC+TX]
...
read_tpm_nvmem: object at 0x1008 is smaller than 40
```

**This is the moment the original fault was fixed.** The TPM was wiped back to
blank and re-manufactured itself from scratch, reinstalling its endorsement
certificates — and `0x1008` went from *"not found"* to *"is smaller than 40"*,
i.e. it now **exists**. ("Smaller than 40" is unrelated and benign: the GSC
wants a 40-byte structure for an EC-hash feature this board doesn't use, hence
the harmless `load_ec_hash error: 0x1203`.)

The wipe also cleared the developer-mode flag (`TPM:` went from `dev_mode` to
empty), resolving the contradiction on the boot screen.

#### A hang worth knowing about

The first `ccd open` attempt produced an endless loop, ~1.1 s apart:

```
[Compaction done, went from 14352 to 276 bytes, status 0]
```

Identical byte counts each cycle — no forward progress, and writing to the GSC's
internal flash continuously. **Fix: pull the charger (battery already out), wait
10 s, reconnect.** That NVMEM is a log-structured store with atomic commits, so
it's designed to survive losing power mid-write. The retry then completed
instantly and cleanly. Undocumented anywhere I could find.

### `ccd reset factory` — do this

```
> ccd reset factory
> ccd
State: Opened
Flags: 0x400004
Capabilities: 5555555555010000      <- every capability now "1=Always"
> wp
Flash WP: forced disabled
 at boot: forced disabled
```

**This is the most important durable outcome of the whole exercise.** It sets
every CCD capability to `Always` and permanently disables write protect, which
means:

- CCD can be opened over the cable at any time, with no physical presence, no
  developer mode, and **no teardown**.
- The AP flash can be read and written over the cable indefinitely.

Any future firmware work on this device needs only the SuzyQ cable. That is the
safety net; it's why a bricked firmware is now a recoverable inconvenience
rather than another heat-gun session.

---

## 7. Teardown

**The Slate opens from the front — the display comes off, and it is adhesive-mounted.** iFixit's warning is blunt: heat it properly or you will break the
screen. (I cracked one corner; the panel and digitiser still worked.)

Tools: heat source (iOpener / hair dryer / heat gun on low), suction cup,
plastic opening picks, **T3 and T2** Torx, nylon-tipped tweezers.

Sequence to reach the battery connector:

1. Heat the perimeter thoroughly, working around several times rather than
   parking the heat in one place.
2. Suction cup to raise an edge, picks to work around. Know which edge carries
   the display flex before levering.
3. Disconnect the three flat cables from the screen — or leave it loosely
   connected, which is much more useful while testing.
4. Remove the **two black adhesive strips** across the battery/board boundary.
5. Remove the **two black screws** holding the copper heat pipe (T3).
6. Remove the **eight screws** holding the metal plate: **4 blue 3 mm, 2 black
   3 mm, 1 pink 3 mm, 1 pink 2 mm**. The 2 mm one needs **T2**. The pink screws
   are visibly pink on the board.
7. Lift the metal plate away.
8. **Now** the connectors are visible: two speaker plugs (red/black wire pairs
   at the left and right edges), **one battery plug**, and four flat cables.
   Only the battery plug needs disconnecting.

Gotchas:

- **The battery connector is not visible until the metal plate is off.** This is
  the single most confusing part of the teardown.
- **Sort the screws by type.** Four types across eight holes and one is a
  different length — a 3 mm in the 2 mm hole can punch through.
- Don't kink the copper heat pipe.
- Don't pry, flex, or puncture the battery. It only needs unplugging; it's a
  glued pouch cell and it stays put.
- Tape over any cracked glass immediately to contain shards and slow crack
  propagation, and blow out glass dust before it migrates under the board.

### Thermal interface — do not skip

The Slate is **fanless**; the heat spreader is the entire cooling system.

- The SoC package presents **two bare silicon dies** in a metal retaining frame.
  Bare die needs **thermal paste** — a thin film. A grain-of-rice blob per die;
  clamping pressure spreads it. Clean both surfaces with 99% IPA first.
- Four **green thermal pads** sit in a shielded window beside the SoC, bridging
  a real air gap to the plate. Paste cannot do that job. Match the thickness of
  the intact pads, or use **thermal putty**, which conforms to an unknown gap
  and is far more forgiving than guessing pad thickness.
- Non-conductive paste only (Arctic MX-4/MX-6, Noctua NT-H1/H2). **Never liquid
  metal** — it's conductive and would destroy the board.
- Bring the plate screws down gradually in a cross pattern.

Reassembly adhesive: no pre-cut kit exists for this device, so cut your own.
**Tesa 61395** (2 mm and 3 mm) is the standard and is reworkable with heat;
3M 300LSE is the equivalent alternative. For a wall-mounted device, a light tack
at corners and mid-edges is plenty and leaves it reopenable in minutes.

### Power behaviour with the battery out

With the battery disconnected and the charger attached, **the EC powers the AP
up automatically** and there is no way to keep it off — a 10 s power-button hold
shuts it down and it comes straight back. `sysrst on` from the GSC console did
not prevent it either. Plan around this rather than fighting it.

(Also observed, *unexplained*: with the charger in the **left** port the charge
LED blinked irregularly; in the **right** port it was steady. Both orange. A
blinking charge LED generally indicates a power-negotiation or battery fault,
but this was never chased down. Use the right port for charging.)

---

## 8. Flashing

### What worked

**MrChromebox's Firmware Utility Script, run from inside ChromeOS in developer
mode**, installing **UEFI (Full ROM)**:

```bash
cd; curl -LO mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
```

Getting a shell: at the ChromeOS login/welcome screen, `Ctrl+Alt+F2`
(`Ctrl+Alt+→` on a Chromebook keyboard), log in as `root` with no password.
`Ctrl+Alt+F1` returns to the GUI. Connect WiFi at the welcome screen *before*
dropping to a console. `Ctrl+D` skips the developer-mode boot delay.

**Notably, the script reported write protect as *enabled* and the Full ROM
install still succeeded.** *Unknown* why: the internal path (flashrom through
the chipset's own SPI controller) evidently managed a status-register write that
the CCD path could not. Worth flagging as the practical lesson — **try the
in-ChromeOS script before any chip-level work.**

Run a fan over the SoC while flashing if the heat spreader is off.

### What did not work: writing over CCD

Reads over CCD were reliable and reproducible. Writes were blocked by the flash
chip's own protection, which could not be cleared:

```
$ flashrom -p raiden_debug_spi:target=AP -c "$CHIP" --wp-status
Protection range: start=0x00c00000 length=0x00400000 (upper 1/4)
Protection mode: hardware

$ flashrom -p raiden_debug_spi:target=AP -c "$CHIP" --wp-disable
Failed to apply new WP settings: unexpected WP configuration read back from chip
Note: hardware status register protection is enabled. The chip's WP# pin must be
set to an inactive voltage level to be able to change the WP settings.
```

The protected range (`0xC00000`–`0xFFFFFF`, the top quarter) is the read-only
firmware section, and it sits inside the IFD BIOS region, so a Full ROM write
cannot avoid it.

Everything tried, all failing identically: `wp disable` and
`ccd reset factory` (GSC reported `forced disabled` both currently and at boot),
AP running, AP held in reset via `sysrst on`, battery in, battery out, full GSC
power cycles. *Unknown* whether the GSC's WP output doesn't reach the chip's WP#
pin on this board, or the `raiden_debug_spi` transport simply can't perform
`WRSR`. The `--wp-disable` step is documented as necessary for a first-time UEFI
flash, so this may be a known rough edge.

The CH341A route was prepared but never needed. For reference: with the board
unpowered nothing drives WP#, and the programmer supplies the pin states itself,
which is precisely the case the cable can't reproduce.

---

## 9. The pogo pins / detachable keyboard

The `Whiskers Tablet Mode Switch` input device appears **whether or not a
keyboard is attached** — it's the EC advertising the switch it would use. With
no base it reads "tablet" permanently, which is desirable: desktops use it to
turn on touch-first behaviour and the on-screen keyboard.

The bottom contacts are for the official keyboard, and the protocol is fully
documented because it's open source:

- **It is USB.** Google's own docs: *"Hammer is the base of a detachable device,
  connected via USB over pogo pins."* `Whiskers` is the Slate's member of the
  `hammer` family (alongside `hammer`, `wand`, `wallaby`, `staff`).
- The base runs its own EC firmware on an **STM32F072** and carries a touchpad
  with separately updatable firmware.
- On the tablet side, a daemon called **`hammerd`** waits for a base on the pogo
  port and updates base + touchpad firmware before the UI starts.
- **Consequence for Linux:** any hammer-family base appears as an ordinary USB
  HID keyboard and touchpad, no driver work needed. And those pads are
  effectively a USB 2.0 port, so a DIY adapter is conceivable.
- **It cannot charge the tablet.** Power flows tablet → base. Charging is USB-C
  only (and there are two of those).

Reference: <https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/hammerd/README.md>

---

## 10. Linux hardware status

Verified working under a current kernel (7.2.x) with MrChromebox UEFI firmware:

- Display at native 3000×2000; GNOME picks sane HiDPI scaling automatically
- **Touchscreen** — worked perfectly even in the graphical installer
- Stylus (separate input node; Pixelbook Pen should work)
- WiFi (`iwlwifi`, Intel 7265)
- Internal eMMC (`/dev/mmcblk0`, 233 GB) — healthy, plus `mmcblk0boot0`,
  `mmcblk0boot1` housekeeping devices
- Sensors via `cros_ec`: `cros-ec-accel`, `cros-ec-gyro`, `cros-ec-light`,
  `cros-ec-activity`, plus an `acpi-als`. So auto-rotate and ambient-light
  brightness both have real hardware behind them.

Not working:

- **Audio — WORKING.** Speakers confirmed audible. See "Audio: what actually
  fixed it" below for the short version; the list that follows is the
  investigation, kept because most of it was necessary and two of its
  predictions were wrong. The **Intel AVS driver binds**
  — `AVS PROBE`, `AVS DMIC`, `AVS I2S MAX98373`, `AVS HDMI` all appear. But
  enumeration is not the same as working, and this needs more than userspace
  config. Per [nocturne-linux](https://github.com/kabili207/nocturne-linux), the
  full requirement list is:

  1. **Kernel 6.8+** with `CONFIG_SND_SOC_INTEL_AVS`,
     `CONFIG_SND_SOC_INTEL_SKL_HDA_DSP_GENERIC_MACH`,
     `CONFIG_SND_SOC_INTEL_AVS_MACH_MAX98373`,
     `CONFIG_SND_SOC_INTEL_AVS_MACH_DMIC` (all `=m`). **Already satisfied** on
     nixpkgs' kernel — the AVS cards enumerate, which proves the machine
     drivers are built and bound.
  2. **Module options** — `config/modprobe/snd-avs.conf`, three lines and
     probably the single most important missing piece:

     ```
     options snd-intel-dspcfg dsp_driver=4
     options snd-soc-avs ignore_fw_version=1
     options snd-soc-avs obsolete_card_names=1
     ```

     `dsp_driver=4` forces the AVS driver; `ignore_fw_version=1` is required
     because the ChromeOS-extracted DSP blobs don't match the version the
     driver expects, so without it firmware load fails.
  3. **AVS DSP firmware and topology blobs** → `/lib/firmware/intel/avs/*.bin`
     and `/lib/firmware/intel/avs/skl/*.bin`. These are prebuilt `.bin` files
     committed to `config/firmware/avs/` — the `avs-topology-xml` submodule is
     only the *source* for regenerating them, so it isn't needed.

     **Verified:** on a stock NixOS install `/lib/firmware/intel/avs/` does not
     exist at all, and no `snd`/`avs` modprobe options are set. So the cards
     enumerating is the machine driver registering ahead of DSP firmware load —
     the firmware is genuinely absent, not merely version-mismatched.
  4. **ALSA UCM2 profile** → `share/alsa/ucm2/conf.d/avs_max98373/Google-Nocturne-1.0.conf`.
     **nocturne-linux's own profile is a stub that cannot work** — verified by
     reading it on the device:

     ```
     Syntax 7
     SectionUseCase."HiFi" { File "HiFi.conf" }
     ```

     There is no `HiFi.conf` in that repo, and none anywhere under
     `ucm2/Intel/avs/*` in `alsa-ucm-conf` either, so the include dangles and
     the profile fails to load outright. It also carries **no `BootSequence`**,
     so nothing initialises the two MAX98373s and nothing ever flips
     `Left/Right Spk Switch` on — silent even if the include resolved.

     A UCM profile is not optional here: the speaker PCM is card device **1**,
     and **card 1 has no device 0 at all**, so WirePlumber's non-UCM fallback
     probes `hw:1,0` and finds nothing.

     The fix is to reuse upstream's **`Google-Atlas-1.0`** profile under this
     board's card longname. Atlas is the same machine driver (`avs_max98373`)
     with the same two MAX98373s, so the control names — which come from the
     codec and machine drivers, not the board — are identical, and its
     `PlaybackPCM "hw:${CardId},1"` already matches. It ships a real
     70-line `BootSequence` (DAI select muxes, output voltage, digital volume,
     DHT/BDE limiter setup) and a `Google-Atlas-1.0-HiFi.conf` that enables the
     speaker switches.
  5. **WirePlumber config** → `wireplumber.conf.d/51-increase-headroom.conf`
     and `52-volume-limit.conf`. (`53-device-names.conf` exists in the repo but
     `setup.sh` doesn't install it.)
  6. **Two kernel patches** — `avs-dmic-late-probe-dapm-fix` and
     `avs-max98373-late-probe-dapm-fix`, both DAPM init-timing fixes in
     `sound/soc/intel/avs/boards/`. Written against 6.8; *unknown* whether they
     still apply, or are even still needed, on 7.x. **Try without them first**
     — a patched kernel is a large build on 2 Y-series cores (4 threads).
  7. **A coreboot change.** This is the one that's easy to miss:
     `nhlt-max98373-add-32bit-render-format.patch` patches
     `src/soc/intel/skylake/nhlt/max98373.c` — that is **coreboot, not the
     kernel**. NHLT is an ACPI table emitted by *firmware* describing the I2S
     link format, and the MAX98373 needs a 32-bit container for TDM. A stock
     MrChromebox ROM won't carry it, which is why nocturne-linux ships its own
     coreboot submodule, `core.patch` and `rebuild-firmware.sh`.

  **Both 6 and 7 turned out to be unnecessary — this was wrong.** The speakers
  work on a **stock MrChromebox UEFI ROM** with an unpatched kernel: no
  coreboot rebuild, no NHLT patch, no reflash, and neither DAPM patch. The
  prediction that there would be no output "until the NHLT entry is right" was
  simply false — the NHLT table this board's own firmware already emits
  (`ACPI: NHLT ... GOOGLE NOCTURNE`) is sufficient. Anyone following this guide
  should stop after step 5 and test before contemplating a firmware rebuild.

  The speakers are 2× Maxim MAX98373 over TDM/I2S.

  (Successive claims in this file about audio scope were all wrong, and are
  left on the record: first "only a UCM2 profile", then "three kernel patches",
  then "five userspace/firmware pieces, two possible kernel patches and one
  coreboot patch". The truth is smaller than the last two: **firmware blobs,
  modprobe options, and a working UCM2 profile.** Nothing else.)

  Note the general chrultrabook warning *"using AVS on a device with max98357a
  will blow your speakers"* does **not** apply — this board is MAX98373, which
  is what nocturne-linux targets.

  On a non-FHS distro the UCM2 files are found via the `ALSA_CONFIG_UCM2`
  environment variable rather than being dropped in `/usr/share`.
- **Camera.** Known dead end on this device.

Backlight (**verified**): one device, `/sys/class/backlight/intel_backlight`,
`max_brightness` **65535**, and `bl_power` is present and readable. So a display
on/off toggle driven from sysfs has something real to write to.

*Unknown / untested:*

- Whether `iio-sensor-proxy` actually delivers working auto-rotate
- Whether `intel_backlight` honours *writes* to `bl_power` (the file exists;
  setting `brightness` to 0 definitely works as a fallback)
- `keyd` scancodes for the Whiskers top row (no keyboard to test)

### Audio: what actually fixed it

Three things, all userspace, no firmware or kernel work:

1. The AVS DSP firmware blobs in `/lib/firmware/intel/avs/{,skl/}`.
2. The modprobe options (`dsp_driver=4`, `ignore_fw_version=1`,
   `obsolete_card_names=1`).
3. **A UCM2 profile that actually loads** — upstream's `Google-Atlas-1.0`
   reused under this board's card longname, because nocturne-linux's own
   profile is a broken stub (see §10 item 4).

Confirmation that UCM is the thing carrying it, rather than a generic fallback:

```
$ alsaucm -c avs_max98373 list _devices/HiFi
  0: Speaker
    Speakers
$ wpctl inspect <sink>
    api.alsa.card.name     = "avs_max98373"
    api.alsa.path          = "hw:avsmax98373,1"
    device.profile.name    = "HiFi: Speaker: sink"
    node.name = alsa_output.platform-avs_max98373.26.auto.HiFi__Speaker__sink
```

`HiFi: Speaker: sink` is the UCM profile. A generic fallback would instead read
`stereo-fallback`, which is what the HDMI node shows.

#### Card numbers are not stable across boots

This wasted a round of testing. The speaker card was **card 1** on one boot and
**card 0** on the next, with `avs_dmic` taking the slot it vacated:

```
 0 [avsmax98373  ]: avs_max98373 - avs_max98373     <- was card 1 last boot
 1 [avsdmic      ]: avs_dmic     - avs_dmic
 2 [hdaudioB0D2  ]: hdaudioB0D2  - hdaudioB0D2
 3 [PROBE        ]: avs_probe_mb - AVS PROBE
```

So `hw:1,1` is a moving target and any note recording it is wrong by the next
reboot. **Always address the card by name**, which is stable:

```
speaker-test -D plughw:CARD=avsmax98373,DEV=1 -c 2 -t sine -l 1
```

This is also why UCM matters beyond routing: PipeWire binds by card name, so it
is immune to the renumbering that hand-written `hw:N,M` tests are not.

#### Two more traps in testing

- **The stock test file is mono.** `Front_Center.wav` is 1-channel, the speaker
  PCM wants 2, and `aplay -D hw:...` refuses with `Channels count non
  available` — which reads like a broken device. Use `plughw:` (inserts the
  conversion) or a stereo file.
- **`amixer sget` is the wrong verb** for these controls; they are not simple
  mixer elements, so it prints nothing at all and looks like an empty card.
  Use `cget`:

  ```
  $ amixer -c 0 cget name='Left Spk Switch'
    : values=on
  ```

**Evidence the hardware and firmware side are fine** (all from `journalctl -k`,
which `wheel` can read without `sudo`):

```
ACPI: NHLT 0x000000007A9C5000 0019DC (v05 GOOGLE NOCTURNE ...)
max98373 i2c-MX98373:00: MAX98373 revisionID: 0x43
max98373 i2c-MX98373:01: MAX98373 revisionID: 0x43
max98373 i2c-MX98373:00: Reset completed (retry:0)
max98373 i2c-MX98373:01: Reset completed (retry:0)
snd_soc_avs 0000:00:1f.3: bound 0000:00:02.0 (ops intel_audio_component_bind_ops [i915])
```

Both codecs answer on I2C and reset cleanly, the NHLT table is present, and
four cards register (`hdaudioB0D2`, `avs_max98373`, `avs_probe_mb`,
`avs_dmic`) all with longname `Google-Nocturne-1.0`. `avs_probe_mb` and
`avs_dmic` only appear once topology parses, so the DSP blobs did load. Module
options read back correctly from sysfs:

```
/sys/module/snd_intel_dspcfg/parameters/dsp_driver     = 4
/sys/module/snd_soc_avs/parameters/ignore_fw_version   = Y
/sys/module/snd_soc_avs/parameters/obsolete_card_names = Y
```

`obsolete_card_names=1` matters for UCM: it is what keeps the card named
`avs_max98373`, which is the directory UCM2 matches under `conf.d/`.

## 11. If it won't boot

**Check the UEFI boot order first.** After flashing MrChromebox firmware and
installing an OS, the boot order can end up pointing at the wrong entry, and the
symptom is indistinguishable from a dead machine — no screen output, nothing.
Press **Esc** at the boot logo to get the boot menu and pick the right entry,
then fix the order in setup. This has already been the cause once on this
device, and it costs thirty seconds to rule out before assuming anything worse.

**You are not locked out.** `ccd reset factory` set every CCD capability to
`Always` and permanently disabled write protect, so the SuzyQ cable gets you
full access with no teardown and no physical presence.

1. Charger into the **right** USB-C port, SuzyQ into the **left**, adapter
   screws facing the rear.
2. `lsusb | grep 18d1:5014`, then `sudo picocom -b 115200 /dev/ttyUSB0`.
3. `ccd` should already say `State: Opened` (or `ccd open` will now succeed
   instantly). `wp` should say `forced disabled`.
4. **Watch the AP boot log on `/dev/ttyUSB1`** while power-cycling. This is the
   highest-value diagnostic on the device and needs no unlocking.
5. To reflash firmware:

```bash
CHIP="GD25Q128E/GD25B128E/GD25R128E/GD25Q127C"
sudo flashrom -p raiden_debug_spi:target=AP -c "$CHIP" -r now1.rom
sudo flashrom -p raiden_debug_spi:target=AP -c "$CHIP" -r now2.rom
sha256sum now1.rom now2.rom       # must match before trusting anything
sudo flashrom -p raiden_debug_spi:target=AP -c "$CHIP" -w <rom> --ifd -i bios -N
```

If the write is refused on protection grounds again, fall back to the CH341A
with the board fully unpowered (battery unplugged, charger out).

Remember the AP will auto-power-on whenever the charger is attached with the
battery disconnected — the tablet appearing "dead" during a flash is expected,
since the GSC holds the CPU in reset while it drives the flash bus.

---

## 12. Restoring stock ChromeOS

Two independent things have to be put back: the **firmware** and the **OS**.

### Firmware

The stock 16 MB dump lives at `chromebook-pixel-slate.rom` (taken as two
byte-identical reads with the correct chip definition —
`sha256 5b37d5d4269f2f6598836c45822d17a3d2f6e327cea5d6e816181dd555a91178`).
**This file is irreplaceable; keep it somewhere durable and off the machine.**

```bash
CHIP="GD25Q128E/GD25B128E/GD25R128E/GD25Q127C"
sudo flashrom -p raiden_debug_spi:target=AP -c "$CHIP" \
  -w chromebook-pixel-slate.rom --ifd -i bios -N
```

MrChromebox's script can also restore stock firmware directly if a UEFI Linux
install is still bootable.

### OS

The Full ROM flash makes the existing ChromeOS install on the eMMC unbootable —
ChromeOS needs its own firmware. After restoring the firmware, reinstall from a
recovery USB (§4).

### Caveats

- Restoring firmware does **not** restore write protect. `ccd reset factory`
  disabled it permanently.
- CCD stays open with all capabilities `Always`.
- The TPM has been wiped and re-manufactured, so any data that was encrypted
  against the old TPM state is gone — it already was, before any of this.
- ChromeOS on `nocturne` is past end-of-support, so a restored device gets no
  further updates.

---

## 13. Sources

- [MrChromebox firmware docs](https://docs.mrchromebox.tech/) — [write protect](https://docs.mrchromebox.tech/docs/firmware/wp/disabling.html) · [SuzyQ unbricking](https://docs.mrchromebox.tech/docs/support/unbricking/unbrick-suzyq.html) · [CH341A unbricking](https://docs.mrchromebox.tech/docs/support/unbricking/unbrick-ch341a.html) · [known issues](https://docs.mrchromebox.tech/docs/known-issues.html)
- [Cr50 CCD documentation](https://chromium.googlesource.com/chromiumos/platform/ec/+/fe6ca90e/docs/case_closed_debugging_cr50.md) · [CCD how-tos](https://chromium.googlesource.com/chromiumos/platform/ec/+/cr50_stab/docs/ccd_howtos.md) · [hdctools CCD](https://chromium.googlesource.com/chromiumos/third_party/hdctools/+/HEAD/docs/ccd.md)
- [Cr50 and verified boot troubleshooting](https://chromium.googlesource.com/chromiumos/platform/ec/+/cr50_stab/docs/cr50_vboot_troubleshooting.md)
- [Firmware Management Parameters](https://www.chromium.org/chromium-os/fwmp/) · [coreboot `antirollback.h`](https://doxygen.coreboot.org/da/d21/antirollback_8h.html)
- [hammerd / detachable bases](https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/hammerd/README.md)
- [kabili207/nocturne-linux](https://github.com/kabili207/nocturne-linux) — device-specific patches, UCM2 profiles, firmware
- [olm3ca/Pixel-Slate](https://github.com/olm3ca/Pixel-Slate) · [chrultrabook docs](https://docs.chrultrabook.com/) · [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)
- [iFixit Pixel Slate guides](https://www.ifixit.com/Device/Google_Pixel_Slate) · [erichVK5 SuzyQ PCB](https://github.com/erichVK5/erichVK5-suzy-Q-cable-v1)
- [Chromium debug button shortcuts](https://chromium.googlesource.com/chromiumos/docs/+/master/debug_buttons.md)
