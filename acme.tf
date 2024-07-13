### ACME related variables
variable "acme_email" {}
variable "acme_common_name" {}

### DNS related variables
variable "az_dns_zone" {}

### DNS zone
resource "azurerm_dns_zone" "az-dns" {
    name = "${var.az_dns_zone}"
    resource_group_name = "${var.az_resource_group}"
}

resource "azurerm_dns_txt_record" "acme-txt" {
    name = "acme-challenge"
    zone_name = "${azurerm_dns_zone.az-dns.name}"
    resource_group_name = "${azurerm_dns_zone.az-dns.resource_group_name}"
    ttl = 300
    record {
        value = "${acme_certificate.web-n-cert.certificate_pem}"
    }
    depends_on = [
        azurerm_dns_zone.az-dns,
        acme_certificate.web-n-cert
    ]
}

### generating ACME cert
resource "tls_private_key" "web-n-ed25519" {
  algorithm = "ED25519"
}
resource "tls_private_key" "web-n-rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "acme_registration" "acme-reg" {
    account_key_pem = tls_private_key.web-n-ed25519.private_key_pem
    email_address = "${var.acme_email}"
}

resource "random_password" "pfx-passwd" {
    length = 30
    special = true
} #todo: not necessary with cert_request CRT block

resource "tls_cert_request" "web-n-crt" {
    #key_algorithm = "ED25519"
    private_key_pem = "${tls_private_key.web-n-ed25519.private_key_pem}"
    dns_names = ["${var.acme_common_name}"]
    subject {
        common_name = "${var.acme_common_name}"
    }
}

resource "acme_certificate" "web-n-cert" {
    account_key_pem = "${acme_registration.acme-reg.account_key_pem}"
    #common_name = var.acme_common_name
    certificate_request_pem = "${tls_cert_request.web-n-crt.cert_request_pem}"

    dns_challenge {
        provider = "azuredns"

    config = {
        AZURE_CLIENT_CERTIFICATE_PATH = "${tls_private_key.web-n-rsa.private_key_pem}"
        AZURE_CLIENT_ID = "${var.az_client_id}"
        AZURE_TENANT_ID = "${var.az_tenant_id}"
        AZURE_SUBSCRIPTION_ID = "${var.az_subscription_id}"
        AZURE_RESOURCE_GROUP = "${var.az_resource_group}"
        AZURE_CLIENT_SECRET = "${var.az_client_secret}"
        #AZURE_AUTH_METHOD = ""
        AZURE_TTL = 300
        AZURE_DNS_ZONE = "${azurerm_dns_zone.az-dns.name}"
        }
    }
    depends_on = [ azurerm_dns_zone.az-dns ]
}