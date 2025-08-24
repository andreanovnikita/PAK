#!/bin/bash

###############################################################
#PLEASE ADD NETWORK WITHOUT octet!
#for example (Network 1.1.1.0/24, add: 1.1.1)
#ONLY 24 SUBNET!
network=10.11.11
###############################################################



# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -q "dash"; then
	echo 'This script needs to be run with "bash", not "sh".'
	exit
fi

# Discard stdin. Needed when running from a one-liner which includes a newline
read -N 999999 -t 0.001

if [[ "$EUID" -ne 0 ]]; then
	echo "This script needs to be run with superuser privileges."
	exit
fi

# Store the absolute path of the directory where the script is located
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

new_client_dns () {
	exit
	echo "Select a DNS server for the client:"
	echo "   1) Default system resolvers"
	echo "   2) Google"
	echo "   3) 1.1.1.1"
	echo "   4) OpenDNS"
	echo "   5) Quad9"
	echo "   6) AdGuard"
	echo "   7) Specify custom resolvers"
	read -p "DNS server [1]: " dns
	until [[ -z "$dns" || "$dns" =~ ^[1-7]$ ]]; do
		echo "$dns: invalid selection."
		read -p "DNS server [1]: " dns
	done
	case "$dns" in
		1|"")
			# Locate the proper resolv.conf
			# Needed for systems running systemd-resolved
			if grep '^nameserver' "/etc/resolv.conf" | grep -qv '127.0.0.53' ; then
				resolv_conf="/etc/resolv.conf"
			else
				resolv_conf="/run/systemd/resolve/resolv.conf"
			fi
			# Extract nameservers and provide them in the required format
			dns=$(grep -v '^#\|^;' "$resolv_conf" | grep '^nameserver' | grep -v '127.0.0.53' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | xargs | sed -e 's/ /, /g')
		;;
		2)
			dns="8.8.8.8, 8.8.4.4"
		;;
		3)
			dns="1.1.1.1, 1.0.0.1"
		;;
		4)
			dns="208.67.222.222, 208.67.220.220"
		;;
		5)
			dns="9.9.9.9, 149.112.112.112"
		;;
		6)
			dns="94.140.14.14, 94.140.15.15"
		;;
		7)
			echo
			until [[ -n "$custom_dns" ]]; do
				echo "Enter DNS servers (one or more IPv4 addresses, separated by commas or spaces):"
				read -p "DNS servers: " dns_input
				# Convert comma delimited to space delimited
				dns_input=$(echo "$dns_input" | tr ',' ' ')
				# Validate and build custom DNS IP list
				for dns_ip in $dns_input; do
					if [[ "$dns_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
						if [[ -z "$custom_dns" ]]; then
							custom_dns="$dns_ip"
						else
							custom_dns="$custom_dns, $dns_ip"
						fi
					fi
				done
				if [ -z "$custom_dns" ]; then
					echo "Invalid input."
				else
					dns="$custom_dns"
				fi
			done
		;;
	esac
}

new_client_setup () {
	# Given a list of the assigned internal IPv4 addresses, obtain the lowest still
	# available octet. Important to start looking at 2, because 1 is our gateway.
	octet=2
	while grep AllowedIPs /etc/wireguard/wg0.conf | cut -d "." -f 4 | cut -d "/" -f 1 | grep -q "^$octet$"; do
		(( octet++ ))
	done
	# Don't break the WireGuard configuration in case the address space is full
	if [[ "$octet" -eq 255 ]]; then
		echo "253 clients are already configured. The WireGuard internal subnet is full!"
		exit
	fi
	key=$(wg genkey)
	psk=$(wg genpsk)
	# Configure client in the server
	cat << EOF >> /etc/wireguard/wg0.conf
# BEGIN_PEER $client
[Peer]
PublicKey = $(wg pubkey <<< $key)
PresharedKey = $psk
AllowedIPs = $network.$octet/32$(grep -q 'fddd:2c4:2c4:2c4::1' /etc/wireguard/wg0.conf && echo ", fddd:2c4:2c4:2c4::$octet/128")
# END_PEER $client
EOF
	# Create client configuration
	cat << EOF > "$script_dir"/"$client".conf
[Interface]
Address = $network.$octet/24$(grep -q 'fddd:2c4:2c4:2c4::1' /etc/wireguard/wg0.conf && echo ", fddd:2c4:2c4:2c4::$octet/64")
DNS = $dns
PrivateKey = $key

[Peer]
PublicKey = $(grep PrivateKey /etc/wireguard/wg0.conf | cut -d " " -f 3 | wg pubkey)
PresharedKey = $psk
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $(grep '^# ENDPOINT' /etc/wireguard/wg0.conf | cut -d " " -f 3):$(grep ListenPort /etc/wireguard/wg0.conf | cut -d " " -f 3)
PersistentKeepalive = 25
EOF
}

view_clients () {
                        number_of_clients=$(grep -c '^# BEGIN_PEER' /etc/wireguard/wg0.conf)
                        if [[ "$number_of_clients" = 0 ]]; then
                                echo
                                echo "There are no existing clients!"
                                exit
                        fi
                        echo
			echo "List of clients:"
                        grep '^# BEGIN_PEER' /etc/wireguard/wg0.conf | cut -d ' ' -f 3 | nl -s ') '
}
select_client () {
                        echo "Please select the client"
                        read -p "Client: " client_number
                        until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do
                                echo "$client_number: invalid selection."
                                read -p "Client: " client_number
                        done
                        client=$(grep '^# BEGIN_PEER' /etc/wireguard/wg0.conf | cut -d ' ' -f 3 | sed -n "$client_number"p)

}

full_view_clients () {

get_client_ip() {
    local conf="$1"
    grep -A 5 "\[Interface\]" "$conf" | awk -F'[ /]' '/Address/ {print $3; exit}'
}

is_blocked() {
    local ip="$1"
    sudo ipset list blacklist-wg 2>/dev/null | grep -q -w "$ip"
}

echo "List of clients:"
for client_conf in "$script_dir"/*.conf; do
    client=$(basename "$client_conf" .conf)
    ip=$(get_client_ip "$client_conf")

    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        if is_blocked "$ip"; then
            echo -e "\e[31m- $client ($ip - blocked)\e[0m"

        else
            echo -e "\e[32m+ $client ($ip - active)\e[0m"
        fi
    else
        echo -e "\e[33m? $client (IP: ${ip:- Not found! Error... })\e[0m"
    fi
done


}
protect_all_configs () {
	chattr +aui $script_dir/*.conf
}


print_dev_info() {
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
  clear
  echo -e "${GREEN}===============================================${NC}"
  echo -e "${CYAN}               About This Program               ${NC}"
  echo -e "${GREEN}===============================================${NC}"
  echo -e ""
  echo -e "This script is designed for convenient and secure"
  echo -e "management of WireGuard connections."
  echo -e ""
  echo -e "${BLUE}Developer:${NC} Andreyanov Nikita"
  echo -e "${BLUE}Telegram:${NC} t.me/aes_192 (for error reports)"
  echo -e "${BLUE}License:${NC} GPL-3"
  echo -e ""
  echo -e "${GREEN}===============================================${NC}"
}
if [[ ! -e /etc/wireguard/wg0.conf ]]; then
	echo "Wireguard not installed!"
	exit
	fi
	clear
	protect_all_configs
	echo
	echo "Select an option:"
	echo "   1) Add a new client"
	echo "   2) Remove an existing client"
	echo "   3) View a list of clients"
	echo "   4) View QR code for client"
	echo "   5) Resolve client to IP"
	echo "   6) Resolve IP to client"
	echo "   7) Block client"
	echo "   8) Unblock client"
	echo ""
	echo "   999) About program"
	echo "   0) Exit"
	read -p "Option: " option
	until [[ "$option" =~ ^([0-8]|999)$ ]]; do
		echo "$option: invalid selection."
		read -p "Option: " option
	done


	case "$option" in
		1)
			echo
			echo "Provide a name for the client:"
			read -p "Name: " unsanitized_client
			# Allow a limited lenght and set of characters to avoid conflicts
			client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client" | cut -c-15)
			while [[ -z "$client" ]] || grep -q "^# BEGIN_PEER $client$" /etc/wireguard/wg0.conf; do
				echo "$client: invalid name."
				read -p "Name: " unsanitized_client
				client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client" | cut -c-15)
			done
			echo

			#auto set DNS
			#new_client_dns
		        dns="1.1.1.1, 1.0.0.1"

			new_client_setup
			# Append new client configuration to the WireGuard interface
			wg addconf wg0 <(sed -n "/^# BEGIN_PEER $client/,/^# END_PEER $client/p" /etc/wireguard/wg0.conf)
			echo
			qrencode -t ANSI256UTF8 < "$script_dir"/"$client.conf"
			echo -e '\xE2\x86\x91 That is a QR code containing your client configuration.'
			echo
                        echo ""
                        echo ""
                        cat $script_dir/$client.conf
                        protect_all_configs
			exit
		;;
		2)
			view_clients
			select_client
			echo
			read -p "Confirm $client removal? [y/N]: " remove
			until [[ "$remove" =~ ^[yYnN]*$ ]]; do
				echo "$remove: invalid selection."
				read -p "Confirm $client removal? [y/N]: " remove
			done
			if [[ "$remove" =~ ^[yY]$ ]]; then
				# The following is the right way to avoid disrupting other active connections:
				# Remove from the live interface
				wg set wg0 peer "$(sed -n "/^# BEGIN_PEER $client$/,\$p" /etc/wireguard/wg0.conf | grep -m 1 PublicKey | cut -d " " -f 3)" remove
				# Remove from the configuration file
				sed -i "/^# BEGIN_PEER $client$/,/^# END_PEER $client$/d" /etc/wireguard/wg0.conf
				chattr -aui "$script_dir"/"$client.conf"
                                rm "$script_dir"/"$client.conf"
  				echo
				echo "$client removed!"
			else
				echo
				echo "$client removal aborted!"
			fi
			exit
		;;
		3)
			full_view_clients
			exit
		;;
		4)
			view_clients
			select_client
                        echo
                        read -p "Confirm $client show config? [y/N]: " view
                        until [[ "$view" =~ ^[yYnN]*$ ]]; do
                                echo "$view: invalid selection."
                                read -p "Confirm $client show config? [y/N]: " view
			done
			echo
                        qrencode -t ANSI256UTF8 < "$script_dir"/"$client.conf"
                        echo -e '\xE2\x86\x91 That is a QR code containing your client configuration.'
                        echo
                        echo ""
                        echo ""
                        cat $script_dir/$client.conf
                        protect_all_configs
			exit
		;;
		5)
			view_clients
			select_client
                        echo
			echo "$client <->" $(grep "$network.*" $script_dir/$client.conf | sed 's|/.*||; s|.*= ||')
			exit

		;;
		6)
			echo
			read -p "IP: " find_ip
			client=$(grep -l "Address = $find_ip" *.conf | sed 's/.conf//')
			if [ -z "$client" ]; then
				echo "IP not assigned to client!"
			else
 				echo "$find_ip <-> $client"
			fi
			exit
		;;
		7)
			view_clients
			select_client
                        echo
			ip_client=$(grep "$network.*" $script_dir/$client.conf | sed 's|/.*||; s|.*= ||')
                        echo "$client <-> $ip_client"
			ipset add blacklist-wg $ip_client
			echo "Client $client (ip.addr $ip_client) has been blocked!"
            ipset save > /etc/ipsets
			exit
		;;
		8)
			view_clients
			select_client
                        echo
                        ip_client=$(grep "$network.*" $script_dir/$client.conf | sed 's|/.*||; s|.*= ||')
                        echo "$client <-> $ip_client"
                        ipset del blacklist-wg $ip_client
                        echo "Client $client (ip.addr $ip_client) has been unblocked!"
                        ipset save > /etc/ipsets
						exit

		;;
		999)
			print_dev_info
			exit
		;;
		0)
			exit
		;;
	esac
fi
