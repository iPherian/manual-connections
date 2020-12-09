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

while true; do
  if [[ ! $PIA_TOKEN ]]; then
    export PIA_TOKEN="$(./get_token.sh)"
  fi

  ./port_forwarding.sh
  ret=$?
  # if the port forwarding script has run at least once, then either startup has succeeded or failed permanently, and we don't want to write this file more than once, so remove the var.
  unset PIA_WRITE_STARTUP_DONE_FILE

  if [[ $ret -eq 0 ]]; then
    exit 0
  elif [[ $ret -ne 20 ]]; then # code 20 is port expired
    1>&2 echo "Error: port_forwarding.sh fatal error ($ret). Ending."
    exit 1
  fi
  unset PIA_TOKEN
  # avoid requesting tokens too often
  sleep 10
  echo "Port seems to have expired. Trying to get a new one."
done
