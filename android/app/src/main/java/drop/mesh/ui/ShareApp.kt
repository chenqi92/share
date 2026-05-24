package drop.mesh.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import drop.mesh.data.Device

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShareApp() {
    val engine = LocalEngine.current
    val pendingPairings by engine.pendingPairings.collectAsState()
    val pendingOffers by engine.pendingFileOffers.collectAsState()
    val history by engine.history.collectAsState()

    var sendingTo by remember { mutableStateOf<Device?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("MeshDrop", style = MaterialTheme.typography.titleLarge) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        containerColor = Color.Transparent,
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFFD6E9FF),
                            Color(0xFFE8DFFF),
                            Color(0xFFFFE1EA),
                        )
                    )
                )
                .padding(padding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                SelfCard()
                DeviceList(onDeviceTap = { sendingTo = it })
                Spacer(Modifier.height(if (history.isEmpty()) 24.dp else 300.dp))
            }

            if (history.isNotEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter),
                ) { HistoryView() }
            }

            sendingTo?.let { device ->
                SendSheet(device = device, onDismiss = { sendingTo = null })
            }
            pendingPairings.firstOrNull()?.let { pp ->
                PairingSheet(pending = pp, onDismiss = { })
            }
            pendingOffers.firstOrNull()?.let { offer ->
                FileOfferSheet(offer = offer, onDismiss = { })
            }
        }
    }
}
