terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = file("credentials.txt")
}
provider "azapi" {}

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

# Allow Azure services to connect to PostgreSQL

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.db_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
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

# Blob Storage Linked Service
resource "azurerm_data_factory_linked_service_azure_blob_storage" "blobstoragels" {
  name              = "blob_storage_ls"
  data_factory_id   = azurerm_data_factory.data_factory_server.id
  connection_string = data.azurerm_storage_account.storage_account_data.primary_connection_string
}

# Parquet Dataset
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

# PostgreSQL V2 Linked Service

resource "azapi_resource" "postgresql_linked_service" {
  type      = "Microsoft.DataFactory/factories/linkedservices@2018-06-01"
  name      = "postgresql_ls"
  parent_id = azurerm_data_factory.data_factory_server.id

  body = {
    properties = {
      type    = "AzurePostgreSql"
      version = "2.0"

      typeProperties = {
        server   = azurerm_postgresql_flexible_server.db_server.fqdn
        port     = 5432
        database = azurerm_postgresql_flexible_server_database.db_database.name
        sslMode  = 3
        username = "adminadmin"

        password = {
          type  = "SecureString"
          value = var.pg_password
        }
      }
    }
  }

  schema_validation_enabled = false
}

# PostgreSQL V2 Dataset

resource "azapi_resource" "postgresql_dataset" {
  type      = "Microsoft.DataFactory/factories/datasets@2018-06-01"
  name      = "urban_city_postgresql_ds"
  parent_id = azurerm_data_factory.data_factory_server.id

  body = {
    properties = {
      linkedServiceName = {
        referenceName = azapi_resource.postgresql_linked_service.name
        type          = "LinkedServiceReference"
      }

      type = "AzurePostgreSqlTable"

      typeProperties = {}
    }
  }

  schema_validation_enabled = false

  depends_on = [
    azapi_resource.postgresql_linked_service
  ]
}

# PostgreSQL Linked Service
# resource "azurerm_data_factory_linked_service_postgresql" "postgresql_ls" {
#   name            = "postgresql_ls"
#   data_factory_id = azurerm_data_factory.data_factory_server.id

#   connection_string = "Host=${azurerm_postgresql_flexible_server.db_server.fqdn};Port=5432;Database=${azurerm_postgresql_flexible_server_database.db_database.name};Username=adminadmin;Password=${var.pg_password};SSL Mode=Require"
# }

# PostgreSQL Dataset
# resource "azurerm_data_factory_dataset_postgresql" "postgresql_dataset" {
#   name                = "urban_city_postgresql_ds"
#   data_factory_id     = azurerm_data_factory.data_factory_server.id
#   linked_service_name = azurerm_data_factory_linked_service_postgresql.postgresql_ls.name
# }

