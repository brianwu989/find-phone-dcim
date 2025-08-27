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
