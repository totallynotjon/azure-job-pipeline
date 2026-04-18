# Input variables — passed in at plan/apply time or via .tfvars

variable "location" {
  type        = string
  description = "Primary Azure region for all project resources"
  default     = "eastus"
}

variable "default_project_tags" {
  type        = map(string)
  description = "Default project tags to add to all resources"
  default = {
    project = "azure-job-pipeline"
  }
}

variable "alert_contact_email" {
  type        = string
  description = "Email address linked to the Azure mobile app account that receives push-notification alerts. Passed via TF_VAR_alert_contact_email env var in CI; no default so plan fails fast if unset."
  sensitive   = true
}
