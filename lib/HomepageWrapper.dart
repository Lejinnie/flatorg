import 'package:flatorg/pages/TasksHomepage.dart';
import 'package:flutter/material.dart';

class HomepageWrapper extends StatefulWidget {
  const HomepageWrapper({super.key, required this.title});

  final String title;

  @override
  State<StatefulWidget> createState() {
    return _HomepageWrapperState();
  }
}

class _HomepageWrapperState extends State<HomepageWrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(widget.title),
      ),
      drawer: const Drawer(
        child: SafeArea(child: ListTile(title: Text("TODO"))),
      ),
      body: TasksHomepage(),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Groceries'),
        ],
      ),
    );
  }
}
