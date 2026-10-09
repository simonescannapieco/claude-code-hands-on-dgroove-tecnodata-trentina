# 2026-09-13 23:50:06 by RouterOS 7.15.3
# software id = 21MV-9803
#
# model = CK-V11
# serial number = CK21MV9803
/interface bridge
add name=br-valle vlan-filtering=yes
/interface ethernet
set [ find default-name=ether1 ] comment="ptp-cles-01 (ponte radio verso Trento)"
set [ find default-name=ether2 ] comment="bts-cles-01 ether1"
set [ find default-name=ether3 ] comment="bts-cavareno-01 (fibra di zona)"
/interface vlan
add interface=br-valle name=vlan903-transito-cles vlan-id=903
add interface=br-valle name=vlan999-gestione vlan-id=999
/interface bridge port
add bridge=br-valle interface=ether1
add bridge=br-valle interface=ether2
add bridge=br-valle interface=ether3
/interface bridge vlan
add bridge=br-valle tagged=br-valle,ether1,ether2,ether3 vlan-ids=103
add bridge=br-valle tagged=br-valle,ether1,ether2 vlan-ids=300
add bridge=br-valle tagged=br-valle,ether1 vlan-ids=903
add bridge=br-valle tagged=br-valle,ether1,ether2,ether3 vlan-ids=999
/ip address
add address=192.0.2.6/26 interface=vlan999-gestione
add address=192.0.2.73/31 interface=vlan903-transito-cles
add address=192.0.2.134 interface=br-valle
/ipv6 address
add address=2001:db8:c1a5::6/64 advertise=no interface=vlan999-gestione
/ip route
add gateway=192.0.2.62 routing-table=main dst-address=192.0.2.0/24 distance=200 comment="riserva per la gestione"
/routing ospf instance
add name=ospf1 router-id=192.0.2.134
/routing ospf area
add instance=ospf1 name=backbone
/routing ospf interface-template
add area=backbone interfaces=vlan903-transito-cles type=ptp
/ip dns
set servers=203.0.113.80,203.0.113.81
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh address=192.0.2.0/26
set www-ssl address=192.0.2.0/26 certificate=gestione disabled=no
set api disabled=yes
set winbox address=192.0.2.0/26
set api-ssl disabled=yes
/radius
add address=192.0.2.41 secret=nas-371f22ff1c97 service=login src-address=192.0.2.6 timeout=1s
/snmp community
set [ find default=yes ] disabled=yes
add authentication-protocol=SHA1 encryption-protocol=AES name=monitor security=private addresses=192.0.2.43/32
/snmp
set contact=noc@ciaspolink.example.org enabled=yes location="traliccio Cles" trap-generators=interfaces trap-target=192.0.2.43 trap-version=3
/system clock
set time-zone-name=Europe/Rome
/system identity
set name=rtr-cles-01
/system logging action
set 3 remote=192.0.2.243
/system logging
add action=remote topics=info
add action=remote topics=error
add action=remote topics=critical
add action=remote topics=warning
add action=remote topics=account
/system ntp client
set enabled=yes
/system ntp client servers
add address=192.0.2.244
/user aaa
set use-radius=yes
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
