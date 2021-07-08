resource "tls_private_key" "dev" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

# Create the root certificate
resource "tls_self_signed_cert" "ca" {
  key_algorithm   = tls_private_key.dev.algorithm
  private_key_pem = tls_private_key.dev.private_key_pem

  # Certificate expires after 1 year
  validity_period_hours = 8766

  # Generate a new certificate if Terraform is run within three
  # hours of the certificate's expiration time.
  early_renewal_hours = 200

  # Allow to be used as a CA
  is_ca_certificate = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
    "cert_signing"
  ]

  dns_names = [azurerm_public_ip.vpn_ip.domain_name_label]

  subject {
    common_name  = "CAOpenVPN"
    organization = var.cert_organisation
  }
}

resource "local_file" "ca_pem" {
  filename = ".openvpn/ca_cert.pem"
  content  = tls_self_signed_cert.ca.cert_pem
}

resource "null_resource" "cert_encode" {
  provisioner "local-exec" {
    command = "openssl x509 -in .openvpn/ca_cert.pem -outform der | base64 -w0 > .openvpn/ca_cert.der"
  }

  # When running locally for interactive dev, this file remains between runs
  # On a build agent it doesn't persist across runs, but since the file output is deterministic
  # we can just recreate it each time
  triggers = {
    always_run = timestamp()
  }

  depends_on = [local_file.ca_pem]
}

data "local_file" "ca_der" {
  filename = ".openvpn/ca_cert.der"

  depends_on = [
    null_resource.cert_encode
  ]
}

resource "tls_private_key" "client_cert" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "client_cert" {
  key_algorithm   = tls_private_key.client_cert.algorithm
  private_key_pem = tls_private_key.client_cert.private_key_pem

  subject {
    common_name  = "ClientOpenVPN"
    organization = var.cert_organisation
  }
}

resource "tls_locally_signed_cert" "client_cert" {
  cert_request_pem   = tls_cert_request.client_cert.cert_request_pem
  ca_key_algorithm   = tls_private_key.client_cert.algorithm
  ca_private_key_pem = tls_private_key.dev.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "key_encipherment",
    "client_auth"
  ]
}

resource "local_file" "client_cert" {
  content  = tls_locally_signed_cert.client_cert.cert_pem
  filename = ".openvpn/client_cert.pem"
}
