#!/bin/bash

IP=`hostname -I | cut -f 1 -d ' '`

for INI in *ini ; do
    sed -i "s/external_ip=.*/external_ip=$IP/" $INI
done

sudo ./MasterServer
