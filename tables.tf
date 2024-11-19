resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.dataset_name
  project    = var.project_id
  location   = "EU"
}

resource "google_bigquery_table" "events_table" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = var.table_name_events
  schema = file("schemas/generic-event-schema.json")
  
  time_partitioning {
    field = "timestamp"
    type  = "DAY"
  }

  clustering = ["sourceSystem", "entity", "operation"]
}
