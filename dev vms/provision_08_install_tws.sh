#!/bin/bash
if [ ! -d ~/tws ]; then
  wget https://download2.interactivebrokers.com/installers/tws/latest-standalone/tws-latest-standalone-linux-x64.sh
  chmod +x tws-latest-standalone-linux-x64.sh
  ./tws-latest-standalone-linux-x64.sh -q
else
  echo "TWS already installed, skipping."
fi
