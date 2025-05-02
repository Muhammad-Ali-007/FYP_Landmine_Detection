import 'package:flutter/material.dart';
// import './records_page.dart'; // Assuming this file exists and defines RecordsPage
// import './main.dart'; // Assuming this file defines the main app widget (e.g., MyApp or HomePage)

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: <Widget>[
          // Button to navigate to records_page.dart
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecordsPage()), // Assuming RecordsPage widget
              );
            },
            child: const Text('Records'),
          ),
          // Button to navigate to main.dart (assuming it's the home page)
          TextButton(
             style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            onPressed: () {
               // Navigate back to the first screen in the stack (assuming main.dart is the root)
              Navigator.popUntil(context, (route) => route.isFirst);
               // Alternative: Push the main page, depending on desired navigation flow
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => const MainPage()), // Assuming MainPage widget in main.dart
              // );
            },
            child: const Text('Home'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Short project description
            const Text(
              'This application is designed to detect landmines using advanced architecture and algorithms.',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20.0),

            // Image of the architecture
            // Replace 'assets/architecture.png' with the actual path to your image asset
            Image.asset(
              'assets/architecture.png', // Placeholder image path
              fit: BoxFit.contain, // Adjust the fit as needed
               errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text('Could not load architecture image.'));
              },
            ),
            const SizedBox(height: 20.0),

            // You can add more features here if needed
          ],
        ),
      ),
    );
  }
}

// Add a placeholder RecordsPage widget if it doesn't exist yet
// Remove this if records_page.dart already contains the RecordsPage definition
class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Records Page')),
      body: const Center(child: Text('Records Page Content')),
    );
  }
}

// Add a placeholder MainPage widget if main.dart doesn't define one that you want to navigate back to
// Remove this if main.dart already contains the MainPage definition you intend to use
class MainPage extends StatelessWidget {
   const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Main Page')),
      body: const Center(child: Text('Main Page Content')),
    );
  }
}
