variable "project_name" {
  description = "Name of project"
}

variable "vmcount" {
  description = "Number of objects to be created"
}

variable "location" {
  description = "Location of the Resource Group"
}

variable "rg-name" {
  description = "Resource Group name"
}

variable "virtual_machine_ids" {
  description = "Virtual Machine ID's to install the Monitoring Agent"
}
