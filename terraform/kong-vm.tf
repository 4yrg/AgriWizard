# =============================================================================
# AgriWizard - Kong Gateway VM
# =============================================================================
# Cheap B1s VM with Docker + Kong gateway
# =============================================================================

variable "vm_password" {
  description = "Admin password for VM"
  type        = string
  sensitive   = true
}

variable "vm_username" {
  description = "Admin username for VM"
  type        = string
  default     = "kongadmin"
}

variable "vm_size" {
  description = "VM size for Kong gateway"
  type        = string
  default     = "Standard_D2s_v3"
}

# Network Security Group for Kong VM
resource "azurerm_network_security_group" "kong_vm" {
  name                = "${var.project_name}-kong-vm-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "KongProxy"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "KongAdmin"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8001"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Public IP for Kong VM
resource "azurerm_public_ip" "kong_vm" {
  name                = "${var.project_name}-kong-vm-ip"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]

  tags = local.common_tags
}

# Subnet for Kong VM
resource "azurerm_subnet" "kong_vm" {
  name                 = "${var.project_name}-kong-vm-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.100.0/24"]
}

# Virtual Network Interface
resource "azurerm_network_interface" "kong_vm" {
  name                = "${var.project_name}-kong-vm-nic"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.kong_vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.kong_vm.id
  }

  tags = local.common_tags
}

# Network Interface Security Group Association
resource "azurerm_network_interface_security_group_association" "kong_vm" {
  network_interface_id      = azurerm_network_interface.kong_vm.id
  network_security_group_id = azurerm_network_security_group.kong_vm.id
}

# Cloud-init script for Docker + Kong (embedded config to avoid GitHub clone issues)
data "cloudinit_config" "kong_vm" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - curl
        - docker.io
        - docker-compose
      runcmd:
        - systemctl enable docker
        - systemctl start docker
      password: ${var.vm_password}
      chpasswd:
        expire: false
      EOF
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "kongsetup.sh"
    content      = <<-EOF
      #!/bin/bash
      set -e
      echo "Waiting for Docker..."
      until docker info > /dev/null 2>&1; do sleep 1; done
      echo "Docker ready, deploying Kong..."

      # Create directories
      mkdir -p /opt/agriwizard/kong
      cd /opt/agriwizard/kong

      # Create kong.yml
      cat > /opt/agriwizard/kong/kong.yml << 'KONFEOF'
_format_version: "3.0"
_transform: true
services:
  - name: iam-service
    url: https://prod-iam-service.proudisland-ab3ad6ed.centralindia.azurecontainerapps.io
    routes:
      - name: iam-route
        paths: ["/api/v1/iam"]
  - name: hardware-service
    url: https://prod-hardware-service.proudisland-ab3ad6ed.centralindia.azurecontainerapps.io
    routes:
      - name: hardware-route
        paths: ["/api/v1/hardware"]
  - name: analytics-service
    url: https://prod-analytics-service.proudisland-ab3ad6ed.centralindia.azurecontainerapps.io
    routes:
      - name: analytics-route
        paths: ["/api/v1/analytics"]
  - name: weather-service
    url: https://prod-weather-service.proudisland-ab3ad6ed.centralindia.azurecontainerapps.io
    routes:
      - name: weather-route
        paths: ["/api/v1/weather"]
  - name: notification-service
    url: https://prod-notification-service.proudisland-ab3ad6ed.centralindia.azurecontainerapps.io
    routes:
      - name: notification-route
        paths: ["/api/v1/notifications"]
plugins:
  - name: cors
    config:
      origins: ["*"]
      methods: ["GET","POST","PUT","DELETE","PATCH","OPTIONS"]
      headers: ["Authorization","Content-Type"]
      credentials: true
      max_age: 3600
  - name: rate-limiting
    config:
      minute: 100
      hour: 1000
      policy: local
      fault_tolerant: true
KONFEOF

      # Create docker-compose.yml
      cat > /opt/agriwizard/kong/docker-compose.yml << 'DCEOF'
version: '3.9'
services:
  kong:
    image: kong:3.4
    container_name: kong
    ports:
      - "8000:8000"
      - "8443:8443"
      - "8001:8001"
    environment:
      KONG_DECLARATIVE_CONFIG: /usr/local/kong/declarative/kong.yml
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    volumes:
      - ./kong.yml:/usr/local/kong/declarative/kong.yml:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/status"]
      interval: 10s
      timeout: 5s
      retries: 5
DCEOF

      echo "Starting Kong..."
      docker-compose -f /opt/agriwizard/kong/docker-compose.yml up -d
      echo "Kong Gateway started at http://$(hostname -I | awk '{print $1}'):8000"
      echo "Kong Admin at http://$(hostname -I | awk '{print $1}'):8001"
      EOF
  }
}

# Kong VM
resource "azurerm_linux_virtual_machine" "kong_vm" {
  name                = "${var.project_name}-kong-vm"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.vm_username
  network_interface_ids = [azurerm_network_interface.kong_vm.id]

  admin_password = var.vm_password
  disable_password_authentication = false

  custom_data = data.cloudinit_config.kong_vm.rendered

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  tags = local.common_tags
}

# Outputs
output "kong_vm_public_ip" {
  description = "Public IP address of Kong VM"
  value       = azurerm_public_ip.kong_vm.ip_address
}

output "kong_vm_fqdn" {
  description = "FQDN of Kong VM"
  value       = azurerm_public_ip.kong_vm.fqdn
}

output "kong_gateway_url" {
  description = "Kong Gateway HTTP URL"
  value       = "http://${azurerm_public_ip.kong_vm.ip_address}:8000"
}

output "kong_admin_url" {
  description = "Kong Admin API URL"
  value       = "http://${azurerm_public_ip.kong_vm.ip_address}:8001"
}