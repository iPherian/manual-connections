# Fork Description

This is a fork of the pia manual connections script with support for a system that only allows vpn traffic. (requires UFW firewall)

#### Other Features

* Eternal port forwarding (requests a new port on expiration of old)
  * can run a custom command when a forwarded port is established (see ```PIA_ON_PORT_FORWARD```)
* Writes forwarded port to file for use by other services (```/opt/piavpn-manual/pia_port```)
* Can run as a systemd service
  * Instructions: copy *.service file to /etc/systemd/system then customize vars prefixed with $ (e.g. $VAR)
* Can run in a docker container

## Setup

If you want a vpn-only system, make sure you have at least these rules:

```shell
# first make sure you have a way to login
# e.g. if you ssh in:
ufw allow ssh
# deny everything by default:
ufw default deny incoming
ufw default deny outgoing
# but allow the vpn:
ufw allow in on tun06
ufw allow out on tun06
```

## Config

Firewall Related:

( all of these rules are required for a vpn-only system )

| ENV Var | Function |
|-------|------|
|```PIA_ON_DEMAND_UFW_RULES=true```|Before accessing an ip adds a firewall rule allowing outgoing access to it and then removes it afterwards. (requires ufw)|
|```PIA_ADD_VPN_ENDPOINT_TO_UFW=true```|Adds a firewall rule allowing outgoing access the vpn endpoint (permanently).|
|```PIA_SERVERLIST_HOST_IP="xxx.xxx.xxx.xxx"```|The ip for the serverlist host ( serverlist.piaservers.net ). When specified allows it to be accessed without having to permit DNS on the open net through the firewall.|

* Caveat: If using ```PIA_ON_DEMAND_UFW_RULES=true```, backup your ufw rules first. If the script encounteres issues and somehow fails to remove the temporary rules, it may leave behind a lot of spam.

Authentication:

(either ```PIA_AUTH_FILE``` or ```PIA_USER```+```PIA_PASS``` is required)

| ENV Var | Function |
|-------|------|
|```PIA_AUTH_FILE=path```|A file to read your username and password from. The format should be: username on first line, password on second.|
|```PIA_USER=p0123456```|Your username.|
|```PIA_PASS=xxxxx```|Your password.|

Misc:

