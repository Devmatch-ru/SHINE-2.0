import 'package:flutter/material.dart';

class CameraPageRoute extends PageRouteBuilder {
  final Widget child;
  final CameraTransitionType type;
  final Duration duration;
  final Curve curve;

  CameraPageRoute({
    required this.child,
    this.type = CameraTransitionType.focus,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOutCubic,
  }) : super(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );

  @override
  Widget buildTransitions(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
    );

    switch (type) {
      case CameraTransitionType.focus:
        return _buildFocusTransition(curvedAnimation, secondaryAnimation, child);
      case CameraTransitionType.zoom:
        return _buildZoomTransition(curvedAnimation, secondaryAnimation, child);
      case CameraTransitionType.aperture:
        return _buildApertureTransition(curvedAnimation, secondaryAnimation, child);
      case CameraTransitionType.pan:
        return _buildPanTransition(curvedAnimation, secondaryAnimation, child);
      case CameraTransitionType.blur:
        return _buildBlurTransition(curvedAnimation, secondaryAnimation, child);
      case CameraTransitionType.shutter:
        return _buildShutterTransition(curvedAnimation, secondaryAnimation, child);
    }
  }

  Widget _buildFocusTransition(
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final focusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(animation);

    final blurAnimation = Tween<double>(
      begin: 8.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
    ));

    final scaleAnimation = Tween<double>(
      begin: 1.1,
      end: 1.0,
    ).animate(animation);

    return Stack(
      children: [
        Transform.scale(
          scale: 0.95,
          child: Opacity(
            opacity: 1.0 - secondaryAnimation.value * 0.3,
            child: Container(),
          ),
        ),
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Transform.scale(
              scale: scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: blurAnimation.value,
                      spreadRadius: blurAnimation.value / 2,
                    ),
                  ],
                ),
                child: Opacity(
                  opacity: focusAnimation.value,
                  child: child,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildZoomTransition(
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final zoomAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    final backgroundScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(secondaryAnimation);

    return Stack(
      children: [
        Transform.scale(
          scale: backgroundScaleAnimation.value,
          child: Opacity(
            opacity: 1.0 - secondaryAnimation.value * 0.5,
            child: Container(),
          ),
        ),
        Center(
          child: Transform.scale(
            scale: zoomAnimation.value,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApertureTransition(
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        final radius = (size.width + size.height) * 0.7 * animation.value;

        return Stack(
          children: [
            Container(color: Colors.black),
            ClipPath(
              clipper: CircleClipper(radius),
              child: child,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanTransition(
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
    ));

    final exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0.0),
    ).animate(secondaryAnimation);

    final parallaxAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0.0),
      end: Offset.zero,
    ).animate(animation);

    return Stack(
      children: [
        SlideTransition(
          position: exitSlideAnimation,
          child: Container(),
        ),
        SlideTransition(
          position: slideAnimation,
          child: SlideTransition(
            position: parallaxAnimation,
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildBlurTransition(
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final blurInAnimation = Tween<double>(
      begin: 10.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuint,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    final scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(animation);

    return Stack(
      children: [
        Opacity(
          opacity: 1.0 - secondaryAnimation.value * 0.7,
          child: Container(),
        ),
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Transform.scale(
              scale: scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: blurInAnimation.value,
                    ),
                  ],
                ),
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: child,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShutterTransition(
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final shutterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutQuart,
    ));

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ClipPath(
          clipper: ShutterClipper(shutterAnimation.value),
          child: child,
        );
      },
    );
  }
}

class CircleClipper extends CustomClipper<Path> {
  final double radius;

  CircleClipper(this.radius);

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class ShutterClipper extends CustomClipper<Path> {
  final double progress;

  ShutterClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    final centerY = size.height / 2;
    final openHeight = size.height * progress;

    final topY = centerY - openHeight / 2;
    final bottomY = centerY + openHeight / 2;

    path.addRect(Rect.fromLTRB(0, topY, size.width, bottomY));

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

enum CameraTransitionType {
  focus,
  zoom,
  aperture,
  pan,
  blur,
  shutter,
}