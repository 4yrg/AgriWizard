environment = "prod"
location    = "centralindia"
acr_name    = "agriwizard"

postgresql_admin_password = "ProdSecure@123"
postgresql_sku_name     = "Standard_B1ms"
jwt_secret = "prod-jwt-secret-minimum-32-characters-long"

container_apps_env_name = "agriwizard-env"
cpu_core    = 0.25
memory_size = 0.5
min_replicas = 0
max_replicas = 2

# VM Configuration
vm_username = "kongadmin"
vm_password = "KongAdmin2026!"
vm_size     = "Standard_D2s_v3"
