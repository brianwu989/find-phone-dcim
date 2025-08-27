# find-phone-dcim (Linux)

Copy photos/videos from DCIM/Camera, DCIM/*360* and mp3 from any *recordings* folders
on Android phones (MTP/GVFS) to ~/Downloads/<date>.

Features
- Detects GVFS MTP (/run/user/$UID/gvfs/mtp:host=*) and USB mounts (/media/$USER, /run/media/$USER)
- Scans: (1) DCIM/Camera (2) DCIM/*360* (3) */recordings* (mp3 only)
- Modes: --mode=range (default), --mode=mtime
- Flags: --dry-run, --debug

Usage
  ./find_phone_dcim.sh --dry-run --debug 2025-08-26
  ./find_phone_dcim.sh 2025-08-26
  ./find_phone_dcim.sh --mode=mtime --dry-run 2025-08-26
# find-phone-dcim (Linux)

Copy photos/videos from DCIM/Camera, DCIM/*360* and mp3 from recordings folders on Android phones (MTP/GVFS) to ~/Downloads/<date>.

## ✨ Features
- Detects: GVFS MTP (/run/user/$UID/gvfs/mtp:host=*), USB mounts (/media/$USER, /run/media/$USER)
- Scans: (1) DCIM/Camera (photos + videos) (2) DCIM/*360* (photos + videos) (3) */recordings* (mp3 only)
- Modes: --mode=range (default, [DATE, DATE+1)), --mode=mtime (calendar day)
- Flags: --dry-run (preview), --debug (print mounts/paths)

## 🔧 Installation
git clone https://github.com/brianwu989/find-phone-dcim.git
cd find-phone-dcim
sudo ./install.sh

## 🚀 Quick Start
find-phone-dcim --dry-run --debug 2025-08-26
find-phone-dcim 2025-08-26
find-phone-dcim --mode=mtime 2025-08-26

## 📄 License
MIT License (see LICENSE)
