# Input variables — passed in at plan/apply time or via .tfvars

variable "location" {
  type        = string
  description = "Primary Azure region for all project resources"
  default     = "eastus"
}
