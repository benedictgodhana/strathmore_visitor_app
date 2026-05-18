import 'package:flutter/material.dart';
import 'package:strathmore_visitor_app/screens/home_screen.dart';
import '../models/visitor.dart';
import '../utils/constants.dart';

class VisitorDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Visitor? visitor =
        ModalRoute.of(context)?.settings.arguments as Visitor?;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Visitor's Details",
          style: TextStyle(fontFamily: 'BrandonGrotesque'),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundLight,
      body:
          visitor == null
              ? Center(
                child: Text(
                  'No visitor data provided.',
                  style: TextStyle(
                    fontFamily: 'BrandonGrotesque',
                    fontSize: 18,
                  ),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                        child: Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text('Name:', style: _labelStyle()),
                    Text(visitor.name, style: _valueStyle()),
                    SizedBox(height: 16),
                    Text('Gate:', style: _labelStyle()),
                    Text(visitor.gate ?? '-', style: _valueStyle()),
                    SizedBox(height: 16),
                    Text('Check-in Time:', style: _labelStyle()),
                    Text(
                      visitor.checkInTime?.format(context) ?? '-',
                      style: _valueStyle(),
                    ),
                    SizedBox(height: 16),
                    Text('Check-out Time:', style: _labelStyle()),
                    Text(
                      visitor.checkOutTime?.format(context) ??
                          'Not checked out',
                      style: _valueStyle(),
                    ),
                    SizedBox(height: 16),
                    Text('Appointment:', style: _labelStyle()),
                    Text(
                      (visitor.hadAppointment ?? false) ? 'Yes' : 'No',
                      style: _valueStyle(),
                    ),
                    SizedBox(height: 16),
                    Text('Contact:', style: _labelStyle()),
                    Text(visitor.contact ?? '-', style: _valueStyle()),
                    // Add more fields as needed
                  ],
                ),
              ),
    );
  }

  TextStyle _labelStyle() => TextStyle(
    fontFamily: 'BrandonGrotesque',
    fontWeight: FontWeight.w600,
    color: AppColors.primaryBlue,
    fontSize: 15,
  );

  TextStyle _valueStyle() => TextStyle(
    fontFamily: 'BrandonGrotesque',
    fontWeight: FontWeight.w400,
    color: Colors.black,
    fontSize: 17,
  );
}
