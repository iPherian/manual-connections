#!/bin/bash
# Copyright (C) 2020 Private Internet Access, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

. ./required.sh
. ./funcs.sh

# This function allows you to check if the required tools have been installed.
function check_tool() {
  cmd=$1
  package=$2
  if ! command -v $cmd &>/dev/null
  then
    echo "$cmd could not be found"
    echo "Please install $package"
    exit 1
  fi
}
# Now we call the function to make sure we can use curl and jq.
check_tool curl curl
check_tool jq jq

# This allows you to set the maximum allowed latency in seconds.
# All servers that respond slower than this will be ignored.
# You can inject this with the environment variable MAX_LATENCY.
# The default value is 50 milliseconds.
MAX_LATENCY=${MAX_LATENCY:-0.05}
export MAX_LATENCY

curl_serverlist_req_extra_args=""
serverlist_host="serverlist.piaservers.net"
if [[ -n "${PIA_SERVERLIST_HOST_IP}" ]]; then
  echo "overriding ip for serverlist_host: $PIA_SERVERLIST_HOST_IP"
  curl_serverlist_req_extra_args="--resolve $serverlist_host:443:$PIA_SERVERLIST_HOST_IP"
fi

serverlist_url="https://$serverlist_host/vpninfo/servers/v4"

# This function checks the latency you have to a specific region.
# It will print a human-readable message to stderr,
# and it will print the variables to stdout
printServerLatency() {
  serverIP="$1"
  regionID="$2"
  regionName="$(echo ${@:3} |
    sed 's/ false//' | sed 's/true/(geo)/')"
  ufw_allow_if_requested $serverIP 1>/dev/null
  time=$(LC_NUMERIC=en_US.utf8 curl -o /dev/null -s \
    --connect-timeout $MAX_LATENCY \
    --write-out "%{time_connect}" \
    http://$serverIP:443)
  curl_exit_code=$?
  ufw_unallow_if_requested $serverIP 1>/dev/null
  if [ $curl_exit_code -eq 0 ]; then
    1>&2 echo Got latency ${time}s for region: $regionName
    echo $time $regionID $serverIP
  else
    1>&2 echo Got timeout or error for region $regionName
  fi
}
export -f printServerLatency

echo -n "Getting the server list... "
# Get all region data since we will need this on multiple occasions
if [[ -n "${PIA_SERVERLIST_HOST_IP}" ]]; then
  ufw_allow_if_requested $PIA_SERVERLIST_HOST_IP 1>/dev/null
fi
all_region_data=$(curl $curl_serverlist_req_extra_args -s "$serverlist_url" | head -1)
if [[ -n "${PIA_SERVERLIST_HOST_IP}" ]]; then
  ufw_unallow_if_requested $PIA_SERVERLIST_HOST_IP 1>/dev/null
fi

