#!/bin/bash

# Script to setup git on a container

set -e

mkdir -p ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git config --global color.ui true
