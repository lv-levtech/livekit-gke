output "redis_host" {
  description = "The IP address of the Redis instance"
  value       = google_redis_instance.redis.host
}

output "redis_port" {
  description = "The port of the Redis instance"
  value       = google_redis_instance.redis.port
}

output "redis_address" {
  description = "The full address of the Redis instance (host:port)"
  value       = "${google_redis_instance.redis.host}:${google_redis_instance.redis.port}"
}

output "redis_auth_string" {
  description = "The AUTH string for the Redis instance"
  value       = google_redis_instance.redis.auth_string
  sensitive   = true
}

output "redis_instance_name" {
  description = "The name of the Redis instance"
  value       = google_redis_instance.redis.name
}

output "redis_current_location_id" {
  description = "The current zone where the Redis endpoint is placed"
  value       = google_redis_instance.redis.current_location_id
}
