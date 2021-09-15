provider "google" {
  project     = var.project-id
  version     = "~> 3.37"
}
provider "google-beta" {
  project     = var.project-id
  version     = "~> 3.37"
}
provider "random" {
  version     = "~> 2.3"
}
#data "google_project" "project" {
#}
resource "random_id" "id" {
  byte_length = 3
  prefix = "${var.nameprefix}-"
}
locals {
  rand = var.nameprefix
  zones = values(var.zoneregions)
  regions = keys(var.zoneregions)
  static-bucket = "bkt-${random_id.id.hex}"
}

resource "google_compute_project_metadata" "default" {
  metadata = {
    enable-oslogin  = "TRUE"
    "${random_id.id.hex}" = path.cwd
  }
}
# Network Setup #
resource "google_compute_network" "vpc" {
  name                    = "net-${local.rand}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "region-a-sub" {
  name          = "a-${local.rand}"
  ip_cidr_range = var.subnets[0]
  region        = local.regions[0]
  private_ip_google_access = true
  secondary_ip_range {
  range_name    = "podrange"
    ip_cidr_range = var.podranges[0]
  }
  secondary_ip_range {
    range_name    = "svcrange"
    ip_cidr_range = var.svcranges[0]
  }
  network       = google_compute_network.vpc.self_link
}
resource "google_compute_subnetwork" "region-b-sub" {
  name          = "b-${local.rand}"
  ip_cidr_range = var.subnets[1]
  region        = local.regions[1]
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "podrange"
    ip_cidr_range = var.podranges[1]
  }
  secondary_ip_range {
    range_name    = "svcrange"
    ip_cidr_range = var.svcranges[1]
  }
  network       = google_compute_network.vpc.self_link
}
module "cloud-nat-a" {
  name            = "nat-a-${local.rand}"
  source          = "terraform-google-modules/cloud-nat/google"
  version         = "~> 1.3.0"
  project_id      = var.project-id
  region          = local.regions[0]
  create_router   = true
  router          = "cr-a-${local.rand}"
  network         = google_compute_network.vpc.self_link
}
module "cloud-nat-b" {
  name            = "nat-b-${local.rand}"
  source          = "terraform-google-modules/cloud-nat/google"
  version         = "~> 1.3.0"
  project_id      = var.project-id
  region          = local.regions[1]
  create_router   = true
  router          = "cr-b-${local.rand}"
  network         = google_compute_network.vpc.self_link
}

# Firewall Setup #
resource "google_compute_firewall" "fw-iap-ssh" {
  name          = "ssh-${local.rand}"
  network       = google_compute_network.vpc.self_link
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}
resource "google_compute_firewall" "rfc1918-in" {
  name          = "int-${local.rand}"
  network       = google_compute_network.vpc.self_link
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}
resource "google_compute_firewall" "hc" {
  name          = "hc-${local.rand}"
  network       = google_compute_network.vpc.self_link
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "5001"]
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

# GKE Setup
resource "google_container_cluster" "gke-cluster-a" {
  provider                    = google-beta
  name                        = "payment-tddemo-a-${local.rand}"
  location                    = element(local.zones[0], 0)
  #min_master_version          = data.google_container_engine_versions.gke-cl-a.latest_master_version
  remove_default_node_pool    = true
  initial_node_count          = 1
  network                     = google_compute_network.vpc.name
  subnetwork                  = google_compute_subnetwork.region-a-sub.name
  addons_config {
    network_policy_config {
      disabled = false
    }
  }
  network_policy {
    enabled = true
  }
  private_cluster_config {
    enable_private_nodes      = true
    enable_private_endpoint   = false
    master_ipv4_cidr_block    = var.masterranges[0]
  }
  release_channel {
    channel                   = "REGULAR"
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.region-a-sub.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.region-a-sub.secondary_ip_range[1].range_name
  }
}
resource "google_container_cluster" "gke-cluster-b" {
  name                        = "payment-tddemo-b-${local.rand}"
  provider                    = google-beta
  location                    = element(local.zones[1], 0)
  #min_master_version          = data.google_container_engine_versions.gke-cl-b.latest_master_version
  remove_default_node_pool    = true
  initial_node_count          = 1
  network                     = google_compute_network.vpc.name
  subnetwork                  = google_compute_subnetwork.region-b-sub.name
  addons_config {
    network_policy_config {
      disabled = false
    }
  }
  network_policy {
    enabled = true
  }
  private_cluster_config {
    enable_private_nodes      = true
    enable_private_endpoint   = false
    master_ipv4_cidr_block    = var.masterranges[1]
  }
  release_channel {
    channel                   = "REGULAR"
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.region-b-sub.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.region-b-sub.secondary_ip_range[1].range_name
  }
}

