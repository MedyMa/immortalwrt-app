/// Passive NPU state only. Readiness does not prove hardware traffic activity.
class NpuStatus {
  const NpuStatus({
    required this.present,
    required this.readable,
    required this.firmwareReady,
    required this.mcuAlive,
    this.packetForwardingVerified = false,
  });

  final bool present;
  final bool readable;
  final bool firmwareReady;
  final bool mcuAlive;
  final bool packetForwardingVerified;

  bool get ready => present && readable && firmwareReady && mcuAlive;

  static NpuStatus? tryParse(Object? value) {
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
