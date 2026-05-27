import 'package:intl/intl.dart';

final _date = DateFormat('MMM d, yyyy');

String formatDate(DateTime date) => _date.format(date);
