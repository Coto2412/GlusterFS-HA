# Definición de la imagen base
resource "libvirt_volume" "ubuntu2204" {
  name   = "ubuntu2204.qcow2"
  pool   = "default"
  source = pathexpand(var.base_image_path)
  format = "qcow2"
}

# Volúmenes de SO para los nodos
resource "libvirt_volume" "os_disk" {
  count          = var.vm_count
  name           = "nodo-gluster-os-${count.index}.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu2204.id
  size           = var.os_disk_size
}

# Volúmenes de datos para los Bricks de GlusterFS
resource "libvirt_volume" "data_disk" {
  count  = var.vm_count
  name   = "nodo-gluster-data-${count.index}.qcow2"
  pool   = "default"
  size   = var.data_disk_size
  format = "qcow2"
}

# Cloud-Init para configurar usuario ubuntu y la llave SSH
data "template_file" "user_data" {
  template = file("${path.module}/config/user_data.cfg")
  vars = {
    ssh_key = file(pathexpand(var.ssh_pub_key_path))
  }
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  count          = var.vm_count
  name           = "cloudinit-node-${count.index}.iso"
  user_data      = data.template_file.user_data.rendered
  network_config = file("${path.module}/config/network_node${count.index}.cfg")
  pool           = "default"
}

# Definición de las Máquinas Virtuales
resource "libvirt_domain" "gluster_node" {
  count  = var.vm_count
  name   = "nodo-gluster-${count.index + 1}"
  memory = var.memory
  vcpu   = var.vcpu

  cloudinit = libvirt_cloudinit_disk.cloudinit[count.index].id

  network_interface {
    network_name   = "default"
    addresses      = [var.node_ips[count.index]]
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # Disco del Sistema Operativo
  disk {
    volume_id = libvirt_volume.os_disk[count.index].id
  }

  # Disco de Datos para GlusterFS
  disk {
    volume_id = libvirt_volume.data_disk[count.index].id
  }
}

# Generar archivo de inventario para Ansible dinámicamente usando las IPs estáticas
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tmpl", {
    ips = var.node_ips
  })
  filename = "${path.module}/../ansible/inventory.ini"
}

output "node_ips" {
  value = var.node_ips
}
