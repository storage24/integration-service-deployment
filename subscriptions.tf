# N8N for integration service
resource "google_pubsub_subscription" "subscriptions" {
  for_each = toset(var.entities)
  name     = "${each.key}-event-subscription"
  topic    = google_pubsub_topic.topics[each.key].name

  push_config {
    push_endpoint = "${var.webhook_base_url}/${each.key}-event-subscription"
  }
  dead_letter_policy {
    dead_letter_topic     = "projects/${var.project_id}/topics/${google_pubsub_topic.dead_letter_topic.name}"
    max_delivery_attempts = 5
  }

  ack_deadline_seconds = 30

  message_retention_duration = "604800s" # 7 days
}
