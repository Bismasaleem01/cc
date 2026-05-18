from datetime import datetime, timedelta
from ipaddress import ip_address
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID


ROOT = Path(__file__).resolve().parents[1]
CERT_DIR = ROOT / "certs"
CERT_DIR.mkdir(exist_ok=True)

now = datetime.utcnow()

ca_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
ca_name = x509.Name(
    [
        x509.NameAttribute(NameOID.COUNTRY_NAME, "PK"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "SmartHealthcareApp Local CA"),
        x509.NameAttribute(NameOID.COMMON_NAME, "SmartHealthcareApp Local CA"),
    ]
)
ca_cert = (
    x509.CertificateBuilder()
    .subject_name(ca_name)
    .issuer_name(ca_name)
    .public_key(ca_key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(now - timedelta(days=1))
    .not_valid_after(now + timedelta(days=3650))
    .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
    .add_extension(
        x509.KeyUsage(
            digital_signature=True,
            key_cert_sign=True,
            crl_sign=True,
            key_encipherment=False,
            content_commitment=False,
            data_encipherment=False,
            key_agreement=False,
            encipher_only=False,
            decipher_only=False,
        ),
        critical=True,
    )
    .sign(ca_key, hashes.SHA256())
)

server_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
server_name = x509.Name(
    [
        x509.NameAttribute(NameOID.COUNTRY_NAME, "PK"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "SmartHealthcareApp Local"),
        x509.NameAttribute(NameOID.COMMON_NAME, "192.168.100.114"),
    ]
)
server_cert = (
    x509.CertificateBuilder()
    .subject_name(server_name)
    .issuer_name(ca_name)
    .public_key(server_key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(now - timedelta(days=1))
    .not_valid_after(now + timedelta(days=825))
    .add_extension(
        x509.SubjectAlternativeName(
            [
                x509.DNSName("localhost"),
                x509.IPAddress(ip_address("127.0.0.1")),
                x509.IPAddress(ip_address("192.168.100.114")),
            ]
        ),
        critical=False,
    )
    .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
    .add_extension(
        x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),
        critical=False,
    )
    .sign(ca_key, hashes.SHA256())
)

(CERT_DIR / "local-ca-key.pem").write_bytes(
    ca_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    )
)
(CERT_DIR / "local-ca.pem").write_bytes(ca_cert.public_bytes(serialization.Encoding.PEM))
(CERT_DIR / "local-ca.crt").write_bytes(ca_cert.public_bytes(serialization.Encoding.DER))

(CERT_DIR / "local-key.pem").write_bytes(
    server_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    )
)
(CERT_DIR / "local-cert.pem").write_bytes(server_cert.public_bytes(serialization.Encoding.PEM))

print(CERT_DIR / "local-ca.crt")
