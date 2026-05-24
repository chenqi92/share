import { create } from 'zustand'
import {
  MESHDROP_DEVICES,
  MESHDROP_HISTORY_BY_DAY,
  MESHDROP_PENDING_OFFER,
  MESHDROP_TRANSFERS,
  type HistoryDay,
  type MeshDevice,
  type PendingOffer,
  type TransferRow,
} from '../lib/mockData'

interface EngineState {
  devices: MeshDevice[]
  transfers: TransferRow[]
  history: HistoryDay[]
  selectedPeerId?: string
  pendingOffer?: PendingOffer
  selectPeer: (id?: string) => void
  setPendingOffer: (offer?: PendingOffer) => void
  acceptOffer: () => void
  rejectOffer: () => void
}

export const useMockEngine = create<EngineState>((set) => ({
  devices: MESHDROP_DEVICES,
  transfers: MESHDROP_TRANSFERS,
  history: MESHDROP_HISTORY_BY_DAY,
  selectedPeerId: 'jiawei',
  pendingOffer: undefined,
  selectPeer: (id) => set({ selectedPeerId: id }),
  setPendingOffer: (offer) => set({ pendingOffer: offer }),
  acceptOffer: () => set({ pendingOffer: undefined }),
  rejectOffer: () => set({ pendingOffer: undefined }),
}))

export { MESHDROP_PENDING_OFFER }
