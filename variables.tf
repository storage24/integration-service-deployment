variable "environment" {
  default = "production"
}
variable "project_id" {
  type    = string
  default = "storage24-integration-services"
}
variable "region" {
  type    = string
  default = "europe-west3"
}
variable "zone" {
  type    = string
  default = "europe-west3-c"
}
# Add more entities as needed <sourceSystem>-<entity>
variable "entities" {
  type    = list(string)
  default = ["hubspot-product", "hubspot-park", "hubspot-owner", "hubspot-task", "hubspot-call", "hubspot-email", "hubspot-user"] 
}
variable "webhook_base_url" {
  type    = string
  default = "https://n8n.storage24.com/webhook"
}

variable "dataset_name" {
  type = string
  default = "integration_service"
}

variable "table_name_events" {
  type = string
  default = "raw_events"
}
