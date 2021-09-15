variable "nameprefix" {
  type = string
}
variable "project-id" {
    type = string
}
variable "nodesize" {
  type = string
}
variable "deploy_test_vms" {
  type = bool
}
variable "vm_spec" {
  type = string
}
variable "web-docker-image" {
  type = string
}
variable "zoneregions" {
  type    = any
}
variable "subnets" {
  type    = list(string)
}
variable "podranges" {
  type    = list(string)
}
variable "svcranges" {
  type    = list(string)
}
variable "masterranges" {
  type    = list(string)
}
variable "control-plane" {
  type    = string
}
variable "gcr-location" {
  type    = string
}
variable "payment-svc-img" {
  type    = string
}
variable "apis" {
  type = list(string)
}
