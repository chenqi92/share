package com.welape.meshdrop.transport

import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.io.File
import java.util.UUID

class ResumeStoreTest {
    private lateinit var storeFile: File

    @Before
    fun setUp() {
        storeFile = File.createTempFile("resume-test-", ".json").apply { delete() }
    }

    @After
    fun tearDown() {
        storeFile.delete()
    }

    private fun sample(
        fp: String = "AA112233",
        sha: String = "deadbeef",
        bytesDone: Long = 100,
        fileSize: Long = 500,
    ) = ResumeRecord(
        peerFingerprint = fp,
        transferId = UUID.randomUUID().toString(),
        fileName = "file.bin",
        fileSize = fileSize,
        sha256 = sha,
        savedPath = "/tmp/file.bin",
        bytesDone = bytesDone,
        updatedAt = 1_700_000_000L,
    )

    @Test
    fun emptyStoreFindReturnsNull() = runBlocking {
        val store = ResumeStore(storeFile)
        assertNull(store.find("AA", "BB"))
    }

    @Test
    fun upsertAndFind() = runBlocking {
        val store = ResumeStore(storeFile)
        store.upsert(sample())
        val found = store.find("AA112233", "deadbeef")
        assertNotNull(found)
        assertEquals(100L, found!!.bytesDone)
        assertEquals(500L, found.fileSize)
        assertEquals("file.bin", found.fileName)
    }

    @Test
    fun upsertReplacesByKey() = runBlocking {
        val store = ResumeStore(storeFile)
        store.upsert(sample(bytesDone = 100))
        store.upsert(sample(bytesDone = 250))
        val found = store.find("AA112233", "deadbeef")
        assertEquals(250L, found!!.bytesDone)
        assertEquals(1, store.snapshot().size)
    }

    @Test
    fun differentPeerOrShaCoexist() = runBlocking {
        val store = ResumeStore(storeFile)
        store.upsert(sample(fp = "AA", sha = "S1", bytesDone = 10))
        store.upsert(sample(fp = "AA", sha = "S2", bytesDone = 20))
        store.upsert(sample(fp = "BB", sha = "S1", bytesDone = 30))
        assertEquals(3, store.snapshot().size)
        assertEquals(10L, store.find("AA", "S1")!!.bytesDone)
        assertEquals(30L, store.find("BB", "S1")!!.bytesDone)
    }

    @Test
    fun clearRemovesOnlyMatchingKey() = runBlocking {
        val store = ResumeStore(storeFile)
        store.upsert(sample(fp = "AA", sha = "S1"))
        store.upsert(sample(fp = "AA", sha = "S2"))
        store.clear("AA", "S1")
        assertNull(store.find("AA", "S1"))
        assertNotNull(store.find("AA", "S2"))
    }

    @Test
    fun persistAcrossInstances() = runBlocking {
        val store1 = ResumeStore(storeFile)
        store1.upsert(sample(bytesDone = 42))

        val store2 = ResumeStore(storeFile)
        val found = store2.find("AA112233", "deadbeef")
        assertEquals(42L, found!!.bytesDone)
    }

    @Test
    fun keyDerivation() {
        assertEquals("FP123:ABC", ResumeRecord.makeKey("FP123", "ABC"))
    }
}
