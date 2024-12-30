#!/bin/bash
set -v
cat <<EOF>clab.yaml | clab deploy -t clab.yaml -
name: ipsec-tunnel-mode
topology:
  nodes:
    gwx:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip a a 10.1.5.1/24 dev net1
      - ip a a 10.1.8.1/24 dev net2


    ipsec1:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip a a 10.244.1.1/24 dev eth1
      - ip addr add 10.1.5.10/24 dev eth2
      - ip r a 10.1.8.0/24 via 10.1.5.1 dev eth2
      - ip r a 10.1.9.0/24 via 10.1.5.1 dev eth2

      - ip xfrm state add src 10.1.5.10 dst 10.1.8.10 proto esp spi 0xfe51d977 reqid 0xfe51d977 mode tunnel auth md5 0x00000000000000000000000000000002 enc aes 0x00000000000000000000000000000001
      - ip xfrm state add src 10.1.8.10 dst 10.1.5.10 proto esp spi 0xfe51d977 reqid 0xfe51d977 mode tunnel auth md5 0x00000000000000000000000000000002 enc aes 0x00000000000000000000000000000001

      - ip xfrm policy add src 10.244.1.10/24 dst 10.244.2.10/24 dir out tmpl src 10.1.5.10 dst 10.1.8.10 proto esp reqid 0xfe51d977 mode tunnel
      - ip xfrm policy add src 10.244.2.10/24 dst 10.244.1.10/24 dir fwd tmpl src 10.1.8.10 dst 10.1.5.10 proto esp reqid 0xfe51d977 mode tunnel
      - ip xfrm policy add src 10.244.2.10/24 dst 10.244.1.10/24 dir in  tmpl src 10.1.8.10 dst 10.1.5.10 proto esp reqid 0xfe51d977 mode tunnel

      - iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -o eth0 -j MASQUERADE

      binds:
        - ./ipsecdump.sh:/ipsecdump.sh

    ipsec2:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip a a 10.244.2.1/24 dev eth1
      - ip addr add 10.1.8.10/24 dev eth2
      - ip r a 10.1.5.0/24 via 10.1.8.1 dev eth2
      - ip r a 10.1.9.0/24 via 10.1.8.1 dev eth2

      - ip xfrm state add src 10.1.8.10 dst 10.1.5.10 proto esp spi 0xfe51d977 reqid 0xfe51d977 mode tunnel auth md5 0x00000000000000000000000000000002 enc aes 0x00000000000000000000000000000001
      - ip xfrm state add src 10.1.5.10 dst 10.1.8.10 proto esp spi 0xfe51d977 reqid 0xfe51d977 mode tunnel auth md5 0x00000000000000000000000000000002 enc aes 0x00000000000000000000000000000001

      - ip xfrm policy add src 10.244.2.10/24 dst 10.244.1.10/24 dir out tmpl src 10.1.8.10 dst 10.1.5.10 proto esp reqid 0xfe51d977 mode tunnel
      - ip xfrm policy add src 10.244.1.10/24 dst 10.244.2.10/24 dir fwd tmpl src 10.1.5.10 dst 10.1.8.10 proto esp reqid 0xfe51d977 mode tunnel
      - ip xfrm policy add src 10.244.1.10/24 dst 10.244.2.10/24 dir in  tmpl src 10.1.5.10 dst 10.1.8.10 proto esp reqid 0xfe51d977 mode tunnel

      - iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -o eth0 -j MASQUERADE

      binds:
        - ./ipsecdump.sh:/ipsecdump.sh

    server1:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip addr add 10.244.1.10/24 dev net0
      - ip route replace default via 10.244.1.1

    server2:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
      - ip addr add 10.244.2.10/24 dev net0
      - ip route replace default via 10.244.2.1


  links:
    - endpoints: ["ipsec1:eth1", "server1:net0"]
    - endpoints: ["ipsec2:eth1", "server2:net0"]
    - endpoints: ["ipsec1:eth2", "gwx:net1"]
    - endpoints: ["ipsec2:eth2", "gwx:net2"]
    
EOF

