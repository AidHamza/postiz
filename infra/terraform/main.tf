# Postiz-owned Cloudflare resources. Only the social.appsdoc.com record.
# It was created manually (proxied A record -> Frankfurt) and no other state
# owns it. Adoption is gated on social_record_id so a token without DNS read
# access still produces an empty, safe plan.

locals {
  adopt_record = var.social_record_id != ""
}

import {
  for_each = local.adopt_record ? toset([var.social_record_id]) : toset([])
  to       = cloudflare_dns_record.social[0]
  id       = "${var.zone_id}/${each.value}"
}

resource "cloudflare_dns_record" "social" {
  count   = local.adopt_record ? 1 : 0
  zone_id = var.zone_id
  name    = var.hostname
  type    = "A"
  content = var.origin_ipv4
  proxied = true
  ttl     = 1
  comment = "AppsDoc Postiz (managed by AppsDoc/postiz infra/terraform)"

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.origin_ipv4))
      error_message = "Set origin_ipv4 to the record's current target before adopting it."
    }
  }
}
