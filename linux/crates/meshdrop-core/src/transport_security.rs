//! Native MeshDrop TLS profile. The X.509 key authenticates each handshake while the
//! Ed25519 proof binds it to the same device identity across connections.
use crate::identity::{compute_fingerprint, Identity};
use anyhow::{anyhow, ensure, Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine as _};
use ed25519_dalek::{Signature, Signer, VerifyingKey};
use rcgen::{
    CertificateParams, DistinguishedName, DnType, ExtendedKeyUsagePurpose, IsCa, KeyPair,
    KeyUsagePurpose, SanType,
};
use rustls::{
    client::{
        danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier},
        Resumption,
    },
    crypto::{aws_lc_rs, verify_tls13_signature, CryptoProvider},
    pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer, ServerName, UnixTime},
    server::{
        danger::{ClientCertVerified, ClientCertVerifier},
        NoServerSessionStorage,
    },
    CipherSuite, ClientConfig, DigitallySignedStruct, Error, ServerConfig, SignatureScheme,
};
use std::sync::{Arc, OnceLock};
use tokio::net::TcpStream;
use tokio_rustls::{TlsAcceptor, TlsConnector, TlsStream};
use x509_parser::{
    extensions::{GeneralName, ParsedExtension},
    oid_registry::{OID_EC_P256, OID_KEY_TYPE_EC_PUBLIC_KEY, OID_SIG_ECDSA_WITH_SHA256},
    prelude::{ASN1Time, FromDer, X509Certificate, X509Version},
};

const PREFIX: &str = "urn:meshdrop:identity:";
const ALPN: &[u8] = b"meshdrop/1";

fn binding(point: &[u8], before: i64, after: i64) -> Vec<u8> {
    [
        b"MeshDrop TLS identity v1\0".as_slice(),
        point,
        format!("|{before}|{after}").as_bytes(),
    ]
    .concat()
}

fn credential(identity: &Identity) -> Result<(CertificateDer<'static>, PrivateKeyDer<'static>)> {
    let before = ASN1Time::now().timestamp() - 300;
    let after = before + 30 * 24 * 3600;
    let key = KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256)?;
    let sig = identity
        .signing_key
        .sign(&binding(key.public_key_raw(), before, after));
    let proof = [
        identity.verifying_key().as_bytes().as_slice(),
        sig.to_bytes().as_slice(),
    ]
    .concat();
    let mut cert = CertificateParams::default();
    cert.not_before = ASN1Time::from_timestamp(before)?.to_datetime();
    cert.not_after = ASN1Time::from_timestamp(after)?.to_datetime();
    cert.distinguished_name = DistinguishedName::new();
    cert.distinguished_name
        .push(DnType::CommonName, &identity.fingerprint);
    cert.is_ca = IsCa::ExplicitNoCa;
    cert.key_usages = vec![KeyUsagePurpose::DigitalSignature];
    cert.extended_key_usages = vec![
        ExtendedKeyUsagePurpose::ServerAuth,
        ExtendedKeyUsagePurpose::ClientAuth,
    ];
    cert.subject_alt_names = vec![SanType::URI(
        format!("{PREFIX}{}", STANDARD.encode(proof)).try_into()?,
    )];
    Ok((
        cert.self_signed(&key)?.der().clone(),
        PrivatePkcs8KeyDer::from(key.serialize_der()).into(),
    ))
}

