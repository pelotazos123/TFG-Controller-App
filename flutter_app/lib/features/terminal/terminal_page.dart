import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rccontroller_app/l10n/app_localizations.dart';
import 'package:flutter_rccontroller_app/features/control/control_manager.dart';
import 'package:flutter_rccontroller_app/transport/control_transport.dart';
import 'package:flutter_rccontroller_app/transport/transport_message.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final ControlManager _controlManager = ControlManager.instance;
  final ScrollController _scrollController = ScrollController();
  final List<TransportEvent> _entries = [];
  final List<TransportEvent> _pendingEntries = [];
  bool _autoScroll = true;
  bool _lastConnected = false;

  static const int _maxEntries = 200;

  StreamSubscription<TransportEvent>? _eventSubscription;
  ControlTransport? _boundTransport;

  @override
  void initState() {
    super.initState();
    _controlManager.addListener(_handleTransportChanged);
    _bindTransport(_controlManager.transport);
    _lastConnected = _controlManager.isConnected;
    _entries.addAll(_controlManager.terminalHistory);
  }

  @override
  void dispose() {
    _controlManager.removeListener(_handleTransportChanged);
    _eventSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTransportChanged() {
    final transport = _controlManager.transport;
    if (transport != _boundTransport) {
      _bindTransport(transport);
    }
    _handleConnectionState();
    if (mounted) {
      setState(() {});
    }
  }

  void _bindTransport(ControlTransport? transport) {
    _eventSubscription?.cancel();
    _boundTransport = transport;

    if (transport == null) {
      _eventSubscription = null;
      return;
    }

    _eventSubscription = transport.terminalEvents.listen((event) {
      _appendEntry(event);
    });
  }

  void _handleConnectionState() {
    final isConnected = _controlManager.isConnected;
    if (_lastConnected && !isConnected) {
      final message =
          AppLocalizations.of(context)?.connectionLost ?? 'Connection lost';
      _appendEntry(
        TransportEvent(
          type: 'log',
          data: {
            'level': 'warn',
            'tag': 'CONN',
            'message': message,
          },
          receivedAt: DateTime.now(),
        ),
      );
    }
    _lastConnected = isConnected;
  }

  void _appendEntry(TransportEvent event) {
    if (!mounted) return;
    setState(() {
      if (_autoScroll) {
        _entries.add(event);
        if (_entries.length > _maxEntries) {
          _entries.removeAt(0);
        }
      } else {
        _pendingEntries.add(event);
        if (_pendingEntries.length > _maxEntries) {
          _pendingEntries.removeAt(0);
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoScroll) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isConnected = _controlManager.isConnected;
    final transportLabel = switch (_controlManager.transport) {
      null => localizations?.disconnected,
      _ => isConnected ? localizations?.connected : localizations?.disconnected,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations!.terminalTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.link : Icons.link_off,
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      transportLabel!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Tooltip(
                    message: localizations.terminalAutoscroll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_vert_circle_outlined),
                        Switch.adaptive(
                          value: _autoScroll,
                          onChanged: (v) {
                            setState(() {
                              _autoScroll = v;
                              if (_autoScroll && _pendingEntries.isNotEmpty) {
                                _entries.addAll(_pendingEntries);
                                _pendingEntries.clear();
                                if (_entries.length > _maxEntries) {
                                  _entries.removeRange(
                                    0,
                                    _entries.length - _maxEntries,
                                  );
                                }
                              }
                            });
                            if (_autoScroll) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  );
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                child: _entries.isEmpty
                    ? Center(
                        child: Text(
                          localizations.terminalNoTraffic,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final line = entry.toDisplayLine();
                          final color = switch (entry.type) {
                            'log' => Colors.lightBlueAccent,
                            'hello_ack' => Colors.orangeAccent,
                            'terminal' => Colors.white,
                            _ => Colors.white70,
                          };

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SelectableText(
                              line,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}