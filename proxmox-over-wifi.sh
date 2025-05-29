#!/usr/bin/env bash

# -----------------------------------------------------------------------------

PROXMOX_ISSUE_PATH=/etc/issue
PROXMOX_ISSUE_STRING="Proxmox Virtual Environment"
REPO_URL="http://ftp.pl.debian.org/debian"
REPO_FILE_lslR="ls-lR.gz"

# -----------------------------------------------------------------------------

declare -A t

t["en_on_proxmox"]="Proxmox detected"
t["en_on_others"]="Other system than Proxmox detected"
t["en_yes"]="yes y YES Y"
t["en_no"]="no n NO N"
t["en_invalid"]="Please enter 'yes' or 'no'."
t["en_delete_downloaded_files"]="Delete downloaded files?"
t["en_install_downloaded_files"]="Install downloaded files?"
t["en_file_found"]="File found"
t["en_file_not_found_downloading"]="File not found, downloading..."
t["en_matched"]="Matched file"
t["en_provide"]="Provide"
t["en_update_etc_network_interfaces"]="Update /etc/network/interfaces ?"
t["en_update_etc_wpa_supplicant"]="Update /etc/wpa_supplicant/wpa_supplicant.conf ?"
t["en_configure_vms_and_lxcs"]="Configure DHCP for VMs and LXCs?"
t["en_configure_static_ip"]="Configure static IP?"

t["pl_on_proxmox"]="Wykryto Proxmox"
t["pl_on_others"]="Wykryto inny system niż Proxmox"
t["pl_yes"]="tak t TAK T"
t["pl_no"]="nie n NIE N"
t["pl_invalid"]="Proszę wpisać 'tak' lub 'nie'."
t["pl_delete_downloaded_files"]="Skasować pobrane?"
t["pl_install_downloaded_files"]="Zainstalować pobrane?"
t["pl_file_found"]="Plik znaleziony"
t["pl_file_not_found_downloading"]="Plik nie został znaleziony, pobieranie..."
t["pl_matched"]="Dopasowano plik"
t["pl_provide"]="Podaj"
t["pl_update_etc_network_interfaces"]="Zaktualizować /etc/network/interfaces ?"
t["pl_update_etc_wpa_supplicant"]="Zaktualizować /etc/wpa_supplicant/wpa_supplicant.conf ?"
t["pl_configure_vms_and_lxcs"]="Skonfigurować DHCP dla VM i LXC?"
t["pl_configure_static_ip"]="Skonfigurować statyczny IP?"

# -----------------------------------------------------------------------------

function color() {
    case "$1" in
    red) echo -ne "\e[31m" ;;
    green) echo -ne "\e[32m" ;;
    yellow) echo -ne "\e[33m" ;;
    blue) echo -ne "\e[34m" ;;
    magenta) echo -ne "\e[35m" ;;
    cyan) echo -ne "\e[36m" ;;
    normal) echo -ne "\e[0m" ;;
    *) ;;
    esac
}

function ask_yes_no() {
    local question="$1"
    local answer
    local yes_options="${t[${L}_yes]}"
    local no_options="${t[${L}_no]}"
    while true; do
        read -p "$question ( ${t["${L}_yes"]} / ${t["${L}_no"]} ): " answer
        if [[ " $yes_options " =~ " $answer " ]]; then
            return 0
        elif [[ " $no_options " =~ " $answer " ]]; then
            return 1
        else
            echo "${t[${L}_invalid]}"
        fi
    done
}

function ask_options_default() {
    local question="$1"
    local answer
    local options="$2"
    local default="$3"
    while true; do
        read -p "$question [$default]: " answer
        if [[ " $options " =~ " $answer " ]]; then
            echo "$answer"
            return 0
        elif [[ "" == "$answer" ]]; then
            echo "$default"
            return 1
        fi
    done
}

function ask_input_default() {
    local question="$1"
    local answer
    local default="$2"
    while true; do
        read -p "$question [$default]: " answer
        if [[ "" == "$answer" ]]; then
            echo "$default"
            return 1
        else
            echo "$answer"
            return 0
        fi
    done
}

function ask_input() {
    local question="$1"
    local answer
    while true; do
        read -p "$question: " answer
        if [[ "" != "$answer" ]]; then
            echo "$answer"
            return 0
        fi
    done
}

function file_exists() {
    [ -f "$1" ]
    return $?
}

function file_contains_string() {
    local file="$1"
    local string="$2"
    grep -q "$string" "$file"
    return $?
}

function get_arch() {
    local arch="$(uname -m)"
    case "$arch" in
    x86_64) echo "amd64" ;;
    i686 | i386) echo "i386" ;;
    aarch64) echo "arm64" ;;
    armv7l | armv7hf) echo "armhf" ;;
    armv6l | armel) echo "armel" ;;
    *) echo "$arch" ;;
    esac
}

function download_file() {
    local filename="$1"
    local url="$2"
    file_exists $filename
    if [ $? -eq 1 ]; then
        color yellow
        echo "${t[${L}_file_not_found_downloading]}"
        color normal
        wget $url
    else
        color green
        echo "${t[${L}_file_found]}"
        color normal
    fi
}

# -----------------------------------------------------------------------------

function main() {
    L=$(echo "$LANG" | cut -d'_' -f1)
    L=$(ask_options_default "Choose language/Wybierz język ( en / pl )" "en pl" en)

    file_contains_string $PROXMOX_ISSUE_PATH $PROXMOX_ISSUE_STRING
    if [ $? -eq 0 ]; then
        on_proxmox
    else
        on_others
    fi
}

