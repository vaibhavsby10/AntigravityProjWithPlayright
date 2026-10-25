output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "The public IPv4 address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "http_url" {
  description = "HTTP URL to access the site"
  value       = "http://${aws_instance.web.public_ip}"
}

output "https_url" {
  description = "HTTPS URL to access the site (using self-signed certificate)"
  value       = "https://${aws_instance.web.public_ip}"
}
