# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, home-manager, impermanence, ... }:

{
  imports =
    [
      "${impermanence}/nixos.nix"
      #(import "${home-manager}/nixos")
      home-manager.nixosModules.home-manager
      ./hardware-configuration.nix
    ];

  nix = {
    settings = {
      # auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
  };
  nixpkgs.config.allowUnfree = true;

  # filesystems
  fileSystems."/".options = [ "compress=zstd" "noatime" ];
  fileSystems."/home".options = [ "compress=zstd" "noatime" ];
  fileSystems."/nix".options = [ "compress=zstd" "noatime" ];
  fileSystems."/persist".options = [ "compress=zstd" "noatime" ];
  fileSystems."/persist".neededForBoot = true;

  fileSystems."/var/log".options = [ "compress=zstd" "noatime" ];
  fileSystems."/var/log".neededForBoot = true;

  #boot.kernelParams = [
  #  "systemd.log_level=debug"
  #  "systemd.log_target=console"
  #];
  #boot.kernelParams = [ "psmouse.synaptics_intertouch=1" ];
#boot.blacklistedKernelModules = [ "psmouse" ];

#boot.kernelModules = [ "i2c_hid" "i2c_hid_acpi" ];
boot.kernelParams = [
  "i2c_hid_acpi.disable_watchdog=1"
];


boot.extraModulePackages = [ ];  # Leave empty unless you're building out-of-tree stuff



  # reset / at each boot
  boot.initrd = {
    enable = true;
    supportedFilesystems = [ "btrfs" ];

    luks.devices = {
      "cryptroot".device = lib.mkForce "/dev/disk/by-partlabel/cryptroot";
    };
    postDeviceCommands = ''
      echo "===== Starting restore-root script in initrd =====" > /dev/kmsg
  
      mkdir -p /mnt
      mount -o subvol=/ /dev/mapper/cryptroot /mnt
  
      echo "===== Mounted /dev/mapper/cryptroot on /mnt =====" > /dev/kmsg
  
      btrfs subvolume list -o /mnt/root |
        cut -f9 -d' ' |
        while read subvolume; do
          echo "deleting /$subvolume subvolume..." > /dev/kmsg
          btrfs subvolume delete "/mnt/$subvolume"
        done &&
        echo "deleting /root subvolume..." > /dev/kmsg &&
        btrfs subvolume delete /mnt/root
  
      echo "restoring blank /root subvolume..." > /dev/kmsg
      btrfs subvolume snapshot /mnt/root-blank /mnt/root
  
      umount /mnt
      echo "===== restore-root done =====" > /dev/kmsg
    '';

  
  };

  # configure impermanence
  environment.persistence."/persist" = {
    directories = [
      "/etc/nixos"
      "/var/lib/nixos"
    ];
    files = [
      "/etc/machine-id"
      "/etc/modprobe.d/blacklist.conf"
      #"/etc/ssh/ssh_host_ed25519_key"
      #"/etc/ssh/ssh_host_ed25519_key.pub"
      #"/etc/ssh/ssh_host_rsa_key"
      #"/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  security.sudo.extraConfig = ''
    # rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";

  environment.systemPackages = with pkgs; [
    git
    vim
    firefox
    _1password-gui
    google-chrome
    docker
    remmina
    freerdp3
    kdePackages.kio-fuse #to mount remote filesystems via FUSE
    kdePackages.kio-extras #extra protocols support (sftp, fish and more)
    kdePackages.dolphin-plugins
    android-file-transfer
    fusuma
    #i3status
    dmenu
    arandr
    bluetuith
    #greenclip
    #rofi
    pavucontrol
    parcellite
    parted
    wezterm
    #i3lock
    #i3lock-color
    #xautolock
    pkgs.kitty
    wl-clipboard
    wofi
    unzip
    gnome-keyring
    gnupg
    pinentry-bemenu
    libinput
    evtest
  ];

  fonts.packages = with pkgs; [
    font-awesome
  ];

  users.mutableUsers = false;

  users.users.edm = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "kvm" "input" "adbusers" ];

    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkde01zd1rp7TggQQ8LKj6yhyZe7Ld97tH0uq4/eQnPXgFdu6dXwvGN+JJk+4rTN8FBSIMrnZN0q/Nk6XbtvBMZpv1HDWgsD2DjMPOIRXHAwnJ7r/jjMWlWEqdvv/zd/9Jv7phi0xtE+HFI9ygYvgshdgS44E9SEqA8X6266zm4fB5AyH87oZxBl3ySbF8fBES0K+wiUKLBn6EAGqOD/SjMMV27hX6/x2Kz4uGYHzbTBWJXBcwgPbDBTEy6lQEmfo4s2LkmSBSjNrQWju5R2rcdt8QPOBQwvoYESq/AX48ZzFAV3I6d0aVU5LfslOefhtnzCeVNbMJccGMQn3nZI9z info@nickjanssen.com" ];

    # passwordFile needs to be in a volume marked with `neededForBoot = true`
    #passwordFile = "/persist/passwords/edm";
    hashedPassword = "$6$vT9dh0Ug46.qyIcJ$x3t7mtewm6looyklFIdt631V34tGTUVpQ4Uk2ra4hDY7ODImScgcL2.amqcFAu7b2Cbb65JaVqJoCIq.QvFfC0";
  };

  home-manager.users.edm = { pkgs, ... }: {
    # home.packages = [ pkgs.atool pkgs.httpie ];
    programs.bash.enable = true;
  
    # The state version is required and should stay at the version you
    # originally installed.
    home.stateVersion = "24.11";
  };

  services.openssh = {
    enable = true;
    allowSFTP = false; # Don't set this if you need sftp
    settings = {
      PasswordAuthentication = false;          
    };
    extraConfig = ''
      AllowTcpForwarding yes
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
    '';
  };

  services.xserver.enable = true;
  #services.xserver.windowManager.i3.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.plasma5.enable = false;

  security.pam.services.gdm.enableGnomeKeyring = true;

  services.libinput.enable = true;
  services.libinput.touchpad.naturalScrolling = true;

  services.flatpak.enable = true; 
  #xdg.portal.enable = true;
  #xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];

  services.gnome.gnome-keyring.enable = true;

  programs.hyprland.enable = true;
  programs.waybar.enable = true;
  programs.adb.enable = true;

  #programs.slock.enable = true;

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.docker.enable = true;

  #services.blueman.enable = true; # GUI manager (optional but recommended)
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Optional: For better compatibility with some adapters/devices
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  #services.xserver.libinput = {
  #  enable = true;
  #  naturalScrolling = true; 
  #  # additionalOptions = ''MatchIsTouchpad "on"'';
  #};

  # Open ports in the firewall.
  #networking.firewall = {
  #  enable = true;
  #  allowedTCPPorts = [ 22 ];
  #  allowedUDPPorts = [ ];
  #};

  #system.copySystemConfiguration = true;

  # Read the doc before updating
  system.stateVersion = "22.11";

}

