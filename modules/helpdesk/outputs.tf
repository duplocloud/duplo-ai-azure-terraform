output "release_name" {
  description = "Helm release name"
  value       = helm_release.helpdesk.name
}

output "release_status" {
  description = "Helm release status"
  value       = helm_release.helpdesk.status
}

output "rendered_values" {
  description = "Rendered Helm values document. Contains no secrets: those are passed as sensitive set values."
  value       = local.rendered_values
}

output "values_preview_keys" {
  description = "Non-sensitive preview of what is set: top-level values keys plus backend.extraEnv.<NAME> entries"
  value = concat(
    keys(yamldecode(local.rendered_values)),
    [for e in local.extra_env : "backend.extraEnv.${e.name}"],
    [for s in local.sensitive_entries : s.label if startswith(s.label, "backend.extraEnv.")]
  )
}

output "sensitive_value_labels" {
  description = "Labels (never values) of the secrets passed to Helm as sensitive set values"
  value       = [for s in local.sensitive_entries : s.label]
}
