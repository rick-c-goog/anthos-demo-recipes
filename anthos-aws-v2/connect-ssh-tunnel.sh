cd $HOME/anthos-aws-v2/
source ./aws-resources.sh
ssh -o 'ServerAliveInterval=30' \
      -o 'ServerAliveCountMax=3' \
      -o 'UserKnownHostsFile=/dev/null' \
      -o 'StrictHostKeyChecking=no' \
      -i $SSH_PRIVATE_KEY \
      -L 8118:127.0.0.1:8118 \
      ubuntu@$BASTION_IP -N
