#!/bin/bash
set -v
# http://192.168.2.100/http/MPLS%20in%20GRE%20tunnel%20on%20Linux%20with%20iproute2%20-%20Pengcheng%20Xu%27s%20Place%20%285_31_2024%2011_28_17%20AM%29.html

# mpls ovr gre topo:
#                      gre
#    10.199.0.1-gre            gre-10.199.0.2
#      10.128.0.2/16   ---   10.128.100.2/16
#                      mpls


cat <<EOF>clab.yaml | clab deploy -t clab.yaml -
name: mpls
topology:
  nodes:
    mpls1:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
        - >
          bash -c '
          ip a a 10.128.0.2/16 dev eth1 &&
          
          ip tun a foo4 mode gre remote 10.128.100.2 local 10.128.0.2 &&
          ip addr a 10.199.0.1 dev foo4 &&
          ip link set foo4 up &&
          ip rou a 10.199.0.0/24 dev foo4 &&

          sysctl -w net.mpls.platform_labels=65535 &&
          sysctl -w net.mpls.conf.foo4.input=1 &&
          ip rou change 10.199.0.0/24 encap mpls 100 dev foo4 &&
          ip -f mpls rou a 101 dev lo &&

          sysctl -w net.ipv4.conf.all.rp_filter=2'

    mpls2:
      kind: linux
      image: 192.168.2.100:5000/nettool
      exec:
        - >
          bash -c '
          ip a a 10.128.100.2/16 dev eth1 &&

          ip tun a foo4 mode gre remote 10.128.0.2 local 10.128.100.2 &&
          ip addr a 10.199.0.2 dev foo4 &&
          ip link set foo4 up &&
          ip rou a 10.199.0.0/24 dev foo4 &&

          sysctl -w net.mpls.platform_labels=65535 &&
          sysctl -w net.mpls.conf.foo4.input=1 &&
          ip rou change 10.199.0.0/24 encap mpls 101 dev foo4 &&
          ip -f mpls rou a 100 dev lo &&

          sysctl -w net.ipv4.conf.all.rp_filter=2'

  links:
    - endpoints: ["mpls1:eth1", "mpls2:eth1"]

EOF