fn fingerprint(der: &[u8], now: i64) -> Result<String> {
    ensure!(der.len() <= 16384, "oversized certificate");
    let (rest, cert) = X509Certificate::from_der(der).map_err(|_| anyhow!("invalid X.509"))?;
    let before = cert.validity.not_before.timestamp();
    let after = cert.validity.not_after.timestamp();
    ensure!(
        rest.is_empty()
            && cert.version() == X509Version::V3
            && cert.issuer().as_raw() == cert.subject().as_raw()
            && cert.issuer_uid.is_none()
            && cert.subject_uid.is_none()
            && cert.validity.not_before.to_datetime().nanosecond() == 0
            && cert.validity.not_after.to_datetime().nanosecond() == 0
            && before <= now
            && now < after,
        "invalid device certificate"
    );
    let spki = cert.public_key();
    let point = &spki.subject_public_key;
    ensure!(
        cert.signature_algorithm.algorithm == OID_SIG_ECDSA_WITH_SHA256
            && cert.signature_algorithm.parameters.is_none()
            && cert.signature == cert.signature_algorithm
            && cert.signature_value.unused_bits == 0
            && spki.algorithm.algorithm == OID_KEY_TYPE_EC_PUBLIC_KEY
            && spki
                .algorithm
                .parameters
                .as_ref()
                .and_then(|p| p.as_oid().ok())
                == Some(OID_EC_P256)
            && point.unused_bits == 0
            && point.data.len() == 65
            && point.data[0] == 4,
        "invalid device certificate key"
    );
    cert.verify_signature(None)
        .context("certificate self-signature")?;
    ensure!(
        cert.extensions().len() <= 10,
        "too many certificate extensions"
    );
    let mut proof = None;
    // extensions_map rejects duplicate OIDs.
    for ext in cert.extensions_map()?.values() {
        match ext.parsed_extension() {
            ParsedExtension::SubjectAlternativeName(san) => {
                let [GeneralName::URI(uri)] = san.general_names.as_slice() else {
                    anyhow::bail!("invalid device SAN")
                };
                let raw =
                    STANDARD.decode(uri.strip_prefix(PREFIX).context("device SAN prefix")?)?;
                ensure!(raw.len() == 96, "invalid identity proof length");
                proof = Some(raw);
            }
            ParsedExtension::BasicConstraints(_) => {
                ensure!(ext.value == [0x30, 0], "invalid basic constraints")
            }
            ParsedExtension::KeyUsage(_) => ensure!(
                ext.value == [3, 2, 7, 0x80] || ext.value == [3, 2, 5, 0xa0],
                "invalid key usage"
            ),
            ParsedExtension::ExtendedKeyUsage(eku) => ensure!(
                (eku.server_auth || eku.client_auth)
                    && !eku.any
                    && !eku.code_signing
                    && !eku.email_protection
                    && !eku.time_stamping
                    && !eku.ocsp_signing
                    && eku.other.is_empty(),
                "invalid extended key usage"
            ),
            ParsedExtension::ParseError { .. } => anyhow::bail!("malformed extension"),
            _ => ensure!(!ext.critical, "unexpected critical extension"),
        }
    }
    let proof = proof.context("missing device identity")?;
    let key = VerifyingKey::from_bytes(proof[..32].try_into()?)?;
    key.verify_strict(
        &binding(&point.data, before, after),
        &Signature::from_slice(&proof[32..])?,
    )?;
    Ok(compute_fingerprint(&key))
}

#[derive(Debug)]
struct PeerVerifier {
    provider: Arc<CryptoProvider>,
    expected: Option<String>,
    authenticated: OnceLock<String>,
}

impl PeerVerifier {
    fn new(expected: Option<String>) -> Arc<Self> {
        let mut provider = aws_lc_rs::default_provider();
        provider.cipher_suites.retain(|suite| {
            matches!(
                suite.suite(),
                CipherSuite::TLS13_AES_256_GCM_SHA384 | CipherSuite::TLS13_CHACHA20_POLY1305_SHA256
            )
        });
        Arc::new(Self {
            provider: Arc::new(provider),
            expected,
            authenticated: OnceLock::new(),
        })
    }

