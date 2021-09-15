#!/bin/bash
#Check if someone's applied this already to their environment
if grep -Fxq "echo \"Updating /etc/hosts\"" ~/.customize_environment 2>/dev/null
then
  echo "Fix already applied. Exiting"
  exit 1
fi
set +H
#If .customize_environment doesn't exist, we need shebang first
if [ ! -f "~/.customize_environment" ]; then
  echo "#!/bin/sh" > ~/.customize_environment
fi
#Write to the file so it traverses through each of the API and adds a static host entry for them,
#Any additional APIs will need to be placed in the API variable
cat << 'EOF' >> ~/.customize_environment
echo "Updating /etc/hosts"
export APIS="googleapis.com www.googleapis.com storage.googleapis.com iam.googleapis.com container.googleapis.com cloudresourcemanager.googleapis.com"
for i in $APIS
do
  echo "199.36.153.8 $i" >> /etc/hosts
done
EOF

#Apply to the hosts file right now, so user does not need to restart cloud shell
export APIS="googleapis.com www.googleapis.com storage.googleapis.com iam.googleapis.com container.googleapis.com cloudresourcemanager.googleapis.com"
for i in $APIS
do
  sudo sh -c "echo '199.36.153.9 $i' >> /etc/hosts"
done
