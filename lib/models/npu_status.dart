/// Firmware core-busy utilization plus legacy state parsing for older callers.
/// Readiness and tunnel occupancy are never substituted for utilization.
class NpuStatus {
  const NpuStatus({
    required this.present,
    required this.readable,
    required this.firmwareReady,
    required this.mcuAlive,
    this.packetForwardingVerified = false,
    this.utilizationPercent,
  });

  final bool present;
  final bool readable;
  final bool firmwareReady;
  final bool mcuAlive;
  final bool packetForwardingVerified;
  final double? utilizationPercent;

  bool get ready => present && readable && firmwareReady && mcuAlive;

  static NpuStatus? tryParse(Object? value) {
    if (value is Map && value['schema'] is int && value['schema'] == 1) {
      final milli = value['percent_milli'];
      if (value['available'] != true ||
          value['unit'] != 'mean_core_busy_percent' ||
          value['coverage'] != 'complete' ||
          value['core_count'] is! int ||
          value['core_count'] != 5 ||
          milli is! int ||
          milli < 0 ||
          milli > 100000) {
        return null;
      }
      return NpuStatus(
        present: true,
        readable: true,
        firmwareReady: false,
        mcuAlive: false,
        utilizationPercent: milli / 1000,
      );
    }
    if (value is! Map ||
        !const [2, 3].contains(value['schema']) ||
        value['npu'] is! Map) {
      return null;
    }
    final npu = value['npu'] as Map;
    if (npu['status_node_present'] is! bool ||
        npu['firmware_ready'] is! bool ||
        npu['mcu_alive'] is! bool) {
      return null;
    }
    final ready =
        npu['coverage'] == 'complete' &&
        npu['status_node_present'] == true &&
        npu['firmware_ready'] == true &&
        npu['mcu_alive'] == true;
    return NpuStatus(
      present: npu['status_node_present'] == true,
      readable: npu['coverage'] == 'complete',
      firmwareReady: npu['firmware_ready'] == true,
      mcuAlive: npu['mcu_alive'] == true,
      packetForwardingVerified: ready && npu['packet_offload_verified'] == true,
    );
  }
}
