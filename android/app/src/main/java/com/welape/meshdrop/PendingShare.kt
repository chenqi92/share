package com.welape.meshdrop

import android.net.Uri

/**
 * 系统分享菜单（ACTION_SEND / ACTION_SEND_MULTIPLE）拉起后，
 * 暂存在 [ShareApplication.pendingShare] 里等用户在 UI 选目标 peer。
 *
 * 选完 peer 后 UI 调 [ShareApplication.consumePendingShare] 取出并清空。
 */
sealed class PendingShare {
    data class Text(val content: String) : PendingShare()
    data class Files(val uris: List<Uri>) : PendingShare()
}
