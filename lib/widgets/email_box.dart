import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../config/palette.dart';

class EmailBox extends StatelessWidget {
  final Map data;

  EmailBox(this.data);

  @override
  Widget build(BuildContext context) {
    var time = timeago.format(DateTime.parse(data["creation"]));
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.person)
              ),
              title: Text('${data["subject"]}'),
              subtitle: Text('${data["sender_full_name"]} - $time'),
              trailing: PopupMenuButton(
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(child: Text('Reply'), value: 'Reply',)
                  ];
                },
              )),
          ListTile(
            title: Html(
              data: data["content"],
            ),
          )
        ],
      ),
    );
  }
}