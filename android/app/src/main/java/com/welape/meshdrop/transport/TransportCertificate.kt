package com.welape.meshdrop.transport

import com.welape.meshdrop.data.Identity
import com.welape.meshdrop.data.IdentityStore
import com.welape.meshdrop.data.IdentityStore.provider
import org.bouncycastle.asn1.ASN1IA5String
import org.bouncycastle.asn1.edec.EdECObjectIdentifiers
import org.bouncycastle.asn1.sec.SECObjectIdentifiers
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.AlgorithmIdentifier
import org.bouncycastle.asn1.x509.BasicConstraints
import org.bouncycastle.asn1.x509.ExtendedKeyUsage
import org.bouncycastle.asn1.x509.Extension
import org.bouncycastle.asn1.x509.GeneralName
import org.bouncycastle.asn1.x509.GeneralNames
import org.bouncycastle.asn1.x509.KeyPurposeId
import org.bouncycastle.asn1.x509.KeyUsage
import org.bouncycastle.asn1.x509.SubjectPublicKeyInfo
import org.bouncycastle.asn1.x9.X9ObjectIdentifiers
import org.bouncycastle.cert.X509CertificateHolder
import org.bouncycastle.cert.X509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.bouncycastle.operator.jcajce.JcaContentVerifierProviderBuilder
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.spec.X509EncodedKeySpec
import java.util.Base64
import java.util.Date

internal object TransportCertificate {
    private const val URI_PREFIX = "urn:meshdrop:identity:"
    private val curve = AlgorithmIdentifier(X9ObjectIdentifiers.id_ecPublicKey, SECObjectIdentifiers.secp256r1)
    private val ecdsa = AlgorithmIdentifier(X9ObjectIdentifiers.ecdsa_with_SHA256)
    private val ed25519 = AlgorithmIdentifier(EdECObjectIdentifiers.id_Ed25519)
    private val purposes = arrayOf(KeyPurposeId.id_kp_serverAuth, KeyPurposeId.id_kp_clientAuth)

    data class Material(val der: ByteArray, val privateKey: PrivateKey)

    fun create(identity: Identity, now: Long = System.currentTimeMillis()): Material {
        val key = KeyPairGenerator.getInstance("EC", provider).apply {
            initialize(ECGenParameterSpec("secp256r1"))
        }.generateKeyPair()
        val spki = SubjectPublicKeyInfo.getInstance(key.public.encoded)
        val before = now / 1000 - 300
        val after = before + 30 * 86400
        val rawPublic = SubjectPublicKeyInfo.getInstance(identity.keyPair.public.encoded).publicKeyData.octets
        val signature = Signature.getInstance("Ed25519", provider).run {
            initSign(identity.keyPair.private)
            update(binding(spki.publicKeyData.octets, before, after))
            sign()
        }
        val uri = URI_PREFIX + Base64.getEncoder().encodeToString(rawPublic + signature)
        val name = X500Name("CN=" + identity.fingerprint)
        val builder = X509v3CertificateBuilder(
            name, BigInteger(127, SecureRandom()).setBit(0), Date(before * 1000), Date(after * 1000), name, spki,
        )
        builder.addExtension(Extension.basicConstraints, true, BasicConstraints(false))
        builder.addExtension(Extension.keyUsage, true, KeyUsage(KeyUsage.digitalSignature))
        builder.addExtension(Extension.extendedKeyUsage, false, ExtendedKeyUsage(purposes))
        builder.addExtension(Extension.subjectAlternativeName, false, GeneralNames(GeneralName(GeneralName.uniformResourceIdentifier, uri)))
        val signer = JcaContentSignerBuilder("SHA256withECDSA").setProvider(provider).build(key.private)
        return Material(builder.build(signer).encoded, key.private)
    }

    fun verify(der: ByteArray, now: Long = System.currentTimeMillis()): String {
        require(der.size <= 16384)
        val cert = X509CertificateHolder(der)
        val tbs = cert.toASN1Structure().tbsCertificate
        val spki = cert.subjectPublicKeyInfo
        require(cert.versionNumber == 3 && cert.issuer == cert.subject && tbs.signature == ecdsa && cert.signatureAlgorithm == ecdsa)
        require(now >= cert.notBefore.time && now < cert.notAfter.time && spki.algorithm == curve)
        val point = spki.publicKeyData.octets
        require(point.size == 65 && point.first() == 4.toByte())
        require(cert.isSignatureValid(JcaContentVerifierProviderBuilder().setProvider(provider).build(spki)))
        val extensions = cert.extensions
        val profile = setOf(Extension.basicConstraints, Extension.keyUsage, Extension.extendedKeyUsage, Extension.subjectAlternativeName)
        require(extensions.extensionOIDs.size <= 10 && extensions.criticalExtensionOIDs.all { it in profile })
        extensions.getExtension(Extension.basicConstraints)?.let {
            require(it.parsedValue == BasicConstraints(false).toASN1Primitive())
        }
        extensions.getExtension(Extension.keyUsage)?.let {
            require(it.parsedValue == KeyUsage(KeyUsage.digitalSignature).toASN1Primitive())
        }
        extensions.getExtension(Extension.extendedKeyUsage)?.let {
            val usage = ExtendedKeyUsage.getInstance(it.parsedValue).usages
            require(usage.isNotEmpty() && usage.all { purpose -> purpose in purposes })
        }
        val san = GeneralNames.fromExtensions(extensions, Extension.subjectAlternativeName).names.single()
        require(san.tagNo == GeneralName.uniformResourceIdentifier)
        val uri = ASN1IA5String.getInstance(san.name).string
        require(uri.startsWith(URI_PREFIX))
        val proof = Base64.getDecoder().decode(uri.substring(URI_PREFIX.length))
        require(proof.size == 96)
        val rawPublic = proof.copyOfRange(0, 32)
        val publicKey = java.security.KeyFactory.getInstance("Ed25519", provider)
            .generatePublic(X509EncodedKeySpec(SubjectPublicKeyInfo(ed25519, rawPublic).encoded))
        val valid = Signature.getInstance("Ed25519", provider).run {
            initVerify(publicKey)
            update(binding(point, cert.notBefore.time / 1000, cert.notAfter.time / 1000))
            verify(proof, 32, 64)
        }
        require(valid)
        return IdentityStore.computeFingerprint(publicKey)
    }

    private fun binding(point: ByteArray, before: Long, after: Long): ByteArray =
        "MeshDrop TLS identity v1\u0000".toByteArray(Charsets.US_ASCII) + point +
            "|$before|$after".toByteArray(Charsets.US_ASCII)
}