    fn check(
        &self,
        cert: &CertificateDer<'_>,
        chain: &[CertificateDer<'_>],
        now: UnixTime,
    ) -> Result<(), Error> {
        if !chain.is_empty() {
            return Err(Error::General("unexpected certificate chain".into()));
        }
        let fp = fingerprint(cert.as_ref(), now.as_secs() as i64)
            .map_err(|e| Error::General(e.to_string()))?;
        if self
            .expected
            .as_ref()
            .is_some_and(|expected| expected != &fp)
        {
            return Err(Error::General("unexpected device fingerprint".into()));
        }
        self.authenticated
            .set(fp)
            .map_err(|_| Error::General("duplicate certificate verification".into()))
    }
}

impl ServerCertVerifier for PeerVerifier {
    fn verify_server_cert(
        &self,
        cert: &CertificateDer<'_>,
        chain: &[CertificateDer<'_>],
        _: &ServerName<'_>,
        _: &[u8],
        now: UnixTime,
    ) -> Result<ServerCertVerified, Error> {
        self.check(cert, chain, now)?;
        Ok(ServerCertVerified::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![SignatureScheme::ECDSA_NISTP256_SHA256]
    }

    fn verify_tls12_signature(
        &self,
        _: &[u8],
        _: &CertificateDer<'_>,
        _: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, Error> {
        Err(Error::General("TLS 1.3 required".into()))
    }

    fn verify_tls13_signature(
        &self,
        msg: &[u8],
        cert: &CertificateDer<'_>,
        sig: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, Error> {
        verify_tls13_signature(
            msg,
            cert,
            sig,
            &self.provider.signature_verification_algorithms,
        )
    }
}

impl ClientCertVerifier for PeerVerifier {
    fn root_hint_subjects(&self) -> &[rustls::DistinguishedName] {
        &[]
    }

    fn verify_client_cert(
        &self,
        cert: &CertificateDer<'_>,
        chain: &[CertificateDer<'_>],
        now: UnixTime,
    ) -> Result<ClientCertVerified, Error> {
        self.check(cert, chain, now)?;
        Ok(ClientCertVerified::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        ServerCertVerifier::supported_verify_schemes(self)
    }
    fn verify_tls12_signature(
        &self,
        msg: &[u8],
        cert: &CertificateDer<'_>,
        sig: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, Error> {
        ServerCertVerifier::verify_tls12_signature(self, msg, cert, sig)
    }
    fn verify_tls13_signature(
        &self,
        msg: &[u8],
        cert: &CertificateDer<'_>,
        sig: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, Error> {
        ServerCertVerifier::verify_tls13_signature(self, msg, cert, sig)
    }
}

pub(crate) async fn handshake(
    socket: TcpStream,
    identity: &Identity,
    target: Option<String>,
) -> Result<(TlsStream<TcpStream>, String)> {
    let (cert, key) = credential(identity)?;
    let verifier = PeerVerifier::new(target);
    let stream: TlsStream<_> = if verifier.expected.is_some() {
        let mut config = ClientConfig::builder_with_provider(verifier.provider.clone())
            .with_protocol_versions(&[&rustls::version::TLS13])?
            .dangerous()
            .with_custom_certificate_verifier(verifier.clone())
            .with_client_auth_cert(vec![cert], key)?;
        config.alpn_protocols = vec![ALPN.to_vec()];
        config.resumption = Resumption::disabled();
        config.enable_sni = false;
        TlsConnector::from(Arc::new(config))
            .connect(ServerName::try_from("meshdrop.local")?, socket)
            .await?
            .into()
    } else {
        let mut config = ServerConfig::builder_with_provider(verifier.provider.clone())
            .with_protocol_versions(&[&rustls::version::TLS13])?
            .with_client_cert_verifier(verifier.clone())
            .with_single_cert(vec![cert], key)?;
        config.alpn_protocols = vec![ALPN.to_vec()];
        config.send_tls13_tickets = 0;
        config.session_storage = Arc::new(NoServerSessionStorage {});
        TlsAcceptor::from(Arc::new(config))
            .accept(socket)
            .await?
            .into()
    };
    ensure!(
        stream.get_ref().1.alpn_protocol() == Some(ALPN),
        "MeshDrop ALPN required"
    );
    Ok((
        stream,
        verifier
            .authenticated
            .get()
            .context("missing peer identity")?
            .clone(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::SigningKey;
    use tokio::{
        io::{AsyncReadExt, AsyncWriteExt},
        net::TcpListener,
        time::{timeout, Duration},
    };

    fn identity() -> Identity {
        let signing_key = SigningKey::from_bytes(&rand::random());
        Identity {
            id: uuid::Uuid::new_v4().simple().to_string(),
            fingerprint: compute_fingerprint(&signing_key.verifying_key()),
            signing_key,
        }
    }

    #[test]
    fn key_rotation_preserves_identity_and_binds_key_and_dates() {
        let id = identity();
        let (cert, _) = credential(&id).unwrap();
        let (renewed, _) = credential(&id).unwrap();
        let now = ASN1Time::now().timestamp();
        assert_ne!(cert, renewed);
        assert_eq!(fingerprint(cert.as_ref(), now).unwrap(), id.fingerprint);
        assert_eq!(fingerprint(renewed.as_ref(), now).unwrap(), id.fingerprint);
        assert!(fingerprint(cert.as_ref(), 0).is_err());
        assert!(fingerprint(cert.as_ref(), now + 30 * 86400).is_err());

        let (_, parsed) = X509Certificate::from_der(cert.as_ref()).unwrap();
        let san = parsed.subject_alternative_name().unwrap().unwrap();
        let [GeneralName::URI(uri)] = san.value.general_names.as_slice() else {
            panic!("missing proof")
        };
        let mut params = CertificateParams::default();
        params.not_before = parsed.validity.not_before.to_datetime();
        params.not_after = parsed.validity.not_after.to_datetime();
        params.subject_alt_names = vec![SanType::URI((*uri).try_into().unwrap())];
        let other_key = KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256).unwrap();
        let signed_by_other_key = params.self_signed(&other_key).unwrap();
        assert!(fingerprint(signed_by_other_key.der().as_ref(), now).is_err());
    }

    async fn peer_handshakes(
        expected_matches: bool,
    ) -> (
        Identity,
        Identity,
        Result<(TlsStream<TcpStream>, String)>,
        Result<(TlsStream<TcpStream>, String)>,
    ) {
        let server = identity();
        let client = identity();
        let expected = if expected_matches {
            server.fingerprint.clone()
        } else {
            client.fingerprint.clone()
        };
        let listener = TcpListener::bind(("127.0.0.1", 0)).await.unwrap();
        let address = listener.local_addr().unwrap();
        let (server_result, client_result) = tokio::join!(
            async { handshake(listener.accept().await?.0, &server, None).await },
            async { handshake(TcpStream::connect(address).await?, &client, Some(expected)).await }
        );
        (client, server, client_result, server_result)
    }

    #[tokio::test]
    async fn mutually_authenticated_stream_transfers_both_ways() {
        timeout(Duration::from_secs(5), async {
            let (client, server, client_result, server_result) = peer_handshakes(true).await;
            let (mut cs, cs_fp) = client_result.unwrap();
            let (mut ss, ss_fp) = server_result.unwrap();
            assert_eq!((cs_fp, ss_fp), (server.fingerprint, client.fingerprint));
            assert_eq!(
                cs.get_ref().1.protocol_version(),
                Some(rustls::ProtocolVersion::TLSv1_3)
            );
            assert_eq!(cs.get_ref().1.alpn_protocol(), Some(ALPN));
            let content: Vec<u8> = (0..131071).map(|n| (n % 251) as u8).collect();
            let mut received = vec![0; content.len()];
            let mut echoed = vec![0; content.len()];
            tokio::join!(
                async {
                    cs.write_all(&content).await.unwrap();
                    cs.flush().await.unwrap();
                    cs.read_exact(&mut echoed).await.unwrap();
                },
                async {
                    ss.read_exact(&mut received).await.unwrap();
                    ss.write_all(&received).await.unwrap();
                    ss.flush().await.unwrap();
                }
            );
            assert_eq!(received, content);
            assert_eq!(echoed, content);
        })
        .await
        .unwrap();
    }

    #[tokio::test]
    async fn wrong_discovery_identity_cannot_establish_a_session() {
        let (_, _, client, server) = timeout(Duration::from_secs(5), peer_handshakes(false))
            .await
            .unwrap();
        assert!(client.is_err());
        assert!(server.is_err());
    }
}
