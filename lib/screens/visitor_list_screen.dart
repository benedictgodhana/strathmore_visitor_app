import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';

class VisitorListScreen extends StatefulWidget {
  @override
  _VisitorListScreenState createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen> {
  late ScrollController _scrollController;
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _showFab = _scrollController.position.pixels <= 100;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visitorProvider = Provider.of<VisitorProvider>(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Visitor Management',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => visitorProvider.loadCheckedInVisitors(),
            tooltip: 'Refresh',
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    onTap: () async {
                      await visitorProvider.logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => visitorProvider.loadCheckedInVisitors(),
        child:
            visitorProvider.isLoading
                ? Center(child: CircularProgressIndicator())
                : visitorProvider.visitors.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No visitors found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      TextButton(
                        onPressed:
                            () => visitorProvider.loadCheckedInVisitors(),
                        child: Text('Refresh'),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(bottom: 80),
                  itemCount: visitorProvider.visitors.length,
                  itemBuilder: (context, index) {
                    final visitor = visitorProvider.visitors[index];
                    return _buildVisitorCard(visitor, visitorProvider, context);
                  },
                ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _showFab ? 1.0 : 0.0,
        duration: Duration(milliseconds: 200),
        child: FloatingActionButton.extended(
          onPressed:
              () => Navigator.pushNamed(context, '/visitor-registration'),
          icon: Icon(Icons.person_add),
          label: Text('Register'),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitorCard(
    Visitor visitor,
    VisitorProvider provider,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final statusColor =
        visitor.action == 'checked in' ? Colors.green : Colors.blueGrey;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Add visitor details navigation if needed
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  visitor.action == 'checked in'
                      ? Icons.person
                      : Icons.person_outline,
                  color: statusColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.name ?? 'Unknown Visitor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ID: ${visitor.idNumber ?? 'N/A'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (visitor.action == 'checked in')
                Container(
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.logout, color: statusColor),
                    onPressed: () async {
                      await _showCheckoutConfirmation(
                        visitor,
                        provider,
                        context,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCheckoutConfirmation(
    Visitor visitor,
    VisitorProvider provider,
    BuildContext context,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Check Out Visitor'),
            content: Text(
              'Are you sure you want to check out ${visitor.name}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await provider.checkOutVisitor(visitor);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${visitor.name} checked out successfully',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to check out: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text('Check Out', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
