# GlusterFS Lab — Clúster Distribuido en KVM

Laboratorio para desplegar un clúster de almacenamiento en Alta Disponibilidad (HA) con GlusterFS de 3 nodos sobre máquinas virtuales KVM usando Terraform y Ansible.

## Arquitectura

```text
┌─────────────────────────────────────────────────────────────┐
│                     Host (libvirt/KVM)                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ nodo-gluster│  │ nodo-gluster│  │ nodo-gluster│          │
│  │      1      │  │      2      │  │      3      │          │
│  │ .11         │  │ .12         │  │ .13         │          │
│  │             │  │             │  │             │          │
│  │  Peer /     │  │  Peer /     │  │  Peer /     │          │
│  │  Client     │  │  Client     │  │  Client     │          │
│  │  Brick x1   │  │  Brick x1   │  │  Brick x1   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         192.168.122.0/24 (Red Default KVM)                  │
└─────────────────────────────────────────────────────────────┘
```

| Nodo           | IP              | Roles                    | Almacenamiento Asignado |
|----------------|-----------------|--------------------------|-------------------------|
| nodo-gluster-1 | 192.168.122.11  | Peer, Brick, Client      | OS (20GB) + Data (5GB)  |
| nodo-gluster-2 | 192.168.122.12  | Peer, Brick, Client      | OS (20GB) + Data (5GB)  |
| nodo-gluster-3 | 192.168.122.13  | Peer, Brick, Client      | OS (20GB) + Data (5GB)  |

**Total Bricks:** 3 discos dedicados (`/dev/vdb`) formateados en XFS para formar el volumen replicado `gv0`.

## Requisitos

- KVM / libvirt instalado y activo (`qemu:///system`)
- Terraform >= 1.0
- Ansible
- Imagen Ubuntu 22.04 Jammy disponible localmente
- Red `default` configurada en libvirt
- Llave SSH generada localmente (`~/.ssh/id_rsa`)

## Estructura del repositorio

```text
glusterfs/
├── terraform/
│   ├── main.tf               # Definición de VMs, discos e inventario
│   ├── variables.tf          # Parámetros configurables (RAM, CPU, discos, IPs)
│   ├── provider.tf           # Proveedor libvirt
│   ├── terraform.tf          # Versión de providers
│   ├── inventory.tmpl        # Plantilla para generar inventario de Ansible
│   └── config/
│       ├── user_data.cfg     # Cloud-init: usuario jdelpino y llave SSH
│       ├── network_node0.cfg # Configuración estática IP .11
│       ├── network_node1.cfg # Configuración estática IP .12
│       └── network_node2.cfg # Configuración estática IP .13
├── ansible/
│   ├── inventory.ini         # Inventario generado dinámicamente
│   ├── playbook.yml          # Playbook principal
│   └── roles/
│       ├── ssh_setup/        # Configura confianza SSH mutua entre nodos
│       ├── gluster_prepare/  # Prepara discos XFS, /etc/hosts e instala Gluster
│       ├── gluster_cluster/  # Purga estados, hace peering y crea volumen gv0
│       └── gluster_client/   # Monta el volumen distribuido en /mnt/gluster_vol
├── limpia_fingerprint.sh     # Script para limpiar known_hosts del anfitrión
├── probar_glusterfs.sh       # Script de validación de HA y replicación
├── README.md                 # Esta guía de uso
└── README_EXPLICATIVO.md     # Documentación técnica y arquitectura
```

## Despliegue

### 1. Crear las máquinas virtuales

```bash
cd terraform
terraform init
terraform apply
```

Esto crea 3 VMs con:
- 3 GB RAM, 2 vCPUs
- Disco OS de 20 GB (`/dev/vda`)
- Disco de Datos de 5 GB (`/dev/vdb`)
- IPs estáticas asginadas vía Cloud-Init.

### 2. Limpiar fingerprints SSH

Necesario después de crear (o recrear) las VMs para evitar errores de llave en Ansible:

```bash
./limpia_fingerprint.sh
```

### 3. Configurar y Desplegar GlusterFS

```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

Este playbook ejecutará todos los roles:
1. Configura la malla de confianza SSH interna.
2. Prepara los discos y el archivo de hosts.
3. Conecta los Peers usando Hostnames y crea el volumen `gv0` (Replica 3).
4. Monta el volumen en `/mnt/gluster_vol` en cada nodo.

### 4. Ejecutar pruebas de validación

```bash
./probar_glusterfs.sh
```

Este script mostrará el estado de los peers, la información del volumen, los puntos de montaje, y realizará una prueba de lectura/escritura replicada en tiempo real.

## Configuración (variables Terraform)

Editar `terraform/variables.tf` para ajustar recursos:

| Variable         | Default            | Descripción                                 |
|------------------|--------------------|---------------------------------------------|
| `vm_count`       | 3                  | Cantidad de nodos en el clúster             |
| `memory`         | 3072               | RAM por nodo (MB)                           |
| `vcpu`           | 2                  | vCPUs por nodo                              |
| `os_disk_size`   | 20 GB              | Tamaño disco OS                             |
| `data_disk_size` | 5 GB               | Tamaño disco de datos GlusterFS             |
| `node_ips`       | [.11, .12, .13]    | IPs estáticas asignadas a los nodos         |

## Acceso

```bash
# SSH a cualquier nodo usando tu llave pública
ssh jdelpino@192.168.122.11
```

## Destruir el laboratorio

```bash
cd terraform
./limpia.sh
```

## Versiones

| Componente | Versión                 |
|------------|-------------------------|
| GlusterFS  | Nativo de Ubuntu 22.04  |
| Ubuntu     | 22.04 (Jammy)           |
| Terraform  | >= 1.0                  |
| libvirt    | dmacvicar/libvirt v0.7.6|
