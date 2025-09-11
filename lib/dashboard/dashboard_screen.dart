import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String fullName;
  final String email;
  final List<String> roles;

  const DashboardScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
    required this.fullName,
    required this.email,
    required this.roles,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmLogout == true) {
      try {
        final logoutUrl = '${widget.serverUrl}/api/method/logout';
        await http.get(Uri.parse(logoutUrl), headers: {
          'Cookie': 'sid=${widget.sid}',
        }).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint("Error during server logout: $e");
      } finally {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildBackground(context),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAppBar(context),
                    _buildHeader(),
                    _buildDashboardGrid(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.background,
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              Icons.logout_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity:
          CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
            .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Text(
                  widget.fullName.isNotEmpty
                      ? widget.fullName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back,',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.8),
                          fontFamily: 'Poppins',
                        ),
                  ),
                  Text(
                    widget.fullName,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    final dashboardItems = [
      {
        'title': 'Sales Order',
        'icon': Icons.shopping_cart_outlined,
        'route': '/salesOrder',
        'arguments': {
          'serverUrl': widget.serverUrl,
          'sid': widget.sid,
          'roles': widget.roles,
        },
      },
      {
        'title': 'Quotations',
        'icon': Icons.receipt_outlined,
        'route': '/quotationList',
        'arguments': {
          'serverUrl': widget.serverUrl,
          'sid': widget.sid,
        },
      },
      {
        'title': 'Customers',
        'icon': Icons.people_outline,
        'route': '/customerList',
        'arguments': {
          'serverUrl': widget.serverUrl,
          'sid': widget.sid,
          'email': widget.email,
        },
      },
      {
        'title': 'Receivable Report',
        'icon': Icons.receipt_long_outlined,
        'route': '/receivableReport',
        'arguments': {'serverUrl': widget.serverUrl, 'sid': widget.sid},
      },
      {
        'title': 'Sales Person Receivable Report',
        'icon': Icons.account_balance_wallet_outlined,
        'route': '/salesPersonReceivableReport',
        'arguments': {'serverUrl': widget.serverUrl, 'sid': widget.sid},
      },
      {
        'title': 'Visit Entries',
        'icon': Icons.event_note_outlined,
        'route': '/visitEntryList',
        'arguments': {
          'serverUrl': widget.serverUrl,
          'sid': widget.sid,
        },
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.0,
      ),
      itemCount: dashboardItems.length,
      itemBuilder: (context, index) {
        final item = dashboardItems[index];
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final delay = 0.2 * index;
            final animation = CurvedAnimation(
              parent: _animationController,
              curve: Interval(delay, 1.0, curve: Curves.easeOut),
            );
            return Transform.translate(
              offset: Offset(0, 50 * (1 - animation.value)),
              child: Opacity(opacity: animation.value, child: child),
            );
          },
          child: _DashboardCard(
            title: item['title'] as String,
            icon: item['icon'] as IconData,
            onTap: () {
              Navigator.pushNamed(
                context,
                item['route'] as String,
                arguments: item['arguments'] as Map<String, dynamic>,
              );
            },
          ),
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shadowColor: Theme.of(context).primaryColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.8),
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
