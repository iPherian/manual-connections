if [[ -e $PIA_AUTH_FILE ]]; then
  authFileLen=$(wc -l "$PIA_AUTH_FILE")
  if [[ $authFileLen -lt 2 ]]; then
    1>&2 echo This script will grab your PIA username from the first
    1>&2 echo line if the file specified by PIA_AUTH_FILE, and your
    1>&2 echo PIA password from the last line.  
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

if [[ ! $PIA_USER || ! $PIA_PASS ]]; then
  echo If you want this script to automatically get a token from the Meta
  echo service, please add the variables PIA_USER and PIA_PASS. Example:
  echo $ PIA_USER=p0123456 PIA_PASS=xxx ./get_region_and_token.sh
  exit 1
fi

echo "The ./get_region_and_token.sh script got started with PIA_USER and PIA_PASS,
so we will also use a meta service to get a new VPN token."

echo "Trying to get a new token by authenticating with the meta service..."
ufw_allow_if_requested $bestServer_meta_IP 1>/dev/null
generateTokenResponse=$(curl -s -u "$PIA_USER:$PIA_PASS" \
  --connect-to "$bestServer_meta_hostname::$bestServer_meta_IP:" \
  --cacert "ca.rsa.4096.crt" \
  "https://$bestServer_meta_hostname/authv3/generateToken")
ufw_unallow_if_requested $bestServer_meta_IP 1>/dev/null
echo "$generateTokenResponse"

if [ "$(echo "$generateTokenResponse" | jq -r '.status')" != "OK" ]; then
  echo "Could not get a token. Please check your account credentials."
  echo
  echo "You can also try debugging by manually running the curl command:"
  echo $ curl -vs -u "$PIA_USER:$PIA_PASS" --cacert ca.rsa.4096.crt \
    --connect-to "$bestServer_meta_hostname::$bestServer_meta_IP:" \
    https://$bestServer_meta_hostname/authv3/generateToken
  exit 1
fi

token="$(echo "$generateTokenResponse" | jq -r '.token')"
echo "This token will expire in 24 hours.
"
