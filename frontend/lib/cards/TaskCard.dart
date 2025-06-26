import 'package:flatorg/datastructures/MyTask.dart';
import 'package:flatorg/styles/Spacings.dart';
import 'package:flutter/material.dart';

class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.personname,
    required this.duedate,
  });

  final Mytask task;
  final String personname;
  final DateTime duedate;

  @override
  State<StatefulWidget> createState() {
    return _TaskCardState();
  }
}

class _TaskCardState extends State<TaskCard> {
  // TODO: replace with proper data structure and stuff

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Spacings.big_card_outside_padding,
      child: Card(
        // color: MyColors.background,
        child: Container(
          padding: EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // TODO: make this change colour or something else when less than 72h to finish.
                      "Due until: ${widget.duedate.hour}:${widget.duedate.minute} / ${widget.duedate.day}.${widget.duedate.month}.${widget.duedate.year}",
                    ),
                    Text(
                      "Task: ${widget.task.getTaskName()}",
                      style: TextStyle(fontSize: 20),
                    ),
                    Text(
                      "Assigned: ${widget.personname}",
                      // style: TextStyle(color: MyColors.dark_3),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  style: ButtonStyle(
                    // backgroundColor: WidgetStateProperty.all(
                    //   MyColors.highlight,
                    // ),
                    // shape: WidgetStateProperty.all(
                    //   RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(10),
                    //   ),
                    // ),
                  ),
                  padding: EdgeInsets.all(0),
                  onPressed: () => {},
                  icon: Icon(Icons.check, size: 33),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.all(0),
                  onPressed: () => {},
                  icon: Icon(Icons.more_vert),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
