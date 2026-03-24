import 'dart:async';

class PerformanceMonitorService {
  // Metrics tracking
  final Map<String, OperationMetric> _metrics = {};
  final _metricsController = StreamController<PerformanceData>.broadcast();
  
  Stream<PerformanceData> get performanceData => _metricsController.stream;

  // Start tracking operation
  void startOperation(String operationName) {
    _metrics[operationName] = OperationMetric(
      name: operationName,
      startTime: DateTime.now(),
    );
  }

  // End tracking operation
  void endOperation(String operationName, {bool success = true}) {
    if (!_metrics.containsKey(operationName)) {
      print('⚠️ Operation not started: $operationName');
      return;
    }

    final metric = _metrics[operationName]!;
    metric.endTime = DateTime.now();
    metric.success = success;
    metric.duration = metric.endTime!.difference(metric.startTime).inMilliseconds;

    print('⏱️ $operationName: ${metric.duration}ms');

    // Log metric
    _broadcastMetric(metric);
  }

  // Track async operation
  Future<T> trackAsyncOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startOperation(operationName);
    try {
      final result = await operation();
      endOperation(operationName, success: true);
      return result;
    } catch (e) {
      endOperation(operationName, success: false);
      print('❌ $operationName failed: $e');
      rethrow;
    }
  }

  // Get performance report
  PerformanceReport getPerformanceReport() {
    final metrics = _metrics.values.toList();
    
    // Separate successful and failed operations
    final successful = metrics.where((m) => m.success).toList();
    final failed = metrics.where((m) => !m.success).toList();

    // Calculate statistics
    final avgDuration = successful.isEmpty
        ? 0
        : successful.map((m) => m.duration!).reduce((a, b) => a + b) / successful.length;

    final maxDuration = successful.isEmpty
        ? 0
        : successful.map((m) => m.duration!).reduce((a, b) => a > b ? a : b);

    final minDuration = successful.isEmpty
        ? 0
        : successful.map((m) => m.duration!).reduce((a, b) => a < b ? a : b);

    return PerformanceReport(
      totalOperations: metrics.length,
      successful: successful.length,
      failed: failed.length,
      successRate: metrics.isEmpty 
          ? '0' 
          : (successful.length / metrics.length * 100).toStringAsFixed(2),
      avgDuration: avgDuration.toStringAsFixed(2),
      maxDuration: maxDuration,
      minDuration: minDuration,
      metrics: metrics,
      generatedAt: DateTime.now(),
    );
  }

  // Get specific metric stats
  Map<String, dynamic> getOperationStats(String operationName) {
    final relevantMetrics = _metrics.values
        .where((m) => m.name.contains(operationName))
        .toList();

    if (relevantMetrics.isEmpty) {
      return {'error': 'No metrics found for operation: $operationName'};
    }

    final successful = relevantMetrics.where((m) => m.success).toList();
    final avgDuration = successful.isEmpty
        ? 0.0
        : successful.map((m) => m.duration!).reduce((a, b) => a + b) / successful.length;

    return {
      'operationName': operationName,
      'totalCalls': relevantMetrics.length,
      'successfulCalls': successful.length,
      'failedCalls': relevantMetrics.length - successful.length,
      'averageDuration': '${avgDuration.toStringAsFixed(2)}ms',
      'lastExecuted': relevantMetrics.last.endTime?.toString() ?? 'N/A',
    };
  }

  // Clear metrics
  void clearMetrics() {
    _metrics.clear();
    print('🔄 Metrics cleared');
  }

  // Broadcast metric
  void _broadcastMetric(OperationMetric metric) {
    _metricsController.add(PerformanceData(
      metric: metric,
      timestamp: DateTime.now(),
    ));
  }

  // Export metrics as JSON
  Map<String, dynamic> exportMetricsAsJson() {
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'report': getPerformanceReport().toJson(),
      'metrics': _metrics.values
          .map((m) => {
            'name': m.name,
            'duration': m.duration,
            'success': m.success,
            'startTime': m.startTime.toIso8601String(),
            'endTime': m.endTime?.toIso8601String(),
          })
          .toList(),
    };
  }

  void dispose() {
    _metricsController.close();
  }
}

class OperationMetric {
  final String name;
  final DateTime startTime;
  DateTime? endTime;
  int? duration;
  bool success = true;

  OperationMetric({
    required this.name,
    required this.startTime,
  });
}

class PerformanceData {
  final OperationMetric metric;
  final DateTime timestamp;

  PerformanceData({
    required this.metric,
    required this.timestamp,
  });
}

class PerformanceReport {
  final int totalOperations;
  final int successful;
  final int failed;
  final String successRate;
  final String avgDuration;
  final int maxDuration;
  final int minDuration;
  final List<OperationMetric> metrics;
  final DateTime generatedAt;

  PerformanceReport({
    required this.totalOperations,
    required this.successful,
    required this.failed,
    required this.successRate,
    required this.avgDuration,
    required this.maxDuration,
    required this.minDuration,
    required this.metrics,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'totalOperations': totalOperations,
    'successful': successful,
    'failed': failed,
    'successRate': successRate,
    'avgDuration': avgDuration,
    'maxDuration': maxDuration,
    'minDuration': minDuration,
    'generatedAt': generatedAt.toIso8601String(),
  };
}
