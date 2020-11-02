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

set -a

# Begin Firewall Related

function on_demand_rules_cmd {
  if [[ "$PIA_ON_DEMAND_UFW_RULES" == "true" ]]; then
    eval "$@"
  fi
}

function make_ufw_allow_args {
  destination=$1
  if [[ -z $destination ]]; then
    1>&2 echo "${FUNCNAME[0]}: error: first param destination was empty"
    return 1
  fi
  echo "allow out from any to $destination"
}

function ufw_allow {
  destination=$1
  if [[ -z $destination ]]; then
    1>&2 echo "${FUNCNAME[0]}: error: first param destination was empty"
    return 1
  fi
  ufw $(make_ufw_allow_args $destination)
}

function ufw_unallow {
  destination=$1
  if [[ -z $destination ]]; then
    1>&2 echo "${FUNCNAME[0]}: error: first param destination was empty"
    return 1
  fi
  ufw delete $(make_ufw_allow_args $destination)
}

function ufw_allow_if_requested {
  destination=$1
  if [[ -z $destination ]]; then
    1>&2 echo "${FUNCNAME[0]}: error: first param destination was empty"
    return 1
  fi
  on_demand_rules_cmd ufw_allow $destination
}

function ufw_unallow_if_requested {
  destination=$1
  if [[ -z $destination ]]; then
    1>&2 echo "${FUNCNAME[0]}: error: first param destination was empty"
    return 1
  fi
  on_demand_rules_cmd ufw_unallow $destination
}

# End Firewall Related

function datetime_to_epoch_secs {
  datetime="$1"
  echo $(date --date "$datetime" +'%s')
}

set +a
