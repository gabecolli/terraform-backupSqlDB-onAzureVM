variable "workloadType" {
  type = string
  default = "SQLDataBase"
}

variable "protectionContainers" {
  type = string
  default = "VMAppContainer;Compute;my-resource-group;my-virtual-machine"
}

variable "protectionContainerTypes" {
  type = string
  default = "VMAppContainer"
}

variable "sourceResourceIds" {
  type = string
  default = "/subscriptions/${var.subid}/resourceGroups/my-resource-group/providers/Microsoft.Compute/virtualMachines/my-virtual-machine"
}

variable "backupManagementType" {
  type = string
  default = "AzureWorkload"
}

variable "armProviderNamespace" {
  default = "Microsoft.RecoveryServices"
}

variable "vaultName" {
  default = "vault-lidlh4do"
}

variable "vaultRG" {
  default = "USAGM"
}

variable "vaultSubID" {
  type = string
}


variable "policyName" {
  default = "HourlyLogBackup"
}

variable "fabricName" {
  default = "Azure"
}

variable "subid"{
  type = string
}


variable "protectedItems" {
  default = ["sqldatabase;mssqlserver;master"]
}

variable "protectedItemTypes" {
  default = ["AzureVmWorkloadSQLDatabaseProtectedItem"]
}
