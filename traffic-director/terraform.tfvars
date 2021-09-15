#project-id = ""
nameprefix = "sme2020-td"
nodesize = "e2-standard-2"
deploy_test_vms = true #To-Do: conditional resource here
vm_spec = "e2-small" # Used for test VMs
control-plane = "control-plane"
web-docker-image = "web-service"
gcr-location = "gcr.io/codelab-scripts"
payment-svc-img = "payment-service:latest"
# If you want a multi-zone cluster, add additional zones to the map
# This will deploy one cluster per region.
zoneregions = {
      "asia-southeast1" = ["asia-southeast1-b"],
      "us-central1" = ["us-central1-c"],
}

# Add subnets, one per each region. Must match items of zoneregions.
subnets = [
    "10.11.0.0/22",
    "10.11.4.0/22"
]
# Add secondary range subnets, one per each region. Must match zoneregions length.
podranges = [
    "172.16.0.0/18",
    "172.16.64.0/18"
]
svcranges = [
    "172.16.254.0/24",
    "172.16.255.0/24"
]
masterranges = [
    "192.168.0.0/28",
    "192.168.64.0/28"
]
apis = [
  "compute.googleapis.com",
  "trafficdirector.googleapis.com",
  "pubsub.googleapis.com",
  "container.googleapis.com",
  "oslogin.googleapis.com"
]