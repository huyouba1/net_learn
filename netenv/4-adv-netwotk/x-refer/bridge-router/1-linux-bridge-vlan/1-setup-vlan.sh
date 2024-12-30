#!/bin/bash
set -v
{ ip l s br-vlan down && brctl delbr br-vlan; } > /dev/null 2>&1
brctl addbr br-vlan;ip l s br-vlan up

cat <<EOF>clab.yaml | clab deploy -t clab.yaml -
name: vlan
topology:
  nodes:
    br-vlan:
      kind: bridge

    gwx:
      kind: linux
      image: 192.168.2.100:5000/vyos/vyos:1.4.7
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - ./startup-conf/gwx-boot.cfg:/opt/vyatta/etc/config/config.boot

    vlan1:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      # N-S Traffic:
        - >
          bash -c '
          vconfig add net1 5 &&
          ip l s net1.5 up &&
          ip a a 10.1.5.10/24 dev net1.5 &&
          
          ip route add 0.0.0.0/0 via 10.1.5.1 table 5 &&
          ip rule add from 10.1.5.0/24 table 5'
 
    vlan2:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      # E-W Traffic:
        - >
          bash -c '
          vconfig add net1 8 &&
          ip l s net1.8 up &&
          ip a a 10.1.8.10/24 dev net1.8 &&
          
          ip route add 0.0.0.0/0 via 10.1.8.1 table 8 &&
          ip rule add from 10.1.8.0/24 table 8'

    vlan3:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      # E-W Traffic:
        - >
          bash -c '
          vconfig add net1 9 &&
          ip l s net1.9 up &&
          ip a a 10.1.9.10/24 dev net1.9 &&
          
          ip route add 0.0.0.0/0 via 10.1.9.1 table 9 &&
          ip rule add from 10.1.9.0/24 table 9'


  links:
    - endpoints: ["vlan1:net1", "br-vlan:eth2"]
    - endpoints: ["vlan2:net1", "br-vlan:eth3"]
    - endpoints: ["vlan3:net1", "br-vlan:eth4"]
    - endpoints: ["br-vlan:net0", "gwx:eth1"]

EOF