| ENV Var | Function |
|-------|------|
|```PIA_ON_PORT_FORWARD=command```|A command to be run when a forwarded port is established. The command will be called with one additional argument of the port number.|
|```PIA_REGION=swiss```|Region to connect to. Available server region ids are listed [here](https://serverlist.piaservers.net/vpninfo/servers/v4). Example values include ```us_california```, ```ca_ontario```, and ```swiss```. If left empty, reverts to autodetecting the fastest region.|
|```PIA_LOCAL_ROUTES=xxxxx```|Custom local routes. Many can be specified seperated by a space. (Only applies to wireguard).|
|```PIA_WRITE_STARTUP_DONE_FILE=path```|When startup has completed successfully message "startup done" will be written to the file in the var. Can be used to manage dependencies (i.e. to launch another program when this one has completed). It is particularly useful when using port forwarding, as normally it wouldn't be clear when we have started up as the port forwarding script runs forever.|

# Manual PIA VPN Connections

This repository contains documentation on how to create native WireGuard and OpenVPN connections to our __NextGen network__, and also on how to enable Port Forwarding in case you require this feature. You will find a lot of information below. However if you prefer quick test, here is the __TL/DR__:

```
git clone https://github.com/pia-foss/manual-connections.git
cd manual-connections
./run_setup.sh
```

The scripts were written so that they are easy to read and to modify. The code also has a lot of comments, so that you find all the information you might need. We hope you will enjoy forking the repo and customizing the scripts for your setup!

## Table of Contents

- [Dependencies](#dependencies)
- [Disclaimers](#disclaimers)
- [Confirmed distributions](#confirmed-distributions)
- [3rd Party Repositories](#3rd-party-repositories)
- [PIA Port Forwarding](#pia-port-forwarding)
- [Automated setup](#automated-setup)
- [Manual PF testing](#manual-pf-testing)
- [License](#license)

## Dependencies

In order for the scripts to work (probably even if you do a manual setup), you will need the following packages:
 * `curl`
 * `jq`
 * (only for WireGuard) `wg-quick` and `wireguard` kernel module
 * (only for OpenVPN) `openvpn`

## Disclaimers

 * Port Forwarding is disabled on server-side in the United States.
 * These scripts do not enforce IPv6 or DNS settings, so that you have the freedom to configure your setup the way you desire it to work. This means you should have good understanding of VPN and cybersecurity in order to properly configure your setup.
 * For battle-tested security, please use the official PIA App, as it was designed to protect you in all scenarios.
 * This repo is really fresh at this moment, so please take into consideration the fact that you will probably be one of the first users that use the scripts.
 * Though we support research of open source technologies, we can not provide official support for all FOSS platforms, as there are simply too many platforms (which is a good thing). That is why we link 3rd Party repos in this README. We can not guarantee the quality of the code in the 3rd Party Repos, so use them only if you understand the risks.

## Confirmed distributions

The functionality of the scripts within this repository has been tested and confirmed on the following operating systems and GNU/Linux distributions:
 * Arch
 * Artix
 * Fedora 32, 33
 * FreeBSD 12.1 (tweaks are required)
 * Manjaro
 * PureOS amber
 * Raspberry Pi OS 2020-08-20
 * Ubuntu 18.04, 20.04

## 3rd Party Repositories

Some users have created their own repositories for manual connections, based on the information they found within this repository. We can not guarantee the quality of the code found within these 3rd party repos, but we can create a centralized list so it's easy for you to find repos contain scripts to enable PIA services for your system.

| System | Fork | Language | Scope | Repository |
|:-:|:-:|:-:|:-:|-|
| FreeBSD | Yes | Bash | Compatibility | [glorious1/manual-connections](https://github.com/glorious1/manual-connections) |
| OPNsense | No | Python | WireGuard, PF | [FingerlessGlov3s/OPNsensePIAWireguard](https://github.com/FingerlessGlov3s/OPNsensePIAWireguard) |
| pfSense | No | Sh | OpenVPN, PF | [fm407/PIA-NextGen-PortForwarding](https://github.com/fm407/PIA-NextGen-PortForwarding) |
| Synology | Yes | Bash | Compatibility | [steff2632/manual-connections](https://github.com/steff2632/manual-connections) |
| Synology | No | Python | PF | [stmty9/synology](https://github.com/stmty9/synology) |
| TrueNAS | No | Bash | PF | [dak180/TrueNAS-Scripts](https://github.com/dak180/TrueNAS-Scripts/blob/master/pia-port-forward.sh) |
| UFW | Yes | Bash | Firewall Rules | [iPherian/manual-connections](https://github.com/iPherian/manual-connections) |

## PIA Port Forwarding

The PIA Port Forwarding service (a.k.a. PF) allows you run services on your own devices, and expose them to the internet by using the PIA VPN Network. The easiest way to set this up is by using a native PIA application. In case you require port forwarding on native clients, please follow this documentation in order to enable port forwarding for your VPN connection.

This service can be used only AFTER establishing a VPN connection.

## Automated setup

In order to help you use VPN services and PF on any device, we have prepared a few bash scripts that should help you through the process of setting everything up. The scripts also contain a lot of comments, just in case you require detailed information regarding how the technology works. The functionality is controlled via environment variables, so that you have an easy time automating your setup.

Here is a list of scripts you could find useful:
 * [Get the best region and a token](get_region_and_token.sh): This script helps you to get the best region and also to get a token for VPN authentication. Adding your PIA credentials to env vars `PIA_USER` and `PIA_PASS` will allow the script to also get a VPN token. The script can also trigger the WireGuard script to create a connection, if you specify `PIA_AUTOCONNECT=wireguard` or `PIA_AUTOCONNECT=openvpn_udp_standard`
 * [Connect to WireGuard](connect_to_wireguard_with_token.sh): This script allows you to connect to the VPN server via WireGuard.
 * [Connect to OpenVPN](connect_to_openvpn_with_token.sh): This script allows you to connect to the VPN server via OpenVPN.
 * [Enable Port Forwarding](port_forwarding.sh): Enables you to add Port Forwarding to an existing VPN connection. Adding the environment variable `PIA_PF=true` to any of the previous scripts will also trigger this script.

## Manual PF tesing

To use port forwarding on the NextGen network, first of all establish a connection with your favorite protocol. After this, you will need to find the private IP of the gateway you are connected to. In case you are WireGuard, the gateway will be part of the JSON response you get from the server, as you can see in the [bash script](https://github.com/pia-foss/manual-connections/blob/master/wireguard_and_pf.sh#L119). In case you are using OpenVPN, you can find the gateway by checking the routing table with `ip route s t all`.

After connecting and finding out what the gateway is, get your payload and your signature by calling `getSignature` via HTTPS on port 19999. You will have to add your token as a GET var to prove you actually have an active account.

Example:
```bash
bash-5.0# curl -k "https://10.4.128.1:19999/getSignature?token=$TOKEN"
{
    "status": "OK",
    "payload": "eyJ0b2tlbiI6Inh4eHh4eHh4eCIsInBvcnQiOjQ3MDQ3LCJjcmVhdGVkX2F0IjoiMjAyMC0wNC0zMFQyMjozMzo0NC4xMTQzNjk5MDZaIn0=",
    "signature": "a40Tf4OrVECzEpi5kkr1x5vR0DEimjCYJU9QwREDpLM+cdaJMBUcwFoemSuJlxjksncsrvIgRdZc0te4BUL6BA=="
}
```

The payload can be decoded with base64 to see your information:
```bash
$ echo eyJ0b2tlbiI6Inh4eHh4eHh4eCIsInBvcnQiOjQ3MDQ3LCJjcmVhdGVkX2F0IjoiMjAyMC0wNC0zMFQyMjozMzo0NC4xMTQzNjk5MDZaIn0= | base64 -d | jq 
{
  "token": "xxxxxxxxx",
  "port": 47047,
  "expires_at": "2020-06-30T22:33:44.114369906Z"
}
```
This is where you can also see the port you received. Please consider `expires_at` as your request will fail if the token is too old. All ports currently expire after 2 months.

Use the payload and the signature to bind the port on any server you desire. This is also done by curling the gateway of the VPN server you are connected to.
```bash
bash-5.0# curl -sGk --data-urlencode "payload=${payload}" --data-urlencode "signature=${signature}" https://10.4.128.1:19999/bindPort
{
    "status": "OK",
    "message": "port scheduled for add"
}
bash-5.0# 
```

Call __/bindPort__ every 15 minutes, or the port will be deleted!

### Testing your new PF

To test that it works, you can tcpdump on the port you received:

```
bash-5.0# tcpdump -ni any port 47047
```

After that, use curl __from another machine__ on the IP of the traffic server and the port specified in the payload which in our case is `47047`:
```bash
$ curl "http://178.162.208.237:47047"
```

You should see the traffic in your tcpdump:
```
bash-5.0# tcpdump -ni any port 47047
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked v1), capture size 262144 bytes
22:44:01.510804 IP 81.180.227.170.33884 > 10.4.143.34.47047: Flags [S], seq 906854496, win 64860, options [mss 1380,sackOK,TS val 2608022390 ecr 0,nop,wscale 7], length 0
22:44:01.510895 IP 10.4.143.34.47047 > 81.180.227.170.33884: Flags [R.], seq 0, ack 906854497, win 0, length 0
```

If you run curl on the same machine (the one that is connected to the VPN), you will see the traffic in tcpdump anyway and the test won't prove anything. At the same time, the request will get firewall so you will not be able to access the port from the same machine. This can only be tested properly by running curl on another system.

## License
This project is licensed under the [MIT (Expat) license](https://choosealicense.com/licenses/mit/), which can be found [here](/LICENSE).
