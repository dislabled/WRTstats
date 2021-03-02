# WRTstats
Export of router stats to InfluxDB, and presentation with Grafana JSON Model

![WRTstats][screenshot]

## Prereq
* A router running DD-WRT
* A local server running InfluxDB and Grafana.

## Installation

1. Enable JFFS support on the router
2. Upload the script to /jffs/bin/
3. Edit the database IP, and port.
4. Add  ```* 0 * * * root /jffs/bin/main.sh > /dev/null 2>&1``` to router cron jobs.
5. Import JSON file to grafana.



This is working and tested on a Netgear R7000
Based / modified of https://github.com/trevorndodds/dd-wrt-grafana

[screenshot]: images/screenshot.png
