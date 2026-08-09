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

resource "azurerm_postgresql_flexible_server" "db_server" {
  name                = "urbancitypgserveriyeme11"
  resource_group_name = azurerm_resource_group.urban_city_rg.name
  location            = azurerm_resource_group.urban_city_rg.location
  version             = "16"

  public_network_access_enabled = true
  administrator_login           = "adminadmin"
  administrator_password        = var.pg_password
  zone                          = "1"

  storage_mb   = 32768
  storage_tier = "P30"

  sku_name    = "GP_Standard_D4s_v3"
  create_mode = "Default"

  authentication {
    password_auth_enabled = true
  }

  depends_on = [azurerm_resource_group.urban_city_rg]
}

resource "azurerm_postgresql_flexible_server_database" "db_database" {
  name      = "urban_city_db"
  server_id = azurerm_postgresql_flexible_server.db_server.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = false
  }
}

# Data factory

data "azurerm_storage_account" "storage_account_data" {
  name                = "urbancitystorageiyeme01"
  resource_group_name = azurerm_resource_group.urban_city_rg.name
}

resource "azurerm_data_factory" "data_factory_server" {
  name                = "urbancityfactoryiyeme00"
  location            = azurerm_resource_group.urban_city_rg.location
  resource_group_name = azurerm_resource_group.urban_city_rg.name
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "blobstoragels" {
  name              = "blob_storage_ls"
  data_factory_id   = azurerm_data_factory.data_factory_server.id
  connection_string = data.azurerm_storage_account.storage_account_data.primary_connection_string
}

resource "azurerm_data_factory_dataset_parquet" "urbancityds" {
  name                = "urban_city_parquet_ds"
  data_factory_id     = azurerm_data_factory.data_factory_server.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.blobstoragels.name

  compression_codec = "snappy"

  azure_blob_storage_location {
    container = "silver"
    filename  = "urban_service_requests.parquet"
  }
}
