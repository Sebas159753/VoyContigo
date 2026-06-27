import 'package:flutter/material.dart';

class TickerWidget extends StatefulWidget {
  final List<Widget> children;
  final double speed;

  const TickerWidget({super.key, required this.children, this.speed = 30});

  @override
  State<TickerWidget> createState() => _TickerWidgetState();
}

class _TickerWidgetState extends State<TickerWidget> {
  late ScrollController _scrollController;
  bool _isScrolling = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() async {
    while (_isScrolling) {
      if (!mounted) break;
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          final duration = Duration(seconds: (maxScroll / widget.speed).round());
          await _scrollController.animateTo(
            maxScroll,
            duration: duration,
            curve: Curves.linear,
          );
          if (mounted && _isScrolling) {
            _scrollController.jumpTo(0);
          }
        } else {
          await Future.delayed(const Duration(seconds: 1));
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox();
    
    // Duplicamos los items varias veces para crear la ilusión de infinito
    final infiniteChildren = List.generate(20, (index) => widget.children).expand((i) => i).toList();

    return IgnorePointer(
      ignoring: true, // Evitar interacciones manuales que rompan la animación
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: infiniteChildren,
      ),
    );
  }
}
