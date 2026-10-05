import 'package:immortalwrt_app/models/router_models.dart';

RouterSnapshot previewSnapshot() {
  final now = DateTime(2026, 10, 1, 10, 41);
  return RouterSnapshot(
    fetchedAt: now,
    hostHints: const [
      HostHint(
        mac: 'aa:bb:cc:00:01:14',
        name: 'iPhone 17 Pro',
        addresses: [
          '192.168.2.114',
          '240e:abcd:1234:2::72a1',
          'fdc8:64ed:f962::72a1',
        ],
      ),
    ],
    uptimeSeconds: 2 * 86400 + 14 * 3600 + 7 * 60,
    summary: TrafficSummary(
      collectedAt: now.subtract(const Duration(seconds: 20)),
      version: '1.1.5',
      headlineDown: 45741401702,
      headlineUp: 9019431322,
      headlineSource: 'br-wan',
      hasWanTotals: true,
      attributedDown: 13550621819,
      attributedUp: 1073741824,
      clientCount: 6,
      clients: const [
        TrafficClient(
          ip: '192.168.2.114',
          name: 'iPhone 17 Pro',
          bytes: 2587717796,
        ),
        TrafficClient(
          ip: '192.168.2.132',
          name: 'MacBook Pro',
          bytes: 1105954079,
        ),
        TrafficClient(
          ip: '192.168.2.138',
          name: 'Living Room TV',
          bytes: 665719931,
        ),
        TrafficClient(ip: '192.168.2.140', name: 'iPad Air', bytes: 332859965),
        TrafficClient(ip: '192.168.2.151', name: 'Office PC', bytes: 193273528),
        TrafficClient(ip: '192.168.2.160', name: 'NAS', bytes: 96636764),
      ],
      apps: const [
        TrafficApp(name: 'YouTube', down: 9040906158, up: 332859965),
        TrafficApp(name: 'Apple', down: 4488240824, up: 236223201),
        TrafficApp(name: 'bilibili', down: 2201170739, up: 118111601),
        TrafficApp(name: 'WeChat', down: 1202590843, up: 386547057),
      ],
    ),
    trafficWindow: TrafficSummary(
      collectedAt: now.subtract(const Duration(seconds: 20)),
      version: '1.1.5',
      headlineDown: 45741401702,
      headlineUp: 9019431322,
      headlineSource: 'br-wan',
      hasWanTotals: true,
      attributedDown: 13550621819,
      attributedUp: 1073741824,
      clientCount: 6,
      clients: const [
        TrafficClient(
          ip: '192.168.2.114',
          name: 'iPhone 17 Pro',
          bytes: 2587717796,
        ),
        TrafficClient(
          ip: '192.168.2.132',
          name: 'MacBook Pro',
          bytes: 1105954079,
        ),
        TrafficClient(
          ip: '192.168.2.138',
          name: 'Living Room TV',
          bytes: 665719931,
        ),
        TrafficClient(ip: '192.168.2.140', name: 'iPad Air', bytes: 332859965),
        TrafficClient(ip: '192.168.2.151', name: 'Office PC', bytes: 193273528),
        TrafficClient(ip: '192.168.2.160', name: 'NAS', bytes: 96636764),
      ],
      apps: const [
        TrafficApp(name: 'YouTube', down: 9040906158, up: 332859965),
        TrafficApp(name: 'Apple', down: 4488240824, up: 236223201),
        TrafficApp(name: 'bilibili', down: 2201170739, up: 118111601),
        TrafficApp(name: 'WeChat', down: 1202590843, up: 386547057),
      ],
    ),
    live: LiveRate(
      ready: true,
      downBytesPerSecond: 13002342,
      upBytesPerSecond: 2202010,
      at: now,
    ),
    cpuUsagePercent: 22,
    memory: const RouterMemory(
      totalBytes: 1024 * 1024 * 1024,
      availableBytes: 560 * 1024 * 1024,
    ),
    sfpPorts: const [
      SfpPort(interface: 'eth1', slot: 'SFP1', linkUp: true, speedMbps: 2500),
      SfpPort(interface: 'eth2', slot: 'SFP2', linkUp: true, speedMbps: 10000),
    ],
    series: TrafficSeries(
      interval: 60,
      points: [
        TrafficPoint(
          at: now.subtract(Duration(minutes: 59)),
          downBytesPerSecond: 8388608,
          upBytesPerSecond: 3670016,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 58)),
          downBytesPerSecond: 13582178,
          upBytesPerSecond: 4318733,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 57)),
          downBytesPerSecond: 18485261,
          upBytesPerSecond: 4864093,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 56)),
          downBytesPerSecond: 22833618,
          upBytesPerSecond: 5306530,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 55)),
          downBytesPerSecond: 26412734,
          upBytesPerSecond: 5652026,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 54)),
          downBytesPerSecond: 29076052,
          upBytesPerSecond: 5911322,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 53)),
          downBytesPerSecond: 30756063,
          upBytesPerSecond: 6098858,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 52)),
          downBytesPerSecond: 31467143,
          upBytesPerSecond: 6792210,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 51)),
          downBytesPerSecond: 31299906,
          upBytesPerSecond: 7636204,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 50)),
          downBytesPerSecond: 30407792,
          upBytesPerSecond: 8379261,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 49)),
          downBytesPerSecond: 31385319,
          upBytesPerSecond: 8995596,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 48)),
          downBytesPerSecond: 33562462,
          upBytesPerSecond: 9464046,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 47)),
          downBytesPerSecond: 34943794,
          upBytesPerSecond: 9769180,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 46)),
          downBytesPerSecond: 35356948,
          upBytesPerSecond: 9902085,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 45)),
          downBytesPerSecond: 34696306,
          upBytesPerSecond: 9860796,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 44)),
          downBytesPerSecond: 32935851,
          upBytesPerSecond: 9650346,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 43)),
          downBytesPerSecond: 30134044,
          upBytesPerSecond: 9282414,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 42)),
          downBytesPerSecond: 26430145,
          upBytesPerSecond: 8774624,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 41)),
          downBytesPerSecond: 22032330,
          upBytesPerSecond: 8149510,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 40)),
          downBytesPerSecond: 17829579,
          upBytesPerSecond: 7551513,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 39)),
          downBytesPerSecond: 16922050,
          upBytesPerSecond: 7546406,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 38)),
          downBytesPerSecond: 15629486,
          upBytesPerSecond: 7451856,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 37)),
          downBytesPerSecond: 13874271,
          upBytesPerSecond: 7251121,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 36)),
          downBytesPerSecond: 17732610,
          upBytesPerSecond: 6931267,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 35)),
          downBytesPerSecond: 20846029,
          upBytesPerSecond: 6484280,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 34)),
          downBytesPerSecond: 23147231,
          upBytesPerSecond: 5907914,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 33)),
          downBytesPerSecond: 24646939,
          upBytesPerSecond: 5206199,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 32)),
          downBytesPerSecond: 25427338,
          upBytesPerSecond: 4389580,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 31)),
          downBytesPerSecond: 25627990,
          upBytesPerSecond: 3474681,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 30)),
          downBytesPerSecond: 28439944,
          upBytesPerSecond: 3497147,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 29)),
          downBytesPerSecond: 31857220,
          upBytesPerSecond: 3841312,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 28)),
          downBytesPerSecond: 34489300,
          upBytesPerSecond: 4136792,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 27)),
          downBytesPerSecond: 36144505,
          upBytesPerSecond: 4856683,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 26)),
          downBytesPerSecond: 36700059,
          upBytesPerSecond: 5857644,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 25)),
          downBytesPerSecond: 36114392,
          upBytesPerSecond: 6781985,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 24)),
          downBytesPerSecond: 34431321,
          upBytesPerSecond: 7601354,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 23)),
          downBytesPerSecond: 31775646,
          upBytesPerSecond: 8291626,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 22)),
          downBytesPerSecond: 28340642,
          upBytesPerSecond: 8834073,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 21)),
          downBytesPerSecond: 25628702,
          upBytesPerSecond: 9216233,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 20)),
          downBytesPerSecond: 25414827,
          upBytesPerSecond: 9432420,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 19)),
          downBytesPerSecond: 24616916,
          upBytesPerSecond: 9483856,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 18)),
          downBytesPerSecond: 23096696,
          upBytesPerSecond: 9378413,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 17)),
          downBytesPerSecond: 20773727,
          upBytesPerSecond: 9129988,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 16)),
          downBytesPerSecond: 17639308,
          upBytesPerSecond: 8757547,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 15)),
          downBytesPerSecond: 13874199,
          upBytesPerSecond: 8297827,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 14)),
          downBytesPerSecond: 15670015,
          upBytesPerSecond: 8526055,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 13)),
          downBytesPerSecond: 16950446,
          upBytesPerSecond: 8655265,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 12)),
          downBytesPerSecond: 17849905,
          upBytesPerSecond: 8665706,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 11)),
          downBytesPerSecond: 22155963,
          upBytesPerSecond: 8541446,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 10)),
          downBytesPerSecond: 26538518,
          upBytesPerSecond: 8271554,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 9)),
          downBytesPerSecond: 30220883,
          upBytesPerSecond: 7851010,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 8)),
          downBytesPerSecond: 32996499,
          upBytesPerSecond: 7281281,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 7)),
          downBytesPerSecond: 34728132,
          upBytesPerSecond: 6570539,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 6)),
          downBytesPerSecond: 35359554,
          upBytesPerSecond: 5733488,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 5)),
          downBytesPerSecond: 34918996,
          upBytesPerSecond: 4790812,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 4)),
          downBytesPerSecond: 33514047,
          upBytesPerSecond: 3768275,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 3)),
          downBytesPerSecond: 31318607,
          upBytesPerSecond: 2695530,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 2)),
          downBytesPerSecond: 30439243,
          upBytesPerSecond: 2589619,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 1)),
          downBytesPerSecond: 31314508,
          upBytesPerSecond: 3665563,
        ),
        TrafficPoint(
          at: now.subtract(Duration(minutes: 0)),
          downBytesPerSecond: 31460165,
          upBytesPerSecond: 4694340,
        ),
      ],
    ),
    radios: const [
      WifiRadio(
        name: 'MT7990_1_1',
        up: true,
        ssids: [],
        clientCount: null,
        band: '2g',
        channel: 3,
        htmode: 'EHT40',
      ),
      WifiRadio(
        name: 'MT7990_1_2',
        up: true,
        ssids: [],
        clientCount: null,
        band: '5g',
        channel: 40,
        htmode: 'EHT160',
        bssid: '02:11:22:33:44:55',
      ),
      WifiRadio(
        name: 'MT7990_2',
        up: true,
        ssids: [],
        clientCount: null,
        band: '6g',
        channel: 37,
        htmode: 'EHT320',
      ),
    ],
    wifiHistory: WifiHistory(
      interval: 300,
      points: List.generate(
        288,
        (i) => WifiPoint(
          at: DateTime.now().subtract(Duration(minutes: (287 - i) * 5)),
          radio: 'MT7990_1_2',
          downBytesPerSecond: (i % 37 == 0 ? 120000 : 10000 + i * 100)
              .toDouble(),
          upBytesPerSecond: (3000 + (i % 21) * 350).toDouble(),
          txFailurePercent: (2 + (i % 35 == 0 ? 6 : 0)).toDouble(),
          rxCrcPercent: (4 + (i % 47 == 0 ? 9 : 0)).toDouble(),
        ),
      ),
    ),
    dhcpDevices: const [
      DhcpDevice(
        ip: '192.168.2.114',
        name: 'iPhone 17 Pro',
        mac: 'aa:bb:cc:00:01:14',
      ),
      DhcpDevice(
        ip: '192.168.2.132',
        name: 'MacBook Pro',
        mac: 'aa:bb:cc:00:01:32',
      ),
      DhcpDevice(
        ip: '192.168.2.138',
        name: 'Living Room TV',
        mac: 'aa:bb:cc:00:01:38',
      ),
      DhcpDevice(
        ip: '192.168.2.140',
        name: 'iPad Air',
        mac: 'aa:bb:cc:00:01:40',
      ),
      DhcpDevice(ip: '192.168.2.145', name: '', mac: 'aa:bb:cc:00:01:45'),
      DhcpDevice(
        ip: '192.168.2.151',
        name: 'Office PC',
        mac: 'aa:bb:cc:00:01:51',
      ),
      DhcpDevice(
        ip: '192.168.2.152',
        name: 'Pixel 9',
        mac: 'aa:bb:cc:00:01:52',
      ),
      DhcpDevice(ip: '192.168.2.153', name: 'Switch', mac: 'aa:bb:cc:00:01:53'),
      DhcpDevice(ip: '192.168.2.160', name: 'NAS', mac: 'aa:bb:cc:00:01:60'),
      DhcpDevice(
        ip: '192.168.2.161',
        name: 'Printer',
        mac: 'aa:bb:cc:00:01:61',
      ),
      DhcpDevice(ip: '192.168.2.162', name: '', mac: 'aa:bb:cc:00:01:62'),
      DhcpDevice(ip: '192.168.2.163', name: 'Camera', mac: 'aa:bb:cc:00:01:63'),
    ],
  );
}
