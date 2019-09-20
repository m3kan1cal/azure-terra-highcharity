# Define the common tags for all resources.
variable "tags" {
  description = "A map of the tags to use for the resources that are deployed."
  type        = "map"

  default = {
    name                  = "HighCharity Infra"
    tier                  = "Infrastructure"
    application           = "HighCharity"
    applicationversion    = "1.0.0"
    environment           = "Sandbox"
    infrastructureversion = "1.0.0"
    projectcostcenter     = "0570025003"
    operatingcostcenter   = "0570025003"
    owner                 = "fireteamosiris@somedomain.com"
    securitycontact       = "fireteamosiris@somedomain.com"
    confidentiality       = "PII/PHI"
    compliance            = "HIPAA"
  }
}

# Define prefix for consistent resource naming.
variable "resource_prefix" {
  type        = "string"
  default     = "zeushighcharity"
  description = "Service prefix to use for naming of resources."
}

# Define Azure region for resource placement.
variable "location" {
  type        = "string"
  default     = "westus"
  description = "Azure region for deployment of resources."
}

# Define username for use on the hosts.
variable "username" {
  type        = "string"
  default     = "fireteamosiris"
  description = "Username to build and use on the VM hosts."
}

# Create a resource group if it doesn’t exist.
resource "azurerm_resource_group" "resource_group" {
  name     = "${var.resource_prefix}-rg"
  location = "${var.location}"

  tags = "${var.tags}"
}

# Create virtual network with public and private subnets.
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resource_group.name}"

  tags = "${var.tags}"
}

# Create public subnet for hosting bastion/public VMs.
resource "azurerm_subnet" "public_subnet" {
  name                      = "${var.resource_prefix}-pblc-sn001"
  resource_group_name       = "${azurerm_resource_group.resource_group.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "10.0.1.0/24"
  network_security_group_id = "${azurerm_network_security_group.public_nsg.id}"

  # List of Service endpoints to associate with the subnet.
  service_endpoints         = [
    "Microsoft.ServiceBus",
    "Microsoft.ContainerRegistry"
  ]
}

# Create network security group and SSH rule for public subnet.
resource "azurerm_network_security_group" "public_nsg" {
  name                = "${var.resource_prefix}-pblc-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resource_group.name}"

  # Allow SSH traffic in from Internet to public subnet.
  security_rule {
    name                       = "allow-ssh-all"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = "${var.tags}"
}

# Associate network security group with public subnet.
resource "azurerm_subnet_network_security_group_association" "public_subnet_assoc" {
  subnet_id                 = "${azurerm_subnet.public_subnet.id}"
  network_security_group_id = "${azurerm_network_security_group.public_nsg.id}"
}

# Create a public IP address for bastion host VM in public subnet.
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.resource_prefix}-ip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resource_group.name}"
  allocation_method   = "Dynamic"

  tags = "${var.tags}"
}

# Create network interface for bastion host VM in public subnet.
resource "azurerm_network_interface" "bastion_nic" {
  name                      = "${var.resource_prefix}-bstn-nic"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.resource_group.name}"
  network_security_group_id = "${azurerm_network_security_group.public_nsg.id}"

  ip_configuration {
    name                          = "${var.resource_prefix}-bstn-nic-cfg"
    subnet_id                     = "${azurerm_subnet.public_subnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.public_ip.id}"
  }

  tags = "${var.tags}"
}

# Create private subnet for hosting worker VMs.
resource "azurerm_subnet" "private_subnet" {
  name                      = "${var.resource_prefix}-prvt-sn001"
  resource_group_name       = "${azurerm_resource_group.resource_group.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "10.0.2.0/24"
  network_security_group_id = "${azurerm_network_security_group.private_nsg.id}"

  # List of Service endpoints to associate with the subnet.
  service_endpoints         = [
    "Microsoft.Sql",
    "Microsoft.ServiceBus"
  ]
}