function on_proxmox() {
    color cyan
    echo "${t[${L}_on_proxmox]}"

    color magenta
    ask_yes_no "${t[${L}_install_downloaded_files]}"
    if [ $? -eq 0 ]; then
        dpkg -i *.deb
    fi

    ask_yes_no "${t[${L}_delete_downloaded_files]}"
    if [ $? -eq 0 ]; then
        rm ls-lR
    fi

    ask_yes_no "${t[${L}_update_etc_network_interfaces]}"
    if [ $? -eq 0 ]; then
        ip=$(ask_input_default "${t[${L}_provide]} CIDR" "10.0.0.2/24")
        local wifi_interface=$(ip link show | awk -F': ' '/^[0-9]+: w/{print $2}')
        on_proxmox_configure_interfaces "$wifi_interface" "$ip"
        cp interfaces /etc/network/
    fi

    ask_yes_no "${t[${L}_update_etc_wpa_supplicant]}"
    if [ $? -eq 0 ]; then
        on_proxmox_configure_wpa_supplicant
        cp wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
    fi

    ask_yes_no "${t[${L}_configure_vms_and_lxcs]}"
    if [ $? -eq 0 ]; then
        on_proxmox_configure_vms_and_lxcs
        cp dnsmasq.conf /etc/dnsmasq.conf
    fi

    ask_yes_no "${t[${L}_configure_static_ip]}"
    if [ $? -eq 0 ]; then
        local wifi_interface=$(ip link show | awk -F': ' '/^[0-9]+: w/{print $2}')
        local mac=$(ip link show $wifi_interface | awk '/ether/ {print $2}')
        local static_ip=$(ask_input_default "${t[${L}_provide]} IP" "10.0.0.2")
        on_proxmox_configure_static_ip "$mac" "$static_ip" "$HOSTNAME"
        cp static-ips.conf /etc/dnsmasq.d/static-ips.conf
    fi
}

function on_proxmox_configure_interfaces() {
    local wifi_interface="$1"
    local ip="$2"
    content="auto lo
iface lo inet loopback

auto $wifi_interface
iface $wifi_interface inet dhcp
        wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

auto vmbr1
iface vmbr1 inet static
        address $ip
        bridge-ports none
        bridge-stp off
        bridge-fd 0

        post-up echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up   iptables -t nat -A POSTROUTING -s '$ip' -o $wifi_interface -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '$ip' -o $wifi_interface -j MASQUERADE
        post-up   iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
        post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
"
    echo -e "$content" >interfaces
}

on_proxmox_configure_wpa_supplicant() {
    local ssid="$1"
    local pass="$2"
    content_head="ctrl_interface=/run/wpa_supplicant
update_config=1

network={"
    local ssid=$(ask_input "${t[${L}_provide]} SSID")
    local pass=$(ask_input "${t[${L}_provide]} PASS")
    content_network=$(wpa_passphrase $ssid $pass | head -n 4 | tail -n 3)
    content_tail="	proto=WPA RSN
	key_mgmt=WPA-PSK
}
"
    echo -e "$content_head" >wpa_supplicant.conf
    echo -e "$content_network" >>wpa_supplicant.conf
    echo -e "$content_tail" >>wpa_supplicant.conf
}

function on_proxmox_configure_vms_and_lxcs() {
    apt install dnsmasq
    local ip1=$(ask_input_default "${t[${L}_provide]} IP..." "10.0.0.100")
    local ip2=$(ask_input_default "${t[${L}_provide]} ...IP" "10.0.0.200")
    local mask=$(ask_input_default "${t[${L}_provide]} ...IP" "255.255.255.0")
    local time=$(ask_input_default "${t[${L}_provide]} h" "12h")
    content="# Add the proxmox as a domain
#address=/proxmox/put_ip_here

interface=vmbr1
dhcp-range=$ip1,$ip2,$mask,$time
dhcp-option=3,$ip"
    echo -e "$content" >dnsmasq.conf
}

function on_proxmox_configure_static_ip() {
    local mac="$1"
    local static_ip="$2"
    local hostname="$3"
    content="dhcp-host=$mac,$static_ip,$hostname"
    echo -e "$content" >static-ips.conf
}

function on_others() {
    color blue
    echo "${t[${L}_on_others]}"
    color magenta
    echo "${t[${L}_matched]}:" "ls-lR"
    download_file "ls-lR" "$REPO_URL/$REPO_FILE_lslR"
    gzip -dk "$REPO_FILE_lslR"

    color magenta
    filename_wpasupplicant=$(awk '{print $9}' ls-lR | grep -o "wpasupplicant.*_$(get_arch).deb" | sort -n | head -n 1)
    echo "${t[${L}_matched]}:" $filename_wpasupplicant
    color normal
    download_file $filename_wpasupplicant $REPO_URL/pool/main/w/wpa/$filename_wpasupplicant

    color magenta
    filename_libpcsclite1=$(grep "libpcsclite1_1.*$(get_arch).deb" ls-lR | awk '{print $9}' | sort -rn | head -n 1)
    echo "${t[${L}_matched]}:" $filename_libpcsclite1
    color normal
    download_file $filename_libpcsclite1 $REPO_URL/pool/main/p/pcsc-lite/$filename_libpcsclite1

    color magenta
    filename_libnl=$(grep "libnl-genl-3-200.*b1_$(get_arch).deb" ls-lR | awk '{print $9}' | sort -rn | head -n 1)
    echo "${t[${L}_matched]}:" $filename_libnl
    color normal
    download_file $filename_libnl $REPO_URL/pool/main/libn/libnl3/$filename_libnl
}

# -----------------------------------------------------------------------------

main