resource "google_container_node_pool" "cluster-a-nodepool" {
  name       = "cluster-a-np"
  provider   = google-beta
  location   = element(local.zones[0], 0)
  cluster    = google_container_cluster.gke-cluster-a.name
  #version    = data.google_container_engine_versions.gke-cl-a.latest_node_version
  node_count = 1
  node_config {
    machine_type = var.nodesize
    image_type = "COS_CONTAINERD"
    #service_account    = "${data.google_project.project.number}-compute@$developer.gserviceaccount.com"
    metadata = {
      disable-legacy-endpoints  = "true"
      control-plane             = var.control-plane
    }
    labels = {
      app = "default-init"
    }
    tags = [
      "gke-node"
    ]
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
resource "google_container_node_pool" "cluster-b-nodepool" {
  name       = "cluster-b-np"
  provider                    = google-beta
  location   = element(local.zones[1], 0)
  cluster    = google_container_cluster.gke-cluster-b.name
  #version    = data.google_container_engine_versions.gke-cl-b.latest_node_version
  node_count = 1
  node_config {
    machine_type = var.nodesize
    image_type = "COS_CONTAINERD"
    #service_account    = "${data.google_project.project.number}-compute@$developer.gserviceaccount.com"
    metadata = {
      disable-legacy-endpoints  = "true"
      control-plane             = var.control-plane
    }
    labels = {
      app = "default-init"
    }
    tags = [
      "gke-node"
    ]
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Test VMs
/*
resource "google_compute_instance" "vm1" {
  name          = "vm-${local.rand}-01"
  machine_type  = var.vm_spec
  zone          = element(local.zones[0], 0)
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  metadata      = {
    serial-port-enable = true
  }
  network_interface {
    subnetwork = google_compute_subnetwork.region-a-sub.self_link
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}
resource "google_compute_instance" "vm2" {
  name          = "vm-${local.rand}-02"
  machine_type  = var.vm_spec
  zone          = element(local.zones[1], 0)
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  metadata      = {
    serial-port-enable = true
  }
  network_interface {
    subnetwork = google_compute_subnetwork.region-b-sub.self_link
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}
*/
### WEB Front-End Config ###
resource "google_compute_instance_template" "fe-region_a" {
  name_prefix  = "rgn-a-fe-tpl-"
  labels = {
    version = "latest"
  }
  region  = local.regions[0]
  lifecycle {
    create_before_destroy = true
  }
  machine_type         = var.nodesize
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  disk {
    source_image = data.google_compute_image.debian9.self_link
    auto_delete  = true
    boot         = true
  }
  network_interface {
    subnetwork = google_compute_subnetwork.region-a-sub.self_link
  }
  metadata = {
    startup-script      = "${file("vm-scripts/web-http-startup.sh")}"
    shutdown-script     = "${file("vm-scripts/web-http-shutdown.sh")}"
    version             = "latest"
    cart-host           = "http://10.128.0.4"
    payment-host        = "http://10.128.0.6"
    control-plane       = var.control-plane
    web-docker-img      = "${var.gcr-location}/${var.web-docker-image}"
    serial-port-enable  = "true"
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}

data "google_compute_image" "debian9" {
  family  = "debian-9"
  project = "debian-cloud"
}
data "google_container_engine_versions" "gke-cl-a" {
  #provider       = "google-beta"
  location       = element(local.zones[0], 0)
}
data "google_container_engine_versions" "gke-cl-b" {
  #provider       = "google-beta"
  location       = element(local.zones[1], 0)
}
resource "google_compute_instance_template" "fe-region_b" {
  name_prefix  = "rgn-b-fe-tpl-"
  labels = {
    version = "latest"
  }
  region  = local.regions[1]
  lifecycle {
    create_before_destroy = true
  }
  machine_type         = var.nodesize
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  disk {
    source_image = data.google_compute_image.debian9.self_link
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.region-b-sub.self_link
  }
  metadata = {
    startup-script      = "${file("vm-scripts/web-http-startup.sh")}"
    shutdown-script     = "${file("vm-scripts/web-http-shutdown.sh")}"
    version             = "latest"
    cart-host           = "http://10.128.0.4"
    payment-host        = "http://10.128.0.6"
    control-plane       = var.control-plane
    web-docker-img      = "${var.gcr-location}/${var.web-docker-image}"
    serial-port-enable  = "true"
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group_manager" "web-mig-a" {
  name               = "web-mig-a${local.rand}"
  base_instance_name = "web-ig-${local.rand}"
  zone               = element(local.zones[0], 0)
  target_size        = "1"
  named_port {
    name = "http"
    port = 80
  }  
  version {
    name              = "latest"
    instance_template = google_compute_instance_template.fe-region_a.id
  }
  depends_on = [
    google_pubsub_topic.control-plane,
  ]
}
resource "google_compute_instance_group_manager" "web-mig-b" {
  name               = "web-mig-b${local.rand}"
  base_instance_name = "web-ig-${local.rand}"
  zone               = element(local.zones[1], 0)
  target_size        = "1"
  named_port {
    name = "http"
    port = 80
  }  
  version {
    name              = "latest"
    instance_template = google_compute_instance_template.fe-region_b.id
  }
  depends_on = [
    google_pubsub_topic.control-plane,
  ]
}

# Cart service
/*
resource "google_compute_instance_template" "cart-region_a" {
  name_prefix  = "tpl-cart-${local.rand}-${element(local.zones[0], 0)}"
  labels = {
    version = "latest"
  }
  region  = local.regions[0]
  lifecycle {
    create_before_destroy = true
  }
  machine_type         = var.nodesize
  can_ip_forward       = false
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  disk {
    source_image = data.google_compute_image.debian9.self_link
    auto_delete  = true
    boot         = true
  }
  network_interface {
    subnetwork = google_compute_subnetwork.region-a-sub.self_link
  }
  metadata = {
    startup-script      = "${file("vm-scripts/cart-startup.sh")}"
    shutdown-script     = "${file("vm-scripts/cart-shutdown.sh")}"
    version             = "latest"
    cart-host           = "http://10.128.0.4"
    payment-host        = "http://10.128.0.6"
    cart-file           = "${google_storage_bucket.static-files.name}/${google_storage_bucket_object.cart-file.output_name}"
    control-plane       = var.control-plane
    serial-port-enable  = "true"
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}
resource "google_compute_instance_template" "cart-region_b" {
  name_prefix  = "tpl-cart-${local.rand}-${element(local.zones[1], 0)}"
  labels = {
    version = "latest"
  }
  region  = local.regions[1]
  lifecycle {
    create_before_destroy = true
  }
  machine_type         = var.nodesize
  can_ip_forward       = false
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  disk {
    source_image = data.google_compute_image.debian9.self_link
    auto_delete  = true
    boot         = true
  }
  network_interface {
    subnetwork = google_compute_subnetwork.region-b-sub.self_link
  }
  metadata = {
    startup-script      = "${file("vm-scripts/cart-startup.sh")}"
    shutdown-script     = "${file("vm-scripts/cart-shutdown.sh")}"
    version             = "latest"
    cart-host           = "http://10.128.0.4"
    payment-host        = "http://10.128.0.6"
    cart-file           = "${google_storage_bucket.static-files.name}/${google_storage_bucket_object.cart-file.output_name}"
    control-plane       = var.control-plane
    serial-port-enable  = "true"
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}
*/
/*
resource "google_compute_instance_group_manager" "cart-mig-a" {
  name               = "app-cart-${local.rand}-${element(local.zones[0], 0)}"
  zone               = element(local.zones[0], 0)
  target_size        = "1"
  named_port {
    name = "http"
    port = 80
  }  
  version {
    name              = "latest"
    instance_template = google_compute_instance_template.cart-region_a.id
  }
  depends_on = [
    google_pubsub_topic.control-plane,
  ]
}
resource "google_compute_instance_group_manager" "cart-mig-b" {
  name               = "cart-mig-b${local.rand}"
  base_instance_name = "app-cart-${local.rand}-${element(local.zones[1], 0)}"
  zone               = element(local.zones[1], 0)
  target_size        = "1"
  named_port {
    name = "http"
    port = 80
  }
  version {
    name              = "latest"
    instance_template = google_compute_instance_template.cart-region_b.id
  }
  depends_on = [
    google_pubsub_topic.control-plane,
  ]
}
*/

resource "google_compute_health_check" "delivery-hc" {
  name = "delivery-hc-${local.rand}"

  timeout_sec         = 1
  check_interval_sec  = 1
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port = 5001
  }
}

resource "google_compute_health_check" "http-hc" {
  name = "http-hc-${local.rand}"

  timeout_sec         = 1
  check_interval_sec  = 2
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port               = 80
  }
}
#Web Service
resource "google_compute_backend_service" "web-http-bs" {
  name          = "web-http-bs-${local.rand}"
  health_checks = [google_compute_health_check.http-hc.self_link]
  port_name     = "http"
  backend {
    group = google_compute_instance_group_manager.web-mig-a.instance_group
  }
  backend {
    group = google_compute_instance_group_manager.web-mig-b.instance_group
  }
}

resource "google_compute_url_map" "web-url-map" {
  name = "web-map-${local.rand}"
  default_service = google_compute_backend_service.web-http-bs.id
}

resource "google_compute_global_forwarding_rule" "web-http-fr" {
  name = "web-http-fr-${local.rand}"
  target = google_compute_target_http_proxy.web-http-proxy.self_link
  port_range = "80"
}

resource "google_compute_target_http_proxy" "web-http-proxy" {
  name = "web-http-proxy-${local.rand}"
  url_map = google_compute_url_map.web-url-map.self_link
}

#Cart Service
/*
resource "google_compute_backend_service" "cart-service-bs" {
  name          = "cart-bs-${local.rand}"
  health_checks = [google_compute_health_check.http-hc.self_link]
  port_name     = "http"
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  locality_lb_policy    = "ROUND_ROBIN"
  backend {
    group = google_compute_instance_group_manager.cart-mig-a.instance_group
  }
  backend {
    group = google_compute_instance_group_manager.cart-mig-b.instance_group
  }
}
*/
/*
resource "google_compute_url_map" "cart-url-map" {
  name        = "cart-map-${local.rand}"
  default_service = google_compute_backend_service.cart-service-bs.id
}
*/
/*
resource "google_compute_target_http_proxy" "cart-http-proxy" {
  name    = "cart-proxy-${local.rand}"
  url_map = google_compute_url_map.cart-url-map.id
}
*/
/*
resource "google_compute_global_forwarding_rule" "cart-fr" {
  name                  = "cart-http-fr-${local.rand}"
  provider              = google-beta
  target                = google_compute_target_http_proxy.cart-http-proxy.id
  port_range            = "80"
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  ip_address            = "10.128.0.4"
  network               = google_compute_network.vpc.self_link
}
*/

#Enable APIs if not done already
resource "google_project_service" "apienable" {
  for_each = toset(var.apis)
  service     = each.value
  disable_on_destroy = false
  disable_dependent_services = true
}

#Pub/Sub Configs
resource "google_pubsub_topic" "control-plane" {
  name = var.control-plane
}

#Storage Bucket for binaries
resource "google_storage_bucket" "static-files" {
  name          = local.static-bucket
  location      = "US"
  force_destroy = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "cart-file" {
  name   = "cart-service-latest.tar.gz"
  source = "binaries/cart-service-latest.tar.gz"
  bucket = google_storage_bucket.static-files.name
}

# Outputs for use in the rest of the demo
output cluster1-name {
  value = google_container_cluster.gke-cluster-a.name
}
output cluster2-name {
  value = google_container_cluster.gke-cluster-b.name
}
output project-id {
  value = var.project-id
}
output region-1 {
  value = local.regions[0]
}
output region-2 {
  value = local.regions[1]
}
output datacenter-1 {
  value = element(local.zones[0], 0)
}
output datacenter-2 {
  value = element(local.zones[1], 0)
}
output control-plane {
  value = var.control-plane
}
output gcr-location {
  value = var.gcr-location
}
output vpcnet {
  value = google_compute_network.vpc.name
}
output subnet-a {
  value = google_compute_subnetwork.region-a-sub.name
}
output subnet-b {
  value = google_compute_subnetwork.region-b-sub.name
}
output cart-file {
  value = "${google_storage_bucket.static-files.name}/${google_storage_bucket_object.cart-file.output_name}"
}