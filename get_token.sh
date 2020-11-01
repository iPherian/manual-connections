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

print_auth_file_format_msg() {
  1>&2 echo The format of the PIA_AUTH_FILE is: On the first line,
  1>&2 echo your PIA username and on the second your PIA password.
}

if [[ -n "$PIA_AUTH_FILE" ]] && [[ ! -e "$PIA_AUTH_FILE" ]]; then
  1>&2 echo Warning: PIA_AUTH_FILE was specified but does not exist:
  1>&2 echo $PIA_AUTH_FILE
elif [[ -e "$PIA_AUTH_FILE" ]]; then
  authFileLen=$(wc -l "$PIA_AUTH_FILE" | awk "{print \$1}")
  if [[ $authFileLen -lt 2 ]]; then
    print_auth_file_format_msg  
    1>&2 echo
    1>&2 echo Your current file \""$PIA_AUTH_FILE"\" has "$authFileLen" lines, but requires at least two.
    exit 1;
  fi
  if [[ ! $PIA_USER ]]; then
    PIA_USER=$(head -1 "$PIA_AUTH_FILE")
  fi
  if [[ ! $PIA_PASS ]]; then
    PIA_PASS=$(head -2 "$PIA_AUTH_FILE" | tail -1 )
  fi
fi

if [[ ! $PIA_USER || ! $PIA_PASS || ! $PIA_SERVER_META_IP || ! $PIA_SERVER_META_HOSTNAME ]]; then
  1>&2 echo If you want this script to automatically get a token from
  1>&2 echo the Meta service, please add the variables PIA_USER,
  1>&2 echo PIA_PASS, PIA_SERVER_META_IP, and PIA_SERVER_META_HOSTNAME.
  1>&2 echo PIA_AUTH_FILE may be subsituted for the user and pass.
  print_auth_file_format_msg
  1>&2 echo Example:
  1>&2 echo $ PIA_USER=p0123456 PIA_PASS=xxx PIA_SERVER_META_IP=x.x.x.x  PIA_SERVER_META_HOSTNAME=xxx ./get_token.sh
  exit 1
fi

1>&2 echo "The ./get_token.sh script got started with PIA_USER and PIA_PASS and PIA_SERVER_META_HOSTNAME and PIA_SERVER_META_IP,
so we will also use a meta service to get a new VPN token."

# retry a few times because occasional timeouts have been observed connecting to meta servers
max_tries=10
for i in $(eval echo {1..$max_tries}); do
  1>&2 echo "Trying to get a new token by authenticating with the meta service ($i-th try)..."
  ufw_allow_if_requested $PIA_SERVER_META_IP 1>/dev/null
  generateTokenResponse=$(curl -s -u "$PIA_USER:$PIA_PASS" \
    --connect-to "$PIA_SERVER_META_HOSTNAME::$PIA_SERVER_META_IP:" \
    --cacert "ca.rsa.4096.crt" \
    --max-time 30 \
    "https://$PIA_SERVER_META_HOSTNAME/authv3/generateToken")
  ufw_unallow_if_requested $PIA_SERVER_META_IP 1>/dev/null
  1>&2 echo "$generateTokenResponse"

  if [ "$(echo "$generateTokenResponse" | jq -r '.status')" != "OK" ]; then
    1>&2 echo "Could not get a token. Please check your account credentials."
    1>&2 echo
    1>&2 echo "You can also try debugging by manually running the curl"
    1>&2 echo "command (replace user and pass with the real values):"
    1>&2 echo $ curl -vs -u "PIA_USER:PIA_PASS" --cacert ca.rsa.4096.crt \
      --connect-to "$PIA_SERVER_META_HOSTNAME::$PIA_SERVER_META_IP:" \
      https://$PIA_SERVER_META_HOSTNAME/authv3/generateToken
    1>&2 echo "Waiting before possibly retrying again..."
    if [[ $i -lt 3 ]]; then
      sleep 10
    else
      sleep 20
    fi
    continue
  fi

  token="$(echo "$generateTokenResponse" | jq -r '.token')"
  1>&2 echo "This token will expire in 24 hours.
  "
  break
done

echo $token