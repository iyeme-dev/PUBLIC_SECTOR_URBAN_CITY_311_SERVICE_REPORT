terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = file("credentials.txt")
}

resource "azurerm_resource_group" "urban_city_rg" {
  name     = "urban-city-rg"
  location = "North Europe"
}

resource "azurerm_storage_account" "urban_city_storage" {
  name                     = "urbancitystorageiyeme01"
  resource_group_name      = azurerm_resource_group.urban_city_rg.name
  location                 = azurerm_resource_group.urban_city_rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_name  = azurerm_storage_account.urban_city_storage.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.urban_city_storage]
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_name  = azurerm_storage_account.urban_city_storage.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.urban_city_storage]
}

