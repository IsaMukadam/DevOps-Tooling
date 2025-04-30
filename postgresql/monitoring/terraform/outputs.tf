output "prometheus_public_ip" {
  description = "Public IP of Prometheus server"
  value       = aws_instance.prometheus.public_ip
}

output "prometheus_url" {
  description = "URL for Prometheus server"
  value       = "http://${aws_instance.prometheus.public_ip}:9090"
}

output "grafana_public_ip" {
  description = "Public IP of Grafana server"
  value       = aws_instance.grafana.public_ip
}

output "grafana_url" {
  description = "URL for Grafana dashboard"
  value       = "http://${aws_instance.grafana.public_ip}:3000"
}