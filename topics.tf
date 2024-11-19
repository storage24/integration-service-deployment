resource "google_pubsub_topic" "topics" {
  for_each = toset(var.entities)
  name     = "${each.key}-event-topic"
  labels = {
    environment = var.environment
    service     = "${each.key}-service"
  }
  message_retention_duration = "604800s" # 7 days
}

# Dead Letter - Collects undelivered messages
resource "google_pubsub_topic" "dead_letter_topic" {
  name = "events-dead-letter"
}
