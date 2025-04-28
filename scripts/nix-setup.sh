DISK=/dev/nvme0n1

sgdisk --zap-all "$DISK"
wipefs --all "$DISK"

sleep 5

parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 512MiB
parted "$DISK" -- set 1 boot on
mkfs.vfat "$DISK"p1

# leave room for windows
parted "$DISK" -- mkpart primary 512MiB 100%
parted "$DISK" -- name 2 cryptroot

cryptsetup luksFormat "$DISK"p2
cryptsetup open "$DISK"p2 cryptroot

mkfs.btrfs -f -L Butter /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/persist
btrfs subvolume create /mnt/log

# We then take an empty *readonly* snapshot of the root subvolume,
# which we'll eventually rollback to on every boot.
btrfs subvolume snapshot -r /mnt/root /mnt/root-blank

umount /mnt

# Mount the directories

mount -o subvol=root,compress=zstd,noatime /dev/mapper/cryptroot /mnt

mkdir /mnt/home
mount -o subvol=home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home

mkdir /mnt/nix
mount -o subvol=nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix

mkdir /mnt/persist
mount -o subvol=persist,compress=zstd,noatime /dev/mapper/cryptroot /mnt/persist

mkdir -p /mnt/var/log
mount -o subvol=log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log

# don't forget this!
mkdir /mnt/boot
mount "$DISK"p1 /mnt/boot

# create configuration
nixos-generate-config --root /mnt

# now, edit nixos configuration and nixos-install
cp ./configuration.nix /mnt/etc/nixos/configuration.nix
cp /mnt/etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
mkdir -p /mnt/persist/etc/nixos/
cp /mnt/etc/nixos/configuration.nix /mnt/persist/etc/nixos/configuration.nix
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/hardware-configuration.nix

git config user.email "installer@local"
git config user.name "installer"
git add hardware-configuration.nix
git commit -m "tmp"

nixos-install --no-root-passwd --root /mnt --flake .#nixos

#reboot
