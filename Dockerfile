FROM debian:buster-slim

RUN echo "deb http://ftp.debian.org/debian buster-backports main" | tee /etc/apt/sources.list.d/backports.list
RUN apt-get update && apt-get upgrade --no-install-recommends -y
RUN apt-get install --no-install-recommends -y \
	ca-certificates \
	curl \
	iproute2 \
	iptables \
	jq \
	procps \
	wireguard-tools

COPY . /src

WORKDIR /src

VOLUME /etc/wireguard

ENV PIA_LOCAL_ROUTES ""
ENV PIA_REGION ""

CMD PIA_LOCAL_ROUTES="$PIA_LOCAL_ROUTES" PIA_AUTH_FILE=/etc/wireguard/auth.conf PIA_AUTOCONNECT=wireguard PIA_PF=true PIA_REGION="$PIA_REGION" get_region_and_token.sh
