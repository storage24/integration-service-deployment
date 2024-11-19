# Output the external IP address of the instance
output "n8n_instance_external_ip" {
  value       = google_compute_address.n8n_static_ip.address
  description = "The external IP address of the n8n server instance"
}

output "pubsub_topics" {
  value = google_pubsub_topic.topics
}
