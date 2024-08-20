output "public_ip" {
  value = azurerm_public_ip.example.ip_address
}

output "load_balancer_id" {
  value = azurerm_loadbalancer.example.id
}
