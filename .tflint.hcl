plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# azurerm_resource_missing_tags fires on every resource because the project
# passes tags via a variable map rather than hardcoded key/value pairs.
# Checkov covers tag presence as part of its policy set.
rule "azurerm_resource_missing_tags" {
  enabled = false
}
