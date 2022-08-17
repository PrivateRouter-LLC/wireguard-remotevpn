#!/usr/bin/env bash
# Private Router (PrivateRouter.com) Reverse VPN Installer Script
# Coded by Jason Hawks <jason@fixedbit.com>

# Use these command to completely remove everything installed from this script
# docker container stop npm wg-easy pihole;docker container rm npm wg-easy pihole;docker network rm privaterouter;rm -rf /root/.wg-easy/ /root/.pihole/ /root/.nginxproxymanager/
# systemctl disable frpc;rm -rf /etc/systemd/system/frpc.service;rm -rf /etc/frp

# Exit on error
set -e

# Our pretty banner
banner() {
    echo "  "
    echo " ▄▄▄·▄▄▄  ▪   ▌ ▐· ▄▄▄·▄▄▄▄▄▄▄▄ . "
    echo "▐█ ▄█▀▄ █·██ ▪█·█▌▐█ ▀█•██  ▀▄.▀· "
    echo " ██▀·▐▀▀▄ ▐█·▐█▐█•▄█▀▀█ ▐█.▪▐▀▀▪▄ "
    echo "▐█▪·•▐█•█▌▐█▌ ███ ▐█ ▪▐▌▐█▌·▐█▄▄▌ "
    echo ".▀   .▀  ▀▀▀▀. ▀   ▀  ▀ ▀▀▀  ▀▀▀  "
    echo "▄▄▄        ▄• ▄▌▄▄▄▄▄▄▄▄ .▄▄▄     "
    echo "▀▄ █·▪     █▪██▌•██  ▀▄.▀·▀▄ █·   "
    echo "▐▀▀▄  ▄█▀▄ █▌▐█▌ ▐█.▪▐▀▀▪▄▐▀▀▄    "
    echo "▐█•█▌▐█▌.▐▌▐█▄█▌ ▐█▌·▐█▄▄▌▐█•█▌   "
    echo ".▀  ▀ ▀█▄▀▪ ▀▀▀  ▀▀▀  ▀▀▀ .▀  ▀   "
    echo "▄▄▄  ▄▄▄ .• ▌ ▄ ·.      ▄▄▄▄▄▄▄▄ ."
    echo "▀▄ █·▀▄.▀··██ ▐███▪▪    •██  ▀▄.▀·"
    echo "▐▀▀▄ ▐▀▀▪▄▐█ ▌▐▌▐█· ▄█▀▄ ▐█.▪▐▀▀▪▄"
    echo "▐█•█▌▐█▄▄▌██ ██▌▐█▌▐█▌.▐▌▐█▌·▐█▄▄▌"
    echo ".▀  ▀ ▀▀▀ ▀▀  █▪▀▀▀ ▀█▄▀▪▀▀▀  ▀▀▀ "
    echo " ▌ ▐· ▄▄▄· ▐ ▄                    "
    echo "▪█·█▌▐█ ▄█•█▌▐█                   "
    echo "▐█▐█• ██▀·▐█▐▐▌                   "
    echo " ███ ▐█▪·•██▐█▌                   "
    echo ". ▀  .▀   ▀▀ █▪                    "
    echo "  "        
}

#  Read our script name
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

# Helper Sub
show_help()
{    
    echo "== ${SCRIPT_NAME} Flags (* Indicates Required) =="
    echo "* [-s 123.456.789.012]* sets the FRP Server Address"
    echo "* [-t abcd12345]* sets the FRP Server Token"
    echo "* [-d yourdomain.com ] sets the Domain Name for Reverse Proxy"
    echo "* Example: ${SCRIPT_NAME} -s 123.456.789.012 -t abcd12345 -d privaterouter.com"
}

