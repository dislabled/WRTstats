#!/bin/sh

# Copyright (c) 2021 Stian Knudsen
# Licensed under the MIT License


# Variables for script:
influxHost="10.0.0.2:8086"
influxDB="router"
hosts="Sauna:10.0.0.2 Gateway:82.164.229.1 Google:8.8.8.8"
interfaces="lan wan wl0 wl1"


# Function to send data to the InfluxDB database
send2Influx() {
    curl -is -XPOST http://$influxHost/write?db=$influxDB --data-binary "$@ ${curDate}000000000" >/dev/null 2>&1
}

# Get the uptime of router
getUptime() {
    uptime=`cat /proc/uptime | cut -d " " -f 1`
    send2Influx "hw,type=uptime uptime=$uptime"
}

# Return latency for a pinged host
pingHosts() {
    pingResult=`ping -c 10 $1 | tail -2`
    packetLoss=`echo "$pingResult" |grep "packet loss" | cut -d "," -f 3 | cut -d " " -f 2| sed 's/.$//'`
    latency=`echo "$pingResult" |grep "round-trip" | cut -d "=" -f 2 | cut -d "/" -f 1 | sed 's/^ *//'`
    send2Influx "latency,host=$2 latency=$latency,loss=$packetLoss"
}

# Get the temperatures for CPU, and the 2.4 / 5ghz chip
getTemp() {
    cpuTemp=`awk "BEGIN {print $(cat /proc/dmu/temperature)/10; exit}"`
    wl0Temp=$(wl -i eth1 phy_tempsense | awk ' { print $1 } ' )
    wl1Temp=$(wl -i eth2 phy_tempsense | awk ' { print $1 } ' )
    send2Influx "hw,type=temp cpu=$cpuTemp,wl0=$wl0Temp,wl1=$wl1Temp"
}

# Get the current load on the CPU
getLoad() {
    load=`cat /proc/loadavg | sed 's/\// /' | cut -d " " -f 1-5`
    sendfunc() {
        send2Influx "hw,type=load 1m=$1,5m=$2,15m=$3,run=$4,total=$5"
    }
    sendfunc $load
}

# Get the number of current associated clients
getWClients() {
    wl0=`wl -i eth1 assoclist | wc -l`
    wl1=`wl -i eth2 assoclist | wc -l`
    send2Influx "network,type=wclients wl0=$wl0,wl1=$wl1"
}

# Get memory info
getMemInfo() {
    memvalues=`awk '/MemTotal/ {TOT=$2} /MemFree/ {FREE=$2} /Buffers/ {BUF=$2} /^Cached/ {CACH=$2} \
/Active:/ {ACT=$2} /Inactive:/ {INACT=$2} END {printf("hw,type=mem total=%d,free=%d,\
used=%d,buffers=%d,cached=%d,active=%d,inactive=%d",TOT,FREE,TOT-FREE,BUF,CACH,ACT,INACT)}' /proc/meminfo`
    send2Influx "$memvalues"
}

# Get info about current connections
getConnInfo() {
    connections=`cat /proc/net/nf_conntrack`
    tcp=`echo "$connections" | grep ipv4 | grep tcp | wc -l`
    udp=`echo "$connections" | grep ipv4 | grep udp | wc -l`
    icmp=`echo "$connections" | grep ipv4 | grep icmp | wc -l`
    total=`echo "$connections" | grep ipv4 | wc -l`
    send2Influx "network,type=connections tcp=$tcp,udp=$udp,icmp=$icmp,total=$total"
}

# Get info about the CPU
getCPUInfo() {
    cpuInfo=`top -n 1 | awk 'NR==2 {printf("hw,type=cpu usage=%d",$8)}'`
    send2Influx "$cpuInfo"
}

# Get bandwidth for each interface listed
getBandwidth() {
    for i in $interfaces ; do
        iface=`nvram get $i\_ifname` # Get inteface name
        rx=0
        tx=0
        rx=`cat /sys/class/net/$iface/statistics/rx_bytes`
        tx=`cat /sys/class/net/$iface/statistics/tx_bytes`
        send2Influx "bandwidth,iface=$iface rx=$rx,tx=$tx"
    done
}

# Get current time
curDate=`date +%s`

# Iterate through hosts to ping. Using awk for range because of SH compability.
for t in $(awk 'BEGIN { for ( i=0; i<3; i++ ) { print i; } }') ; do
    for i in $hosts ; do
        host=`echo $i | cut -d ":" -f1`
        ip=`echo $i | cut -d ":" -f2`
        pingHosts $ip $host &
    done &
    getUptime &
    getTemp &
    getLoad &
    getWClients &
    getMemInfo &
    getConnInfo &
    getCPUInfo &
    getBandwidth &
    sleep 10
    getBandwidth &
    sleep 10
done

