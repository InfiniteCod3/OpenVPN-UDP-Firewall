#!/bin/bash

# Prompt Home Connection
read -p "Enter your Home connection for SSH Whitelist: " ip

# Flush iptables
iptables -t mangle -P PREROUTING ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t mangle -F
iptables -t mangle -X
iptables -F
iptables -X
iptables -t raw -F
iptables -t raw -X
iptables -t nat -X
iptables -t nat -X

# Whitelist ssh 
iptables -A INPUT -s "$ip" -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 22 -j DROP

# accept required interfaces
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Drop unneeded protocols
iptables -A INPUT -p gre -j DROP
iptables -A INPUT -p 50 -j DROP
iptables -A INPUT -p 51 -j DROP

# Accept ICMP ping traffic
iptables -A INPUT -p icmp --icmp-type echo-request -m hashlimit --hashlimit-upto 1/second --hashlimit-burst 1 --hashlimit-mode srcip --hashlimit-name accept-ping -j ACCEPT

# Drop invalid packets
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# Implement a conlimit of 2
iptables -A INPUT -p udp --dport 1194 -m connlimit --connlimit-above 2 -j DROP

# Accept OpenVPN matching traffic (control hard reset)
iptables -A INPUT -p udp --dport 1194 --match bpf --bytecode "16,48 0 0 0,84 0 0 240,21 0 12 64,48 0 0 9,21 0 10 17,40 0 0 6,69 8 0 8191,177 0 0 0,80 0 0 8,21 0 5 56,64 0 0 17,21 0 3 1,72 0 0 4,21 0 1 62,6 0 0 65535,6 0 0 0" -m conntrack --ctstate NEW -m hashlimit --hashlimit-upto 1/second --hashlimit-burst 1 --hashlimit-mode srcip --hashlimit-name accept-openvpn -j ACCEPT

# Accept related and established traffic
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Set policy to drop
iptables -P INPUT DROP

# Apply kernel settings
echo "net.netfilter.nf_conntrack_max = 1000000000" >> /etc/sysctl.conf
echo "net.netfilter.nf_conntrack_buckets = 100000000" >> /etc/sysctl.conf
echo "net.netfilter.nf_conntrack_expect_max = 100000000" >> /etc/sysctl.conf
echo "net.netfilter.nf_conntrack_udp_timeout = 15" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

# Print success message
echo "Nate's OpenVPN UDP Firewall Deployed!"