# Install Packages
install_packages() {
    # if we received packages to install, install them
    [ $# -eq 0 ] && echo "* No packages requested to install" || {
        # Local variable to hold our packages
        local packages
        # Loop through our passed packages
        while [ $# -gt 0 ]; do
            # Check if the command exists, if not flag it for installation
            [ -x "$(command -v "${1}")" ] && echo "* ${1} is already installed" || { echo "* ${1} will be installed"; packages="${packages} ${1}"; }
            # Shift to the next package
            shift
        done
        # Check if we have any packages to install
        [ -z "${packages}" ] && { echo "* All requested packages are already installed"; return 0; } || { echo "* Installing ${packages:1}"; apt update; apt install -y ${packages}; }
    }
}

frpc_install() {
    # Check if FRPC is already running
    [ "$(systemctl show -p ActiveState frpc | sed 's/ActiveState=//g')" != "active" ] && {
        echo "* Installing FRPC"
        # call out to our external script to install FRPC for us
        curl https://raw.githubusercontent.com/PrivateRouter-LLC/frpc-install-script/main/frpc-install-script.sh | bash -s -- -s ${FRP_SERVER} -t ${FRP_TOKEN}
    } || { echo "* FRPC is already running thus we cannot proceed"; exit 1; }
}

docker_install() {
    # Check if docker is installed, if not install it
    [ -x "$(command -v docker)" ] && echo "* Docker is already installed" || {
        echo "* Installing Docker"
        # Pull docker install script and run it
        curl -fsSL https://get.docker.com | sh > /dev/null
    }
}

create_docker_network() {
    # Check if the docker network privaterouter exists
    [ ! "$(docker network ls | grep privaterouter)" ] && {
        echo "* Creating Docker Network privaterouter"
        # Create our docker network for our containers to connect to
        docker network create \
            --driver=bridge \
            --subnet=172.28.0.0/16 \
            --ip-range=172.28.5.0/24 \
            --gateway=172.28.5.254 \
            privaterouter
    } || { echo "* Docker network privaterouter already exists thus we cannot proceed"; exit 1; }
}

wireguard_frpc() {
    # Check if WireGuard entry is already in the config file
    [[ $(grep "wireguard" "/etc/frp/frpc.ini") == "" ]] && {
        echo "* Adding WireGuard Port To /etc/frp/frpc.ini"
        # Open port for WireGuard connections
        cat >> /etc/frp/frpc.ini <<-EOF
[wireguard]
type = udp
local_ip = 127.0.0.1
local_port = 51820
remote_port = 51820
EOF

        # Restart FRPC Service
        systemctl restart frpc
    } || { echo "* WireGuard Port exists in /etc/frp/frpc.ini"; }
}

fix_dns() {
    # Check if our resolved is holding onto port 53
    [[ $(grep "#DNSStubListener=yes" "/etc/systemd/resolved.conf") != "" ]] && {
        sed -i 's/#DNSStubListener=yes/DNSStubListener=no/g;s/#DNS=/DNS=1.1.1.1/g' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
        echo "* Service resolved no longer binds on port 53"
    } || { echo "* Service resolved does not need to be fixed"; }
}

pihole_install() {
    # Check if PiHole is already running
    [ ! "$(docker ps -a | grep pihole)" ] && {
        echo "* Installing PiHole"

        # Generate PiHole Password
        PIHOLE_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')

        # Start the PiHole container
        docker run -d \
            --name=pihole \
            -e TZ=America/New_York \
            -e WEBPASSWORD=${PIHOLE_PASS} \
            -e FTLCONF_REPLY_ADDR4=172.28.5.253 \
            -v /root/.pihole/etc:/etc/pihole \
            -v /root/.pihole/dnsmasq.d:/etc/dnsmasq.d \
            --restart=unless-stopped \
            --network privaterouter \
            --ip=172.28.5.253 \
            pihole/pihole

        echo "The pihole admin pass is ${PIHOLE_PASS}"
        echo "${PIHOLE_PASS}" > ~/pihole-pass
    } || { echo "* PiHole is already running thus we cannot proceed"; exit 1; }
}

wgeasy_install() {
    # Check if wg-easy is already running
    [ ! "$(docker ps -a | grep wg-easy)" ] && {
        echo "* Installing wg-easy"

        # Generate wg-easy Password
        WGEASY_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')

        # Start the wg-easy container
        docker run -d \
            --name=wg-easy \
            -e WG_HOST=${REVERSE_DOMAIN} \
            -e PASSWORD=${WGEASY_PASS} \
            -e WG_DEFAULT_DNS=172.28.5.253 \
            -v /root/.wg-easy:/etc/wireguard \
            -p 51821:51821/tcp \
            -p 51820:51820/udp \
            --cap-add=NET_ADMIN \
            --cap-add=SYS_MODULE \
            --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
            --sysctl="net.ipv4.ip_forward=1" \
            --restart unless-stopped \
            --network privaterouter \
            weejewel/wg-easy

        echo "The wg-easy admin pass is ${WGEASY_PASS}"
        echo "${WGEASY_PASS}" > ~/wgeasy-pass
    } || { echo "* wg-easy is already running thus we cannot proceed"; exit 1; }
}

npm_install() {
    # NPM WILL NOT BE INSTALLED, PLS CONFIGURE WITH NGINX
    
    
}

# ------------------------------------------------- WE RUN FROM HERE -------------------------------------------------

banner

# Require root
[ "$EUID" -ne 0 ] && { echo "Please run as root"; exit 1; }

# Check if we have passed any arguments
[ $# -eq 0 ] && show_help && exit 1

# Iterate over arguments and process them
while (( "${#}" )); do
    case "${1}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--server)
            [[ ${2} != -* && ! -z ${2} ]] && { FRP_SERVER="${2}"; echo "Using FRP Server: ${2}"; } || { ERRORS+=("Invalid FRP Server passed to -s"); }
            shift
            ;;
        -t|--token)
            [[ ${2} != -* && ! -z ${2} ]] && { FRP_TOKEN="${2}"; echo "Using FRP Token: ${2}"; } || { ERRORS+=("Invalid FRP Token passed to -t"); }
            shift
            ;;
        -d|--domain)
            [[ ${2} != -* && ! -z ${2} ]] && { REVERSE_DOMAIN="${2}"; echo "Using Reverse Domain: ${2}"; } || { ERRORS+=("Invalid Reverse Domain passed to -d"); }
            shift
            ;;
        *)
            ERRORS+=("${1} is not a valid argument for ${SCRIPT_NAME}")
            ;;
    esac
    shift
done

# Check if our required arguments are set
[ -z "${FRP_SERVER}" ] && { ERRORS+=("FRP Server is required"); }
[ -z "${FRP_TOKEN}" ] && { ERRORS+=("FRP Token is required"); }
[ -z "${REVERSE_DOMAIN}" ] && { ERRORS+=("Reverse Domain is required"); }

# Print out our errors if we have any
if [ ! -z "${ERRORS}" ]; then
    printf "\n== The following Errors Were Found ==\n"
    for error in "${ERRORS[@]}"; do
        printf "\n= ${error}\n"
    done
    exit 1
fi

# Make sure our needed packages are installed
install_packages "curl"

frpc_install

wireguard_frpc

docker_install

create_docker_network

fix_dns

pihole_install

wgeasy_install


echo "** The install and setup completed successfully **"

# Print out our passwords
echo "** The pihole admin pass is $(cat ~/pihole-pass)"
echo "** The wg-easy admin pass is $(cat ~/wgeasy-pass)"
echo "** NOTE: You may need to reboot for name resolution between the VMs to work (such as using NPM) **"
