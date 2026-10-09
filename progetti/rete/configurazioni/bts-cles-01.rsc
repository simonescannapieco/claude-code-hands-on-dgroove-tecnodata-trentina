# 2026-09-13 23:50:22 by RouterOS 7.15.3
# software id = 24WU-1056
#
# model = CK-W3
# serial number = CK24WU1056
/interface bridge
add name=br-fwa vlan-filtering=yes
/interface ethernet
set [ find default-name=ether1 ] comment="rtr-cles-01 ether2"
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
add authentication-types=wpa2-psk mode=dynamic-keys name=fwa wpa2-pre-shared-key=Fwa-Cles-7e2d9a41c0b85f36
/interface wireless
set [ find default-name=wlan1 ] band=5ghz-a/n country=italy disabled=no frequency=5180 installation=outdoor mode=ap-bridge name=wlan-s1 nv2-security=enabled radio-name=bts-cles-01-s1 security-profile=fwa ssid=ciaspolink-cles-s1 tx-power=18 tx-power-mode=all-rates-fixed wireless-protocol=nv2
set [ find default-name=wlan2 ] band=5ghz-a/n country=italy disabled=no frequency=5220 installation=outdoor mode=ap-bridge name=wlan-s2 nv2-security=enabled radio-name=bts-cles-01-s2 security-profile=fwa ssid=ciaspolink-cles-s2 tx-power=18 tx-power-mode=all-rates-fixed wireless-protocol=nv2
set [ find default-name=wlan3 ] band=5ghz-a/n/ac channel-width=20/40/80mhz-Ceee country=italy disabled=no frequency=5260 installation=outdoor mode=ap-bridge name=wlan-s3 nv2-security=enabled radio-name=bts-cles-01-s3 security-profile=fwa ssid=ciaspolink-cles-s3 tx-power=18 tx-power-mode=all-rates-fixed wireless-protocol=nv2
/interface vlan
add interface=br-fwa name=vlan999-gestione vlan-id=999
/interface bridge port
add bridge=br-fwa interface=ether1
add bridge=br-fwa interface=wlan-s1 pvid=103
add bridge=br-fwa interface=wlan-s2 pvid=103
add bridge=br-fwa interface=wlan-s3 pvid=103
/interface bridge vlan
add bridge=br-fwa tagged=br-fwa,ether1 vlan-ids=999
add bridge=br-fwa tagged=ether1 untagged=wlan-s1,wlan-s2,wlan-s3 vlan-ids=103
add bridge=br-fwa tagged=ether1,wlan-s1 vlan-ids=300
/interface wireless access-list
add comment=LN-000202 interface=wlan-s1 mac-address=00:00:5E:00:53:02 vlan-id=300 vlan-mode=use-tag
add comment=LN-000204 interface=wlan-s2 mac-address=00:00:5E:00:53:04
add comment=LN-006112 interface=wlan-s1 mac-address=00:00:5E:00:53:B0
add comment=LN-006113 interface=wlan-s1 mac-address=00:00:5E:00:53:B1
add comment=LN-006114 interface=wlan-s1 mac-address=00:00:5E:00:53:B2
add comment=LN-006115 interface=wlan-s1 mac-address=00:00:5E:00:53:B3
add comment=LN-006116 interface=wlan-s1 mac-address=00:00:5E:00:53:B4
add comment=LN-006117 interface=wlan-s2 mac-address=00:00:5E:00:53:B5
add comment=LN-006118 interface=wlan-s2 mac-address=00:00:5E:00:53:B6
add comment=LN-006119 interface=wlan-s2 mac-address=00:00:5E:00:53:B7
add comment=LN-006120 interface=wlan-s2 mac-address=00:00:5E:00:53:B8
add comment=LN-006121 interface=wlan-s2 mac-address=00:00:5E:00:53:B9
add comment=LN-006122 interface=wlan-s3 mac-address=00:00:5E:00:53:BA
add comment=LN-006123 interface=wlan-s3 mac-address=00:00:5E:00:53:BB
add comment=LN-006124 interface=wlan-s3 mac-address=00:00:5E:00:53:BC
add comment=LN-006125 interface=wlan-s3 mac-address=00:00:5E:00:53:BD
add comment=LN-006126 interface=wlan-s3 mac-address=00:00:5E:00:53:BE
add comment=LN-006127 interface=wlan-s3 mac-address=00:00:5E:00:53:BF
/ip address
add address=192.0.2.22/26 interface=vlan999-gestione
/ipv6 address
add address=2001:db8:c1a5::22/64 advertise=no interface=vlan999-gestione
/ip route
add gateway=192.0.2.62
/ip dns
set servers=203.0.113.80,203.0.113.81
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www address=192.0.2.0/26
set ssh address=192.0.2.0/26
set www-ssl address=192.0.2.0/26 certificate=gestione disabled=no
set api disabled=yes
set winbox address=192.0.2.0/26
set api-ssl disabled=yes
/radius
add address=192.0.2.41 secret=nas-287d4283d11f service=login src-address=192.0.2.22 timeout=1s
/snmp community
set [ find default=yes ] disabled=yes
add authentication-protocol=SHA1 encryption-protocol=AES name=monitor security=private addresses=192.0.2.43/32
/snmp
set contact=noc@ciaspolink.example.org enabled=yes location="traliccio Cles" trap-generators=interfaces trap-target=192.0.2.43 trap-version=3
/system clock
set time-zone-name=Europe/Rome
/system identity
set name=bts-cles-01
/system logging action
set 3 remote=192.0.2.43
/system logging
add action=remote topics=info
add action=remote topics=error
add action=remote topics=critical
add action=remote topics=warning
add action=remote topics=account
/system ntp client
set enabled=yes
/system ntp client servers
add address=192.0.2.44
add address=192.0.2.45
/user aaa
set use-radius=yes
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
