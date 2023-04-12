################################
#           Datadog
################################

variable "dd_api_key" {
  description = "API key to connect to DataDog"
  type        = string
  default     = ""
}

################################
#             ELK
################################

variable "elk_address" {
  description = "(Deprecated) Address to ship logs to ELK"
  type        = string
  default     = ""
}

variable "elk_username" {
  description = "(Deprecated) (Optional) Username to use to ship logs to ELK"
  type        = string
  default     = ""
}

variable "elk_password" {
  description = "(Deprecated) (Optional) Password to use to ship logs to ELK"
  type        = string
  default     = ""
  # Only compatible with Terraform >=0.14
  #sensitive   = true
}

################################
#           Snowflake
################################

variable "idp_certificate" {
  description = "(Optional) The certificate used to verify SAML assertions from the IdP being used with Snowflake. Enter this value as a one-line string with literal \n characters specifying the line breaks."
  type        = string
  default     = ""
}

variable "idp_sso_login_url" {
  description = "(Optional) The IdP SSO URL for the IdP being used with Snowflake."
  type        = string
  default     = ""
}

variable "load_balancer_certificate_arn" {
  description = "(Optional) ARN of SSL certificate that will be used for client connections to Snowflake."
  type        = string
  default     = ""
}

################################
#           Splunk
################################

variable "splunk_index" {
  description = "(Deprecated) Splunk index"
  type        = string
  default     = ""
}

variable "splunk_host" {
  description = "(Deprecated) Splunk host"
  type        = string
  default     = ""
}

variable "splunk_port" {
  description = "(Deprecated) Splunk port"
  type        = number
  default     = 0
}

variable "splunk_tls" {
  description = "(Deprecated) Splunk TLS"
  type        = bool
  default     = false
}

variable "splunk_token" {
  description = "(Deprecated) Splunk token"
  type        = string
  default     = ""
  # Only compatible with Terraform >=0.14
  #sensitive   = true
}

################################
#           Sumologic
################################

variable "sumologic_host" {
  description = "(Deprecated) Sumologic host"
  type        = string
  default     = ""
}

variable "sumologic_uri" {
  description = "(Deprecated) Sumologic uri"
  type        = string
  default     = ""
}

################################
#       HashiCorp Vault
################################

variable "hc_vault_integration_id" {
  description = "HashiCorp Vault integration ID"
  type        = string
  default     = ""
}
