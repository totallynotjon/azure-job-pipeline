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

variable "sql_location" {
  type        = string
  description = "Region for SQL server. Separate from var.location to work around regional provisioning restrictions on new subscriptions."
  default     = "centralus"
}

variable "sql_admin_login" {
  type        = string
  description = "Entra UPN set as SQL server admin. Passed via TF_VAR_sql_admin_login (GH secret SQL_ADMIN_LOGIN)."
  sensitive   = true
}

variable "sql_admin_object_id" {
  type        = string
  description = "Entra object ID for the SQL server admin principal. Passed via TF_VAR_sql_admin_object_id (GH secret SQL_ADMIN_OBJECT_ID)."
  sensitive   = true
}

variable "adzuna_searches" {
  type        = string
  description = "JSON-encoded array of Adzuna search configs. Contains location PII, so it is kept out of source. Passed via TF_VAR_adzuna_searches (GH secret ADZUNA_SEARCHES). Example: [{\"id\":\"remote\",\"what\":\"devops engineer remote\",\"where\":\"\",\"maxDaysOld\":7}]"
  sensitive   = true
}
