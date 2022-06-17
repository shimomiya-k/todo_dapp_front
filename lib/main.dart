import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:todo_dapp_front/todo_list.dart';
import 'package:todo_dapp_front/todo_list_model.dart';

void main() async {
  await dotenv.load(fileName: 'local.env');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TodoListModel(),
      child: const MaterialApp(
        title: 'Flutter TODO',
        home: TodoList(),
      ),
    );
  }
}