# If the server list has less than 1000 characters, it means curl failed.
if [[ ${#all_region_data} -lt 1000 ]]; then
  echo "Could not get correct region data. To debug this, run:"
  echo "$ curl -v $serverlist_url"
  echo "If it works, you will get a huge JSON as a response."
  exit 1
fi
# Notify the user that we got the server list.
echo "OK!"

# Test one server from each region to get the closest region.
# If port forwarding is enabled, filter out regions that don't support it.
if [[ $PIA_PF == "true" ]]; then
  echo Port Forwarding is enabled, so regions that do not support
  echo port forwarding will get filtered out.
  summarized_region_data="$( echo $all_region_data |
    jq -r '.regions[] | select(.port_forward==true) |
    .servers.meta[0].ip+" "+.id+" "+.name+" "+(.geo|tostring)' )"
else
  summarized_region_data="$( echo $all_region_data |
    jq -r '.regions[] |
    .servers.meta[0].ip+" "+.id+" "+.name+" "+(.geo|tostring)' )"
fi

if [[ -n $PIA_REGION ]]; then
  echo -n Checking if specified region works...
  bestRegion="$(echo "$summarized_region_data" | awk "{if (\$2 == \"$PIA_REGION\") print \$2;}")"
  if [[ -n $bestRegion ]]; then
    echo yes
  else
    echo no.
    echo No servers found in $PIA_REGION with the required features.
    exit 1
  fi
else
  echo Testing regions that respond \
    faster than $MAX_LATENCY seconds:
  bestRegion="$(echo "$summarized_region_data" |
    xargs -I{} bash -c 'printServerLatency {}' |
    sort | head -1 | awk '{ print $2 }')"
fi

if [ -z "$bestRegion" ]; then
  echo ...
  echo No region responded within ${MAX_LATENCY}s, consider using a higher timeout.
  echo For example, to wait 1 second for each region, inject MAX_LATENCY=1 like this:
  echo $ MAX_LATENCY=1 ./get_region_and_token.sh
  exit 1
fi

# Get all data for the best region
regionData="$( echo $all_region_data |
  jq --arg REGION_ID "$bestRegion" -r \
  '.regions[] | select(.id==$REGION_ID)')"

echo -n The closest region is "$(echo $regionData | jq -r '.name')"
if echo $regionData | jq -r '.geo' | grep true > /dev/null; then
  echo " (geolocated region)."
else
  echo "."
fi
echo
bestServer_meta_IP="$(echo $regionData | jq -r '.servers.meta[0].ip')"
bestServer_meta_hostname="$(echo $regionData | jq -r '.servers.meta[0].cn')"
bestServer_WG_IP="$(echo $regionData | jq -r '.servers.wg[0].ip')"
bestServer_WG_hostname="$(echo $regionData | jq -r '.servers.wg[0].cn')"
bestServer_OT_IP="$(echo $regionData | jq -r '.servers.ovpntcp[0].ip')"
bestServer_OT_hostname="$(echo $regionData | jq -r '.servers.ovpntcp[0].cn')"
bestServer_OU_IP="$(echo $regionData | jq -r '.servers.ovpnudp[0].ip')"
bestServer_OU_hostname="$(echo $regionData | jq -r '.servers.ovpnudp[0].cn')"
export PIA_SERVER_META_IP=$bestServer_meta_IP
export PIA_SERVER_META_HOSTNAME=$bestServer_meta_hostname

echo "The script found the best servers from the region closest to you.
When connecting to an IP (no matter which protocol), please verify
the SSL/TLS certificate actually contains the hostname so that you
are sure you are connecting to a secure server, validated by the
PIA authority. Please find below the list of best IPs and matching
hostnames for each protocol:
Meta Services: $bestServer_meta_IP // $bestServer_meta_hostname
WireGuard: $bestServer_WG_IP // $bestServer_WG_hostname
OpenVPN TCP: $bestServer_OT_IP // $bestServer_OT_hostname
OpenVPN UDP: $bestServer_OU_IP // $bestServer_OU_hostname
"

token="$(./get_token.sh)"

if [[ -z "$token" ]]; then
  1>&2 echo "Error: Could not get token."
  exit 1
fi

# just making sure this variable doesn't contain some strange string
if [ "$PIA_PF" != true ]; then
  PIA_PF="false"
fi

: ${PIA_ADD_VPN_ENDPOINT_TO_UFW:=false}

if [[ $PIA_AUTOCONNECT == wireguard ]]; then
  if "$PIA_ADD_VPN_ENDPOINT_TO_UFW"; then
    echo "adding vpn endpoint $bestServer_WG_IP to ufw"
    ufw_allow $bestServer_WG_IP
  fi
  echo The ./get_region_and_token.sh script got started with
  echo PIA_AUTOCONNECT=wireguard, so we will automatically connect to WireGuard,
  echo by running this command:
  echo $ PIA_TOKEN=\"$token\" \\
  echo WG_SERVER_IP=$bestServer_WG_IP WG_HOSTNAME=$bestServer_WG_hostname \\
  echo PIA_PF=$PIA_PF ./connect_to_wireguard_with_token.sh
  echo
  PIA_PF=$PIA_PF PIA_TOKEN="$token" WG_SERVER_IP=$bestServer_WG_IP \
    WG_HOSTNAME=$bestServer_WG_hostname ./connect_to_wireguard_with_token.sh
  exit 0
fi

if [[ $PIA_AUTOCONNECT == openvpn* ]]; then
  serverIP=$bestServer_OU_IP
  serverHostname=$bestServer_OU_hostname
  if [[ $PIA_AUTOCONNECT == *tcp* ]]; then
    serverIP=$bestServer_OT_IP
    serverHostname=$bestServer_OT_hostname
  fi
  if "$PIA_ADD_VPN_ENDPOINT_TO_UFW"; then
    echo "adding vpn endpoint $serverIP to ufw"
    ufw_allow $serverIP
  fi
  echo The ./get_region_and_token.sh script got started with
  echo PIA_AUTOCONNECT=$PIA_AUTOCONNECT, so we will automatically
  echo connect to OpenVPN, by running this command:
  echo PIA_PF=$PIA_PF PIA_TOKEN=\"$token\" \\
  echo   OVPN_SERVER_IP=$serverIP \\
  echo   OVPN_HOSTNAME=$serverHostname \\
  echo   CONNECTION_SETTINGS=$PIA_AUTOCONNECT \\
  echo   ./connect_to_openvpn_with_token.sh
  echo
  PIA_PF=$PIA_PF PIA_TOKEN="$token" \
    OVPN_SERVER_IP=$serverIP \
    OVPN_HOSTNAME=$serverHostname \
    CONNECTION_SETTINGS=$PIA_AUTOCONNECT \
    ./connect_to_openvpn_with_token.sh
  exit 0
fi

echo If you wish to automatically connect to the VPN after detecting the best
echo region, please run the script with the env var PIA_AUTOCONNECT.
echo 'The available options for PIA_AUTOCONNECT are (from fastest to slowest):'
echo  - wireguard
echo  - openvpn_udp_standard
echo  - openvpn_udp_strong
echo  - openvpn_tcp_standard
echo  - openvpn_tcp_strong
echo You can also specify the env var PIA_PF=true to get port forwarding.
echo
echo Example:
echo $ PIA_USER=p0123456 PIA_PASS=xxx \
  PIA_AUTOCONNECT=wireguard PIA_PF=true ./get_region_and_token.sh
echo
echo You can also connect now by running this command:
echo $ PIA_TOKEN=\"$token\" WG_SERVER_IP=$bestServer_WG_IP \
  WG_HOSTNAME=$bestServer_WG_hostname ./connect_to_wireguard_with_token.sh
