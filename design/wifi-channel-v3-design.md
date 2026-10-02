# BE14 channel view

The approved mobile layout groups BE14's 2.4, 5 and 6 GHz radios in a selector. The selected radio shows its configured channel and width, current TX failure rate, a 24-hour link-quality chart, client signal distribution when supported, and a 24-hour RX/TX activity chart. All values must be sourced from the router; unavailable sections are omitted rather than filled with sample data.

The MT7988 vendor driver in use returns `nl80211 not found` for `iw survey dump`. Its `iwpriv <interface> stat` output includes cumulative TX success/failure and RX success/CRC counts. The UI must call these **TX failure** and **RX CRC**, never airtime occupancy, interference, or TX retry count. `network.wireless status` supplies band, channel, EHT width and AP interface; its raw payload contains Wi-Fi keys and must be reduced on the router before delivery. `/sys/class/net/<interface>/statistics/{rx,tx}_bytes` supplies activity counters. Client signal bins require a parseable station list; the observed empty list means no distribution can yet be verified.

The router records one sample per radio per minute in `/tmp/traffic`, retaining at most 24 hours in memory. A sample is emitted only when two monotonic counter readings exist. Resets and gaps yield missing points. The read-only `getWirelessHistory` RPC sends bounded, downsampled points with no Wi-Fi keys, station MACs, or private driver text. The app fetches it only for the Wi-Fi page. A missing history RPC leaves channel/status available. The app preserves timestamps and never draws across a gap as continuous data.

The mockup is [`wifi-channel-v3.png`](../../.tmp/wifi-channel-v3.png). Its curves are layout examples, not measurements.