# Create network security group and SSH rule for private subnet.
resource "azurerm_network_security_group" "private_nsg" {
  name                = "${var.resource_prefix}-prvt-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resource_group.name}"

  # Allow SSH traffic in from public subnet to private subnet.
  security_rule {
    name                       = "allow-ssh-public-subnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Block all outbound traffic from private subnet to Internet.
  security_rule {
    name                       = "deny-internet-all"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = "${var.tags}"
}

# Associate network security group with private subnet.
resource "azurerm_subnet_network_security_group_association" "private_subnet_assoc" {
  subnet_id                 = "${azurerm_subnet.private_subnet.id}"
  network_security_group_id = "${azurerm_network_security_group.private_nsg.id}"
}

# Create network interface for worker host VM in private subnet.
resource "azurerm_network_interface" "worker_nic" {
  name                      = "${var.resource_prefix}-wrkr-nic"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.resource_group.name}"
  network_security_group_id = "${azurerm_network_security_group.private_nsg.id}"

  ip_configuration {
    name                          = "${var.resource_prefix}-wrkr-nic-cfg"
    subnet_id                     = "${azurerm_subnet.private_subnet.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags = "${var.tags}"
}

# Generate random text for a unique storage account name.
resource "random_id" "random_id" {
  keepers = {

    # Generate a new ID only when a new resource group is defined.
    resource_group = "${azurerm_resource_group.resource_group.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics.
resource "azurerm_storage_account" "storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  resource_group_name      = "${azurerm_resource_group.resource_group.name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = "${var.tags}"
}

# Create bastion host VM.
resource "azurerm_virtual_machine" "bastion_vm" {
  name                  = "${var.resource_prefix}-bstn-vm001"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.resource_group.name}"
  network_interface_ids = ["${azurerm_network_interface.bastion_nic.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "${var.resource_prefix}-bstn-dsk001"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.resource_prefix}-bstn-vm001"
    admin_username = "${var.username}"
    custom_data    = "${file("${path.module}/files/nginx.yml")}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    # Bastion host VM public key.
    ssh_keys {
      path     = "/home/${var.username}/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfDfs/Q+wMLKKxkfKK2TbsJrSvnOV3G/dNoTPcQyq96gEpP7wOoy4++1hkeYhKZEkE+Ni6A6KId8KzTQlbtgnXMyoKwbNDFFJMzAIyZdFHeuRBLxenWK01SKWLL6N8KQ0aFz0d8hUXMhJODCyRZdZHT4u/2v1CI4g1br503Aqo3c2O+uBPhUIM0xJZAG8d+F83QlQZHr07XjdIAKx5KOgoLX6XB/OWZ+YEIlITatYX5mHOcujv1CwcytVeMfDg8x5VHhHTDipjKX/ikROqq0iAng1voTtuz4CDXMckUuaI7k9KTGnhumBzcTYArFMUZWFqJZax8m5y2oI2VHMvGMjzk680Y5VGIbboRi2PbrAbmWTn7SpTJF5One6Y8PBXOLIju7IO/rUAPstwXm/gEXswFSsU6pI/ol/s4JdD2Xx3n9o+ObVafAQwQl9scabpdXJkfjkLrqvZOCR1//FjgktVXNYI+XbAkyBA3pR/jWa2aWYuLYHArQp/NG9aCDGdZjGdlrkSNm/y29rzVN6H7cXSLYG7te3NEAJehARLLVqon0mdfpYGluhYxBwC8pxJHi9sew0n0gVM4kjIjvrapFVBfX9BzQKrZMkXLi6bt2rx6ktgWUSLcmak7Du5JzQZaJnTkEpHxK52NvqIQo0Nziq7gWeBm6KMxp1B5fuVRNZNPw=="
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.storage_account.primary_blob_endpoint}"
  }

  tags = "${var.tags}"
}

# Create worker host VM.
resource "azurerm_virtual_machine" "worker_vm" {
  name                  = "${var.resource_prefix}-wrkr-vm001"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.resource_group.name}"
  network_interface_ids = ["${azurerm_network_interface.worker_nic.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "${var.resource_prefix}-wrkr-dsk001"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.resource_prefix}-wrkr-vm001"
    admin_username = "${var.username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    # Worker host VM public key.
    ssh_keys {
      path     = "/home/${var.username}/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCyhfsGKt4FF5bIxdIDkBANxivJ9BI/H2UQEUPKYjZh0GDCWyYEPBKYhIGD4OvibdrA/4fFi7tGs3QEvMBju8hZ86iWxpU1cy3JXw6XxLgrhufYpWw2XG6hHfbcJ4wpFwQ1GvwnI52K+BErCcTzqa6JBQGVf1O57lWHXTsGa9WEMwKCza+8JZdckfXUbztO1jYQ+dEi3Uh0ANyGEC+qHRoKcmJKxMDBZMt4lIhkFsApPeg7w1/CdFZCI42+V/xQYB3yn7pgae9NTXgVE40h0pMEkgaDqonc60DJthNb5l81PmshOjttEkHh4TTA4jv2fyDammt5Krl+9k57f3iKTh7VCGPVc/UkMJ1L+nDfOFP5nEuyh+vtuNCZs0iBdumf6MrShN+KyoodDhyd3w3Nx/e7M1iyLLYjNRT+gaHG1xXuYrSE0NM41lCgynDttML2rrPiLdm/l7jEkFJNSXXd57IUaHNV44L5xaRtyVJv+j79JXM2Ds5p2RN0vS8mtqh3g6UOGHPAWC5IKAsU8xXR+N3jvajwUoV5VQGOxRqpkN+litJGQkiFgjd/aqd0jLCd5MGRbk63TL/YssHlR5vya5Fo9kFGPocYnyiqB/VSMPH6mZDorfaWlV3mdR3ocK01DdcmiKPETYpmNRvmT/GIEjlpRT+hlE11prd9rA9Kmw6E7w=="
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.storage_account.primary_blob_endpoint}"
  }

  tags = "${var.tags}"
}

# IDs of virtual networks provisioned.
output "vm_ids" {
  description = "IDs of virtual networks provisioned."
  value       = "${concat(azurerm_virtual_machine.bastion_vm.*.id, azurerm_virtual_machine.worker_vm.*.id)}"
}

# IDs of subnets provisioned.
output "network_subnet_ids" {
  description = "IDs of subnets provisioned."
  value       = "${concat(azurerm_subnet.public_subnet.*.id, azurerm_subnet.private_subnet.*.id)}"
}

# Prefixes of virtual networks provisioned.
output "network_subnet_prefixes" {
  description = "Prefixes of virtual networks provisioned."
  value       = "${concat(azurerm_subnet.public_subnet.*.address_prefix, azurerm_subnet.private_subnet.*.address_prefix)}"
}

# IDs of network security groups provisioned.
output "network_security_group_ids" {
  description = "IDs of network security groups provisioned."
  value       = "${concat(azurerm_network_security_group.public_nsg.*.id, azurerm_network_security_group.private_nsg.*.id)}"
}

# IDs of network interfaces provisioned.
output "network_interface_ids" {
  description = "IDs of network interfaces provisioned."
  value       = "${concat(azurerm_network_interface.bastion_nic.*.id, azurerm_network_interface.worker_nic.*.id)}"
}

# IDs of public IP addresses provisioned.
output "public_ip_ids" {
  description = "IDs of public IP addresses provisioned."
  value       = "${azurerm_public_ip.public_ip.*.id}"
}

# IP addresses of public IP addresses provisioned.
output "public_ip_addresses" {
  description = "IP addresses of public IP addresses provisioned."
  value       = "${azurerm_public_ip.public_ip.*.ip_address}"
}

# FQDNs of public IP addresses provisioned.
output "public_ip_dns_names" {
  description = "FQDNs of public IP addresses provisioned."
  value       = "${azurerm_public_ip.public_ip.*.fqdn}"
}

# IP addresses of private IP addresses provisioned.
output "private_ip_addresses" {
  description = "IP addresses of private IP addresses provisioned."
  value       = "${concat(azurerm_network_interface.bastion_nic.*.private_ip_address, azurerm_network_interface.worker_nic.*.private_ip_address)}"
}
