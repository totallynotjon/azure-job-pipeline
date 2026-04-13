# Input variables — passed in at plan/apply time or via .tfvars

variable "location" {
  type        = string
  description = "Primary Azure region for all project resources"
  default     = "eastus"
}

variable "default_project_tags" {
  type        = map(string)
  description = "Default project tags to add to all resources"
  default     = {
    project = "azure-job-pipeline"
  }
}
