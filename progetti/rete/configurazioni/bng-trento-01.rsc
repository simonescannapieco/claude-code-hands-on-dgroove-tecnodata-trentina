# 2026-09-13 23:50:01 by RouterOS 7.16.2
# software id = 21TE-8142
#
# model = CK-B12
# serial number = CK21TE8142
/interface bridge
add name=lo
/interface ethernet
set [ find default-name=sfp-sfpplus1 ] comment="core-trento-01 Te0/0/1" l2mtu=9100 mtu=9000
set [ find default-name=sfp-sfpplus2 ] comment="sw-trento-01 Te1/1/1 (VLAN abbonati)" l2mtu=9100
/interface vlan
add interface=sfp-sfpplus2 name=vlan100-pppoe-trento vlan-id=100
add interface=sfp-sfpplus2 name=vlan101-pppoe-pergine vlan-id=101
add interface=sfp-sfpplus2 name=vlan102-pppoe-rovereto vlan-id=102
add interface=sfp-sfpplus2 name=vlan103-pppoe-valdinon vlan-id=103
add interface=sfp-sfpplus2 name=vlan210-biz-trento vlan-id=210
add interface=sfp-sfpplus2 name=vlan300-biz-statici vlan-id=300
add interface=sfp-sfpplus2 name=vlan312-biz-rovereto vlan-id=312
add interface=sfp-sfpplus2 name=vlan999-gestione vlan-id=999
/ip pool
add name=pool-casa-1 ranges=198.51.100.2-198.51.100.126
add name=pool-casa-2 ranges=198.51.100.130-198.51.100.190
add name=pool-casa next-pool=pool-casa-2 ranges=198.51.100.2-198.51.100.126
/ppp profile
add change-tcp-mss=no dns-server=203.0.113.80,203.0.113.81 local-address=198.51.100.1 name=casa only-one=yes remote-address=pool-casa use-ipv6=yes use-upnp=no
/interface pppoe-server server
add authentication=pap,chap default-profile=casa disabled=no interface=vlan100-pppoe-trento max-mru=1500 max-mtu=1500 one-session-per-host=yes service-name=pppoe-trento-100
add authentication=pap,chap default-profile=casa disabled=no interface=vlan101-pppoe-pergine max-mru=1500 max-mtu=1500 one-session-per-host=yes service-name=pppoe-pergine-101
add authentication=pap,chap default-profile=casa disabled=no interface=vlan102-pppoe-rovereto max-mru=1500 max-mtu=1500 one-session-per-host=yes service-name=pppoe-rovereto-102
add authentication=pap,chap default-profile=casa disabled=no interface=vlan103-pppoe-valdinon max-mru=1500 max-mtu=1500 one-session-per-host=yes service-name=pppoe-valdinon-103
/ip address
add address=192.0.2.1/26 interface=vlan999-gestione
add address=192.0.2.67/31 interface=sfp-sfpplus1
add address=192.0.2.131 interface=lo
add address=203.0.113.1/26 interface=vlan300-biz-statici
add address=198.51.100.193/27 interface=vlan312-biz-rovereto
add address=198.51.100.225/27 interface=vlan210-biz-trento
/ipv6 address
add address=2001:db8:c1a5::1/64 advertise=no interface=vlan999-gestione
/ip dhcp-relay
add add-relay-info=yes dhcp-server=192.0.2.42 disabled=no interface=vlan210-biz-trento local-address=198.51.100.225 name=relay-biz-trento
add add-relay-info=yes dhcp-server=192.0.2.42 disabled=no interface=vlan300-biz-statici local-address=203.0.113.1 name=relay-biz-statici
add add-relay-info=yes dhcp-server=192.0.2.42 disabled=no interface=vlan312-biz-rovereto local-address=198.51.100.193 name=relay-biz-rovereto
/ppp aaa
set interim-update=12h use-radius=yes
/radius incoming
set accept=yes
/routing ospf instance
add name=ospf1 originate-default=never router-id=192.0.2.131
/routing ospf area
add instance=ospf1 name=backbone
/routing ospf interface-template
add area=backbone interfaces=sfp-sfpplus1 type=ptp
add area=backbone interfaces=lo passive
/ip firewall filter
add action=accept chain=input connection-state=established,related
add action=accept chain=input protocol=ospf
add action=accept chain=input src-address=192.0.2.0/26
add action=accept chain=input dst-port=67 protocol=udp comment="relay DHCP business"
add action=drop chain=input in-interface-list=!gestione
/interface list
add name=gestione
/interface list member
add interface=vlan999-gestione list=gestione
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
add address=192.0.2.41 secret=nas-07bc0df55ad8 service=ppp,login src-address=192.0.2.1 timeout=1s
/snmp community
set [ find default=yes ] name=ciaspolink
/snmp
set contact=noc@ciaspolink.example.org enabled=yes location="POP Trento, sala apparati" trap-generators=interfaces trap-target=192.0.2.43 trap-version=3
/system clock
set time-zone-name=Europe/Rome
/system identity
set name=bng-trento-01
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
