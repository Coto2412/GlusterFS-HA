variable "vm_count" {
  description = "Número de nodos GlusterFS"
  type        = number
  default     = 3
}

variable "node_ips" {
  description = "IPs estáticas para los nodos"
  type        = list(string)
  default     = ["192.168.122.11", "192.168.122.12", "192.168.122.13"]
}

variable "memory" {
  description = "Memoria RAM por nodo en MB"
  type        = string
  default     = "3072"
}

variable "vcpu" {
  description = "Cantidad de vCPUs por nodo"
  type        = number
  default     = 2
}

variable "os_disk_size" {
  description = "Tamaño del disco de Sistema Operativo en bytes (20GB)"
  type        = number
  default     = 21474836480
}

variable "data_disk_size" {
  description = "Tamaño del disco de datos de GlusterFS en bytes (5GB)"
  type        = number
  default     = 5368709120
}

variable "base_image_path" {
  description = "Ruta de la imagen base de Ubuntu"
  type        = string
  default     = "~/vmstore/images/jammy-server-cloudimg-amd64.img"
}

variable "ssh_pub_key_path" {
  description = "Ruta a la llave pública SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
