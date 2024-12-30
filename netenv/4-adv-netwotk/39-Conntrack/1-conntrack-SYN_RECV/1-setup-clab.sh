#!/bin/bash
set -v
cat <<EOF>clab.yaml | clab deploy -t clab.yaml -
name: tcp-conntrack
mgmt:
  ipv6-subnet: ""
  ipv4-subnet: 172.20.20.0/24

topology:
  nodes:
    gw1:
      kind: linux
      image: 192.168.2.100:5000/xcni
      exec:
      - ip a a 10.1.5.1/24 dev eth1
      - ip a a 10.1.8.1/24 dev eth2
      - iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -o eth0 -j MASQUERADE

    server1:
      kind: linux
      image: 192.168.2.100:5000/xcni
      exec:
      - ip addr add 10.1.5.10/24 dev net0
      - ip r r default via 10.1.5.1 dev net0
      - iptables -A OUTPUT -s 10.1.5.10 -d 10.1.8.10 -p tcp --tcp-flags ACK ACK -j DROP

    server2:
      kind: linux
      image: 192.168.2.100:5000/xcni
      exec:
      - ip addr add 10.1.8.10/24 dev net0
      - ip r r default via 10.1.8.1 dev net0
      - conntrack -L

  links:
    - endpoints: ["gw1:eth1", "server1:net0"]
    - endpoints: ["gw1:eth2", "server2:net0"]

EOF

#[root@server1 ~]# conntrack -E
#    [NEW] tcp      6 120 SYN_SENT src=10.1.5.10 dst=10.1.8.10 sport=51546 dport=80 [UNREPLIED] src=10.1.8.10 dst=10.1.5.10 sport=80 dport=51546
# [UPDATE] tcp      6 60 SYN_RECV src=10.1.5.10 dst=10.1.8.10 sport=51546 dport=80 src=10.1.8.10 dst=10.1.5.10 sport=80 dport=51546
# [UPDATE] tcp      6 299 ESTABLISHED src=10.1.5.10 dst=10.1.8.10 sport=51546 dport=80 src=10.1.8.10 dst=10.1.5.10 sport=80 dport=51546 [ASSURED]
#^Cconntrack v1.4.4 (conntrack-tools): 3 flow events have been shown.


