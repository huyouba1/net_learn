#!/bin/bash
set -v

# topo:     
#                              |-----------------------|---LVS-DR[10.1.8.253/24](net1),10.1.8.254/24(VIP[lo])]
#                              |-----------------------|---RS1[10.1.8.10/24](net1),[10.1.8.254/24](VIP[lo](arp_announce and arp_ignore]))
# client---eth1(10.1.5.1/24)-Router-eth2(10.1.8.1/24)--|---RS2[10.1.8.11/24](net1),[10.1.8.254/24](VIP[lo](arp_announce and arp_ignore]))
#                              |-----------------------|---RS3[10.1.8.12/24](net1),[10.1.8.254/24](VIP[lo](arp_announce and arp_ignore]))

{ ip l s brl4lb down && brctl delbr brl4lb; } > /dev/null 2>&1
brctl addbr brl4lb;ip l s brl4lb up

cat <<EOF>clab.yaml | clab deploy -t clab.yaml -
name: lvs-dr-ospf-keepalived
mgmt:
  ipv6-subnet: ""
  ipv4-subnet: 172.20.20.0/24

topology:
  nodes:
    brl4lb:
      kind: bridge

    # 10.1.5.1-eth1 10.1.8.1/24-eth2
    router:
      kind: linux
      image: 192.168.2.100:5000/vyos/vyos:1.4.9
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - ./startup-conf/router-boot.cfg:/opt/vyatta/etc/config/config.boot

    # 10.1.8.253/24-eth1
    lvs-dr-lb1:
      kind: linux
      image: 192.168.2.100:5000/vyos/vyos:1.4.9
      cmd: /sbin/init
      exec:
        - >
          bash -c '
          ip a a 10.1.8.254/32 dev lo'
        - keepalived -D  -f /etc/keepalived/keepalived.conf
      binds:
        - /lib/modules:/lib/modules
        - ./startup-conf/lvs-dr-lb1-boot.cfg:/opt/vyatta/etc/config/config.boot
        - ./keepalived/keepalived1/keepalived.cfg:/etc/keepalived/keepalived.conf:ro

    # 10.1.8.252/24-eth1
    lvs-dr-lb2:
      kind: linux
      cmd: /sbin/init
      image: 192.168.2.100:5000/vyos/vyos:1.4.9
      exec:
        - >
          bash -c '
          ip a a 10.1.8.254/32 dev lo'
        - keepalived -D  -f /etc/keepalived/keepalived.conf
      binds:
        - /lib/modules:/lib/modules
        - ./startup-conf/lvs-dr-lb2-boot.cfg:/opt/vyatta/etc/config/config.boot
        - ./keepalived/keepalived2/keepalived.cfg:/etc/keepalived/keepalived.conf:ro

    dr-rs1:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip a a 10.1.8.10/24 dev net1
      - ip a a 10.1.8.254/32 dev lo
      - ip r r default via 10.1.8.1 dev net1
      - >
        sh -c '
        bash -c "echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore" && bash -c "echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce" &&
        bash -c "echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore" && bash -c "echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce"'
          

    dr-rs2:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip a a 10.1.8.11/24 dev net1
      - ip a a 10.1.8.254/32 dev lo
      - ip r r default via 10.1.8.1 dev net1
      - >
        sh -c '
        bash -c "echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore" && bash -c "echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce" &&
        bash -c "echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore" && bash -c "echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce"'

    client1:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip addr add 10.1.5.5/24 dev net1
      - ip r r default via 10.1.5.1

    client2:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip addr add 10.1.9.5/24 dev net1
      - ip r r default via 10.1.9.1

  links:
    - endpoints: ["client1:net1", "router:eth1"]
    - endpoints: ["client2:net1", "router:eth3"]
    - endpoints: ["router:eth2", "brl4lb:net1"]
    - endpoints: ["lvs-dr-lb1:eth1", "brl4lb:net2"]
    - endpoints: ["lvs-dr-lb2:eth1", "brl4lb:net3"]
    - endpoints: ["dr-rs1:net1", "brl4lb:net4"]
    - endpoints: ["dr-rs2:net1", "brl4lb:net5"]
EOF

