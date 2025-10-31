# Terraform configuration for Besu network on Oracle Cloud
# 2 × E2.1.Micro instances (free tier)

terraform {
  required_version = ">= 1.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Get Ubuntu 22.04 image
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Virtual Cloud Network
resource "oci_core_vcn" "besu_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "besu-vcn"
  dns_label      = "besuvcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "besu_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.besu_vcn.id
  display_name   = "besu-igw"
  enabled        = true
}

# Route Table
resource "oci_core_route_table" "besu_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.besu_vcn.id
  display_name   = "besu-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.besu_igw.id
  }
}

# Security List
resource "oci_core_security_list" "besu_seclist" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.besu_vcn.id
  display_name   = "besu-seclist"

  # SSH
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Besu RPC
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 8545
      max = 8545
    }
  }

  # Besu P2P (between nodes)
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 30303
      max = 30303
    }
  }

  # Internal VCN traffic
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }

  # All outbound
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Public Subnet
resource "oci_core_subnet" "besu_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.besu_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "besu-subnet"
  dns_label         = "besusubnet"
  route_table_id    = oci_core_route_table.besu_rt.id
  security_list_ids = [oci_core_security_list.besu_seclist.id]
}

# Besu Instance 1
resource "oci_core_instance" "besu_node_1" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "besu-node-1"

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.besu_subnet.id
    assign_public_ip = true
    display_name     = "besu-node-1-vnic"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      docker_compose_version = "2.24.0"
    }))
  }
}

# Besu Instance 2
resource "oci_core_instance" "besu_node_2" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "besu-node-2"

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.besu_subnet.id
    assign_public_ip = true
    display_name     = "besu-node-2-vnic"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      docker_compose_version = "2.24.0"
    }))
  }
}

# Outputs
output "node_1_public_ip" {
  value = oci_core_instance.besu_node_1.public_ip
}

output "node_1_private_ip" {
  value = oci_core_instance.besu_node_1.private_ip
}

output "node_2_public_ip" {
  value = oci_core_instance.besu_node_2.public_ip
}

output "node_2_private_ip" {
  value = oci_core_instance.besu_node_2.private_ip
}

output "ssh_commands" {
  value = {
    node_1 = "ssh ubuntu@${oci_core_instance.besu_node_1.public_ip}"
    node_2 = "ssh ubuntu@${oci_core_instance.besu_node_2.public_ip}"
  }
}

output "rpc_endpoint" {
  value = "http://${oci_core_instance.besu_node_1.public_ip}:8545"
}
