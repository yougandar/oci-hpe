#!/bin/bash

iqn=$1
blockIp=$2
iqn1=$3
blockIp1=$4
sudo iscsiadm -m node -o new -T $iqn -p $blockIp:3260
sudo iscsiadm -m node -o update -T $iqn -n node.startup -v automatic
sudo iscsiadm -m node -T $iqn -p $blockIp:3260 -l
sudo iscsiadm -m node -o new -T $iqn1 -p $blockIp1:3260
sudo iscsiadm -m node -o update -T $iqn1 -n node.startup -v automatic
sudo iscsiadm -m node -T $iqn1 -p $blockIp1:3260 -l
