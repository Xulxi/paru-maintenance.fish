#!/usr/bin/env fish
# ---------------------------------------------
# Paru maintenance script for CachyOS / BTRFS
# Automatically creates a Timeshift snapshot before updates
# ---------------------------------------------

# force sudo
sudo -v
echo

# colors
set green (set_color green)
set yellow (set_color yellow)
set red (set_color red)
set normal (set_color normal)

# preferred terminal; set manually
set preferred_terminal ghostty

if not type -q $preferred_terminal
    echo $red"Error: preferred terminal ($preferred_terminal) is not installed"$normal
    exit
end

# ask if user wants shutdown
set shutdown 0
read -P $yellow"Shutdown after maintenance? [Y/n] "$normal choice
if test $choice = y -o $choice = Y
    set shutdown 1
end
echo

# track errors
set failed 0

# header
echo $yellow"==== Paru Maintenance ===="$normal
echo

# 1️⃣ create Snapper pre-update snapshot
echo $green"Creating pre-update Snapper snapshot..."$normal
sudo snapper create --description pre-update --cleanup-algorithm number >/dev/null
if test $status -ne 0
    set failed 1
end
echo

# 2️⃣ update GRUB so snapshot appears in boot menu
echo $green"Updating GRUB configuration..."$normal
sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
if test $status -ne 0
    set failed 1
end
echo

# 3️⃣ clear package cache
echo $green"Clearing package cache..."$normal
paru -Sc --noconfirm >/dev/null
echo

# 4️⃣ remove orphaned packages
echo $green"Removing orphaned packages..."$normal
if paru -Qdtq >/dev/null
    paru -Rns --noconfirm (paru -Qdtq) >/dev/null
    if test $status -ne 0
        set failed 1
    end
end
echo

# 5️⃣ fetch pkglist safely
echo $green"Fetching pkglist..."$normal
if test -f ~/pkglist1.txt
    mv ~/pkglist1.txt ~/pkglist2.txt
end
paru -Qeq >~/pkglist1.txt
if test $status -ne 0
    set failed 1
end
echo

# 6️⃣ update all packages (official + AUR + devel)
echo $green"Updating all packages..."$normal
echo
paru -Syu --devel --needed --noconfirm
if test $status -ne 0
    set failed 1
end
echo

# header
echo $yellow"==== Maintenance Complete ===="$normal
echo

# check for errors
if test $failed -eq 1
    echo $red"One or more commands produced errors."$normal
    if test $shutdown -eq 1
        read -P $yellow"Shutdown anyway? [Y/n] "$normal choice
        if test $choice != y -a $choice != Y
            exit
        end
    end
    echo
end

# shutdown if requested
if test $shutdown -eq 1
    echo $green"Syncing filesystem..."$normal
    sync
    echo
    echo $green"Shutting down..."$normal
    systemctl poweroff -i
end
