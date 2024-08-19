#!/bin/bash

HOST_IP=$(ip -4 addr show docker0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
export HOST_IP

docker-compose up -d
