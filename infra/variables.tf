variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "instance_type" {
  description = "k3d + Traefik + the app need about 2 GB of RAM, so t3.small is the smallest that works."
  type        = string
  default     = "t3.small"
}

variable "enable_nodeport" {
  description = "Open port 30080 for the NodePort service."
  type        = bool
  default     = true
}
