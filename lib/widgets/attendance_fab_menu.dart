import 'package:flutter/material.dart';
import '../models/attendance.dart';

class AttendanceFabMenu extends StatefulWidget {

  final Function(AttendanceStatus?) onSelect;

  const AttendanceFabMenu({
    super.key,
    required this.onSelect,
  });

  @override
  State<AttendanceFabMenu> createState() => _AttendanceFabMenuState();
}

class _AttendanceFabMenuState extends State<AttendanceFabMenu>
    with SingleTickerProviderStateMixin {

  bool open = false;

  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  void toggle() {
    setState(() {
      open = !open;

      if (open) {
        controller.forward();
      } else {
        controller.reverse();
      }
    });
  }

  Widget buildAction(
    IconData icon,
    String label,
    Color color,
    AttendanceStatus? status,
    int index,
  ) {

    return FadeTransition(
      opacity: controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .4),
          end: Offset.zero,
        ).animate(controller),

        child: Padding(
          padding: EdgeInsets.only(bottom: 10.0 * index),

          child: GestureDetector(
            onTap: () {
              widget.onSelect(status);
              toggle();
            },

            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(30),
              ),

              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),

                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [

        if (open) ...[

          buildAction(
            Icons.check,
            "Present",
            Colors.green,
            AttendanceStatus.present,
            4,
          ),

          buildAction(
            Icons.close,
            "Absent",
            Colors.red,
            AttendanceStatus.absent,
            3,
          ),

          buildAction(
            Icons.block,
            "Cancelled",
            Colors.orange,
            AttendanceStatus.cancelled,
            2,
          ),

          buildAction(
            Icons.clear,
            "Clear",
            Colors.grey,
            null,
            1,
          ),
        ],

        FloatingActionButton(
          onPressed: toggle,
          mini: true,
          child: Icon(open ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}