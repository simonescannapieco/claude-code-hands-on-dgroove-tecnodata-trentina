# sep/13/2026 23:50:05 by RouterOS 6.49.10
# software id = 25NK-3653
#
# model = CK-V11
# serial number = CK25NK3653
/interface bridge
add name=br-valle vlan-filtering=yes
/interface ethernet
set [ find default-name=sfp1 ] comment="sw-trento-01 Gi1/0/2"
set [ find default-name=ether2 ] comment="olt-pergine-01 0/9/0"
/interface vlan
add interface=br-valle name=vlan902-transito-pergine vlan-id=902
add interface=br-valle name=vlan999-gestione vlan-id=999
/routing ospf instance
set [ find default=yes ] router-id=192.0.2.133
/snmp community
set [ find default=yes ] disabled=yes
add addresses=192.0.2.43/32 authentication-protocol=SHA1 encryption-protocol=AES name=monitor security=private
/system logging action
set 3 remote=192.0.2.43
/interface bridge port
add bridge=br-valle interface=sfp1
add bridge=br-valle interface=ether2
/interface bridge vlan
add bridge=br-valle tagged=br-valle,sfp1,ether2 vlan-ids=101
add bridge=br-valle tagged=br-valle,sfp1 vlan-ids=902
add bridge=br-valle tagged=br-valle,sfp1,ether2 vlan-ids=999
/ip address
add address=192.0.2.5/26 interface=vlan999-gestione
add address=192.0.2.71/31 interface=vlan902-transito-pergine
add address=192.0.2.133 interface=br-valle
/ip dns
set servers=203.0.113.80,203.0.113.81
/ip route
add comment="riserva per la gestione" distance=200 dst-address=192.0.2.0/24 gateway=192.0.2.62
/ip service
set telnet address=192.0.2.0/26
set ftp disabled=yes
set www disabled=yes
set ssh address=192.0.2.0/26
set www-ssl address=192.0.2.0/26 certificate=gestione disabled=no
set api disabled=yes
set winbox address=192.0.2.0/26
set api-ssl disabled=yes
/ipv6 address
add address=2001:db8:c1a5::5/64 advertise=no interface=vlan999-gestione
/radius
add address=192.0.2.41 secret=nas-40916fcf8da9 service=login src-address=192.0.2.5 timeout=1s
/routing ospf interface
add interface=vlan902-transito-pergine network-type=point-to-point
/routing ospf network
add area=backbone network=192.0.2.70/31
/snmp
set contact=noc@ciaspolink.example.org enabled=yes location="armadio Pergine Valsugana" trap-generators=interfaces trap-target=192.0.2.43 trap-version=3
/system clock
set time-zone-name=Europe/Rome
/system identity
set name=rtr-pergine-01
/system logging
add action=remote topics=info
add action=remote topics=error
add action=remote topics=critical
add action=remote topics=warning
add action=remote topics=account
/system ntp client
set enabled=yes primary-ntp=192.0.2.44 secondary-ntp=192.0.2.45
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
/user aaa
set use-radius=yes
