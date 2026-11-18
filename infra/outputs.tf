output "instance_id" {
  value = aws_instance.k3d.id
}

output "public_ip" {
  value = aws_instance.k3d.public_ip
}

output "app_url" {
  value = "http://${aws_instance.k3d.public_ip}/"
}

output "nodeport_url" {
  value = var.enable_nodeport ? "http://${aws_instance.k3d.public_ip}:30080/" : "closed"
}

output "session_manager_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/systems-manager/session-manager/${aws_instance.k3d.id}?region=${var.aws_region}"
}
