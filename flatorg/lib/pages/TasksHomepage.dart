import 'package:flatorg/cards/TaskCard.dart';
import 'package:flatorg/datastructures/MyTask.dart';
import 'package:flatorg/styles/Sizes.dart';
import 'package:flatorg/styles/Spacings.dart';
import 'package:flutter/material.dart';

class TasksHomepage extends StatefulWidget {
  const TasksHomepage({super.key});
  @override
  State<TasksHomepage> createState() => _TasksHomepageState();
}

class _TasksHomepageState extends State<TasksHomepage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            child: Padding(
              padding: Spacings.header_padding,
              child: Text(
                "Your task",
                style: TextStyle(
                  fontSize: Sizes.h2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          SizedBox(
            child: Padding(
              padding: Spacings.main_task_card_padding,
              child: TaskCard(
                task: Mytask("Shopping", 0),
                personname: "Jin",
                duedate: DateTime(2026, 2, 24, 23, 59),
              ),
            ),
          ),
          SizedBox(
            child: Padding(
              padding: Spacings.header_padding,
              child: Text(
                "Others",
                style: TextStyle(
                  fontSize: Sizes.h2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: Spacings.list_outside_padding,
              child: ListView(
                padding: Spacings.list_padding,

                children: [
                  TaskCard(
                    task: Mytask("Bathroom", 0),
                    personname: "Tim",
                    duedate: DateTime(2025, 10, 24, 23, 59),
                  ),
                  TaskCard(
                    task: Mytask("Bathroom", 0),
                    personname: "Tim",
                    duedate: DateTime(2025, 10, 24, 23, 59),
                  ),
                  TaskCard(
                    task: Mytask("Bathroom", 0),
                    personname: "Tim",
                    duedate: DateTime(2025, 10, 24, 23, 59),
                  ),
                  TaskCard(
                    task: Mytask("Bathroom", 0),
                    personname: "Tim",
                    duedate: DateTime(2025, 10, 24, 23, 59),
                  ),
                  TaskCard(
                    task: Mytask("Bathroom", 0),
                    personname: "Tim",
                    duedate: DateTime(2025, 10, 24, 23, 59),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
