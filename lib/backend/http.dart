import 'dart:convert';
import 'package:flatorg/datastructures/MyTaskList.dart';
import 'package:http/http.dart' as http;

class HttpService {
  final String stockURL = "http://localhost:8080/getTasks";

  Future<List<Mytasklist>> getTasks() async {
    var url = Uri.http("localhost:8080", "getTasks");
    http.Response res = await http.get(Uri.parse(stockURL));

    if (res.statusCode == 200) {
      final obj = jsonDecode(res.body);
      return obj;
    } else {
      throw "Unable to retrieve stock data.";
    }
  }

  // Future<List<Mytasklist>> sendTasks(Mytasklist list) async {
  //   final obj = jsonEncode(list);

  // }
}
