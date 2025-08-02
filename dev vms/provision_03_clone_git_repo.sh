#!/bin/bash
echo "Git repo clone Current working directory: $(pwd)"
if [ ! -d "interactivebrokers2" ]; then
  echo "Cloning interactivebrokers2 repository..."
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone git@github.com:arslan-qamar/interactivebrokers2.git
fi
