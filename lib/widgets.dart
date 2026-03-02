import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

class AppleBouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AppleBouncingButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<AppleBouncingButton> createState() => _AppleBouncingButtonState();
}

class _AppleBouncingButtonState extends State<AppleBouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: -0.08, // يسمح بارتداد (Overshoot) خفيف يتجاوز 1.0
      upperBound: 1.0,
      value: 0.0,
    );

    // عندما يكون 0.0 = الحجم 1.0
    // عندما يكون 1.0 = الحجم 0.95 (انكماش طبيعي)
    _scaleAnimation = Tween<double>(begin: 1.0,end: 0.95,).chain(CurveTween(curve: Curves.easeOutCubic),).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.selectionClick();
    // انكماش تدريجي بنعومة دون توقف حاد
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleTapUp(TapUpDetails details) {
    _runSpringSimulation();
    
    // تأخير بسيط لمحاكاة الفيزياء وإعطاء المستخدم شعوراً باكتمال الضغطة
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) widget.onTap();
    });
  }

  void _handleTapCancel() {
    _runSpringSimulation();
  }

  void _runSpringSimulation() {
    // إعدادات زنبرك (Spring) مطابقة لـ SwiftUI
    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 400.0,
      damping: 24.0, // ارتداد (Overshoot) ميكرو ناعم جداً
    );

    final simulation = SpringSimulation(
      spring,
      _controller.value,
      0.0, // العودة للحجم الطبيعي
      _controller.velocity,
    );

    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}