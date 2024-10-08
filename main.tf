terraform{
    backend "azurerm"{

    }
  }
terraform{
  requireq_version">= 0.12"
}
provider "azurerm" {
  
  version = ~>2.0
  #subscription_id="5668e63a-a9e3-40bf-8047-7a07999e5edd"
  #tenant_id=""
  #client_id=""
  #client_secret=""
  features {
  } 
}
# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "rg-vmss"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "example" {
  name                = "vmss-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Subnet
resource "azurerm_subnet" "example" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "example" {
  name                = "example-public-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
}

# Load Balancer
resource "azurerm_loadbalancer" "example" {
  name                = "example-lb"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "Basic"
  
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.example.id
  }
  
  backend_address_pool {
    name = "backend-pool"
  }
  
  probe {
    name                = "healthprobe"
    port                = 80
    protocol            = "Tcp"
    interval_in_seconds = 15
    number_of_probes    = 2
  }
  
  loadbalancing_rule {
    name                           = "http-rule"
    protocol                       = "Tcp"
    load_distribution              = "Default"
    frontend_ip_configuration_name = "frontend-ip"
    backend_address_pool_id        = azurerm_loadbalancer.example.backend_address_pool[0].id
    probe_id                       = azurerm_loadbalancer.example.probe[0].id
    frontend_port                  = 80
    backend_port                   = 80
  }
}

# Virtual Machine Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "example" {
  name                = "example-vmss"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard_DS1_v2"
  instances           = 2

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name_prefix = "vmss"
    admin_username       = var.username
    admin_password       = var.password
    custom_data          = filebase64("${path.module}/cloud-init.yaml")
  }

  network_interface {
    name    = "example-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      subnet_id = azurerm_subnet.example.id
      primary   = true
    }
  }

  storage_profile {
    image_reference {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
      version   = "latest"
    }

    os_disk {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
      disk_size_gb         = 10
    }
  }
}

# Cloud-init script
resource "local_file" "cloud_init" {
  content  = <<-EOF
              #cloud-config
              package_update: true
              packages:
                - nginx
              runcmd:
                - systemctl start nginx
                - systemctl enable nginx
              EOF
  filename = "${path.module}/cloud-init.yaml"
}
