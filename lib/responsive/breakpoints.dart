import 'package:flutter/material.dart';

const double kDesktopBreakpoint = 900.0;

bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
